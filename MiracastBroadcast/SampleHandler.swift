import ReplayKit
import AVFoundation
import UniformTypeIdentifiers
import Network
import os

/// Broadcast Upload Extension handler.
///
/// Отдельный процесс; получает семплы экрана + системного звука + микрофона
/// от iOS. Кодирует video (H.264) + audio (AAC) в fragmented MP4 HLS-сегменты через
/// `AVAssetWriter`, раздаёт сегменты через встроенный HTTP-сервер `HLSStreamServer`.
///
/// Лимит памяти extension ≈ 50 MB, поэтому битрейт/буферы консервативны.
final class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Logger

    private let log = Logger(subsystem: "miracast.Miracast", category: "extension")

    // MARK: - Config

    private let segmentDuration = CMTime(value: 3, timescale: 2) // 1.5 сек
    private let videoBitRate: Int = 2_500_000
    private let audioBitRate: Int = 96_000

    // MARK: - Pipeline

    private let server = HLSStreamServer()
    private let dlna = DLNAController()
    private let writingQueue = DispatchQueue(label: "miracast.ext.writer", qos: .userInitiated)

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var didStartSession = false
    private var didNotifyTV = false

    private var snapshot: BroadcastPreferences.Snapshot?

    // MARK: - RPBroadcastSampleHandler

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        snapshot = BroadcastPreferences.load()

        // HTTP сервер. Writer создаётся лениво из первого video-буфера,
        // чтобы взять реальные размеры экрана.
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let (port, token) = try await self.server.start(preferredPort: 7000)
                BroadcastPreferences.reportBroadcastStarted(port: port, token: token)
                self.log.info("HLS server up :\(port, privacy: .public)")
            } catch {
                self.fail(with: "Failed to start HTTP server: \(error.localizedDescription)")
                return
            }

            // Дожидаемся первого реального сегмента — только потом уведомляем TV,
            // чтобы плеер не получил пустой плейлист.
            await self.server.waitForFirstSegment()
            self.notifyTVOnce()
        }
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        let writer = self.writer
        let videoInput = self.videoInput
        let audioInput = self.audioInput
        self.writer = nil
        self.videoInput = nil
        self.audioInput = nil
        self.didStartSession = false

        // Делаем shutdown асинхронно, чтобы уложиться в системный лимит teardown (~1 сек).
        writingQueue.async { [server, dlna, snapshot] in
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            if writer?.status == .writing {
                let sem = DispatchSemaphore(value: 0)
                writer?.finishWriting { sem.signal() }
                _ = sem.wait(timeout: .now() + 0.4)
            }
            server.stop()

            // STOP на TV — best-effort, без долгого ожидания.
            if let controlURL = snapshot?.dlnaControlURL, snapshot?.transport == .dlna {
                let renderer = DLNARenderer(
                    id: "stop",
                    friendlyName: snapshot?.dlnaRendererName ?? "",
                    manufacturer: "", modelName: "",
                    location: controlURL, baseURL: controlURL,
                    avTransportControlURL: controlURL
                )
                let sem = DispatchSemaphore(value: 0)
                dlna.stop(on: renderer) { _ in sem.signal() }
                _ = sem.wait(timeout: .now() + 0.3)
            }
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // Swift capture в closure автоматически retain'ит CMSampleBuffer (как class type)
        // — буфер останется живым до окончания appendVideo/appendAudio. Это критично
        // потому что ReplayKit повторно использует контейнер CMSampleBuffer после возврата.
        switch sampleBufferType {
        case .video:
            writingQueue.async { [weak self] in self?.appendVideo(sampleBuffer) }
        case .audioApp:
            writingQueue.async { [weak self] in self?.appendAudio(sampleBuffer) }
        case .audioMic:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Writer

    /// Создаёт писатель ровно один раз. Если width/height не известны заранее,
    /// откладывает создание до первого video-буфера, чтобы взять реальные размеры.
    private func setupWriterIfNeeded(width: Int?, height: Int?) throws {
        guard writer == nil else { return }

        let w = width  ?? 720
        let h = height ?? 1280

        let contentType = UTType("public.mpeg-4") ?? UTType.movie
        let writer = AVAssetWriter(contentType: contentType)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = segmentDuration
        writer.initialSegmentStartTime = .zero
        writer.shouldOptimizeForNetworkUse = true
        writer.delegate = self

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 45,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        vInput.mediaTimeScale = 600

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: audioBitRate
        ]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(vInput), writer.canAdd(aInput) else {
            throw NSError(domain: "MiracastBroadcast", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add inputs"])
        }
        writer.add(vInput)
        writer.add(aInput)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "MiracastBroadcast", code: -2,
                                          userInfo: [NSLocalizedDescriptionKey: "startWriting failed"])
        }

        self.writer = writer
        self.videoInput = vInput
        self.audioInput = aInput
        self.didStartSession = false
        log.info("Writer setup \(w, privacy: .public)x\(h, privacy: .public)")
    }

    private func appendVideo(_ buffer: CMSampleBuffer) {
        // На первом video-буфере, если writer ещё не создан — создаём с реальными размерами.
        if writer == nil {
            do {
                if let desc = CMSampleBufferGetFormatDescription(buffer) {
                    let dims = CMVideoFormatDescriptionGetDimensions(desc)
                    try setupWriterIfNeeded(width: Int(dims.width), height: Int(dims.height))
                } else {
                    try setupWriterIfNeeded(width: nil, height: nil)
                }
            } catch {
                fail(with: "Writer setup failed: \(error.localizedDescription)")
                return
            }
        }
        guard let writer = writer, let input = videoInput else { return }
        startSessionIfNeeded(with: buffer)
        if input.isReadyForMoreMediaData { _ = input.append(buffer) }
        if let err = writer.error {
            fail(with: "Writer error: \(err.localizedDescription)")
        }
    }

    private func appendAudio(_ buffer: CMSampleBuffer) {
        guard let input = audioInput, didStartSession else { return }
        if input.isReadyForMoreMediaData { _ = input.append(buffer) }
    }

    private func startSessionIfNeeded(with buffer: CMSampleBuffer) {
        guard !didStartSession, let writer = writer else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        writer.startSession(atSourceTime: pts)
        didStartSession = true
    }

    // MARK: - TV handshake

    private func notifyTVOnce() {
        writingQueue.async { [weak self] in
            guard let self = self, !self.didNotifyTV else { return }
            self.didNotifyTV = true
            self.notifyTV()
        }
    }

    private func notifyTV() {
        guard let snapshot = snapshot else {
            fail(with: "No snapshot loaded"); return
        }

        // external — main app сам уведомит TV.
        if snapshot.transport == .external {
            log.info("transport=external, skipping TV notify in extension")
            return
        }

        // DLNA — шлём SetAVTransportURI / Play.
        guard let controlURL = snapshot.dlnaControlURL else {
            if snapshot.smartViewURI != nil {
                fail(with: "SmartView-only casting isn't supported in extension. Use DLNA.")
            } else {
                fail(with: "No TV target configured")
            }
            return
        }

        let ip = snapshot.localIP ?? currentWiFiAddress() ?? "127.0.0.1"
        guard let streamURL = snapshot.streamURL(host: ip) else {
            fail(with: "Invalid stream URL"); return
        }

        let renderer = DLNARenderer(
            id: "ext",
            friendlyName: snapshot.dlnaRendererName ?? "",
            manufacturer: "", modelName: "",
            location: controlURL, baseURL: controlURL,
            avTransportControlURL: controlURL
        )
        dlna.playMedia(on: renderer,
                       url: streamURL,
                       mimeType: "application/vnd.apple.mpegurl",
                       title: "iPhone Screen") { [weak self] result in
            if case .failure(let e) = result {
                self?.fail(with: "DLNA: \(e.localizedDescription)")
            }
        }
    }

    // MARK: - Errors

    private func fail(with message: String) {
        log.error("\(message, privacy: .public)")
        BroadcastPreferences.reportBroadcastError(message)
        let error = NSError(domain: "MiracastBroadcast", code: -999,
                            userInfo: [NSLocalizedDescriptionKey: message])
        finishBroadcastWithError(error)
    }

    // MARK: - IP helper

    private func currentWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: interface.ifa_name) == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: host)
                break
            }
        }
        return address
    }
}

// MARK: - AVAssetWriterDelegate

extension SampleHandler: AVAssetWriterDelegate {
    func assetWriter(_ writer: AVAssetWriter,
                     didOutputSegmentData segmentData: Data,
                     segmentType: AVAssetSegmentType,
                     segmentReport: AVAssetSegmentReport?) {
        switch segmentType {
        case .initialization:
            server.setInitSegment(segmentData)
        case .separable:
            let dur = segmentReport?.trackReports.first?.duration.seconds ?? segmentDuration.seconds
            server.appendSegment(segmentData, duration: dur)
        @unknown default:
            break
        }
    }
}
