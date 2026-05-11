import ReplayKit
import AVFoundation
import UniformTypeIdentifiers
import Network

/// Broadcast Upload Extension handler.
///
/// Отдельный процесс; получает семплы экрана + системного звука + микрофона
/// от iOS. Мы:
/// 1. Кодируем video (H.264) и audio (AAC) в fragmented MP4 HLS-сегменты через `AVAssetWriter`.
/// 2. Раздаём сегменты через встроенный HTTP-сервер (HLSStreamServer).
/// 3. Забираем инфу о целевом TV из App Group и посылаем URL на TV через DLNA или SmartView.
///
/// Лимит памяти extension ≈ 50 MB, поэтому битрейт/буферы подобраны консервативно.
final class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Config

    private let segmentDuration = CMTime(value: 3, timescale: 2) // 1.5 сек
    private let videoBitRate: Int = 2_500_000
    private let audioBitRate: Int = 96_000
    private let videoHeight: Int = 1280   // портрет 720×1280

    // MARK: - Pipeline

    private let server = HLSStreamServer()
    private let dlna = DLNAController()
    private let writingQueue = DispatchQueue(label: "miracast.ext.writer")

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var didStartSession = false

    // Снэпшот настроек трансляции, подгружается из App Group.
    private var snapshot: BroadcastPreferences.Snapshot?

    // MARK: - RPBroadcastSampleHandler

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        snapshot = BroadcastPreferences.load()

        // 1. HTTP сервер.
        let port: UInt16
        do {
            port = try server.start(preferredPort: 7000)
        } catch {
            fail(with: "Failed to start HTTP server: \(error.localizedDescription)")
            return
        }
        BroadcastPreferences.reportBroadcastStarted(port: port)

        // 2. Writer.
        do {
            try setupWriter()
        } catch {
            fail(with: "Writer setup failed: \(error.localizedDescription)")
            return
        }

        // 3. IP — если main app не успел сохранить, определяем сами.
        let ip = snapshot?.localIP ?? currentWiFiAddress() ?? "127.0.0.1"
        guard let streamURL = URL(string: "http://\(ip):\(port)/stream.m3u8") else {
            fail(with: "Invalid stream URL")
            return
        }

        // 4. Извещаем TV — но только после того, как энкодер успеет выдать init+первый сегмент.
        // Делаем это отложенно, чтобы плеер не получил пустой плейлист.
        writingQueue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.notifyTV(streamURL: streamURL)
        }
    }

    override func broadcastPaused() {
        // Не поддерживаем паузу явно, поток просто прервётся.
    }

    override func broadcastResumed() {
    }

    override func broadcastFinished() {
        writingQueue.sync {
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            if writer?.status == .writing {
                let sem = DispatchSemaphore(value: 0)
                writer?.finishWriting { sem.signal() }
                _ = sem.wait(timeout: .now() + 2)
            }
            writer = nil
            videoInput = nil
            audioInput = nil
            didStartSession = false
        }
        server.stop()

        // Скажем TV остановиться, если знаем как.
        if let controlString = snapshot?.dlnaControlURL?.absoluteString,
           let controlURL = URL(string: controlString) {
            let renderer = DLNARenderer(
                id: "stop",
                friendlyName: snapshot?.dlnaRendererName ?? "",
                manufacturer: "", modelName: "",
                location: controlURL, baseURL: controlURL,
                avTransportControlURL: controlURL
            )
            let sem = DispatchSemaphore(value: 0)
            dlna.stop(on: renderer) { _ in sem.signal() }
            _ = sem.wait(timeout: .now() + 1)
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        switch sampleBufferType {
        case .video:
            writingQueue.async { [weak self] in self?.appendVideo(sampleBuffer) }
        case .audioApp:
            // audioApp — это системный звук приложения. Приоритет.
            writingQueue.async { [weak self] in self?.appendAudio(sampleBuffer) }
        case .audioMic:
            // Микрофон не используем — чтобы не дублировать с audioApp.
            break
        @unknown default:
            break
        }
    }

    // MARK: - Writer

    private func setupWriter() throws {
        let contentType = UTType("public.mpeg-4") ?? UTType.movie
        let writer = AVAssetWriter(contentType: contentType)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = segmentDuration
        writer.initialSegmentStartTime = .zero
        writer.shouldOptimizeForNetworkUse = true
        writer.delegate = self

        let width = 720
        let height = videoHeight

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
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
    }

    private func appendVideo(_ buffer: CMSampleBuffer) {
        guard let writer = writer, let input = videoInput else { return }
        startSessionIfNeeded(with: buffer)
        if input.isReadyForMoreMediaData { _ = input.append(buffer) }
        if let err = writer.error {
            fail(with: "Writer error: \(err.localizedDescription)")
        }
    }

    private func appendAudio(_ buffer: CMSampleBuffer) {
        guard let input = audioInput else { return }
        // Важно: audio не триггерит startSession — только video.
        guard didStartSession else { return }
        if input.isReadyForMoreMediaData { _ = input.append(buffer) }
    }

    private func startSessionIfNeeded(with buffer: CMSampleBuffer) {
        guard !didStartSession, let writer = writer else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        writer.startSession(atSourceTime: pts)
        didStartSession = true
    }

    // MARK: - TV handshake

    private func notifyTV(streamURL: URL) {
        // Режим `external`: main app сам отправит URL на TV (Chromecast / AirPlay).
        // Extension просто крутит HLS-сервер.
        if snapshot?.transport == .external {
            print("ℹ️ [ext] transport=external, main app notifies TV")
            return
        }

        // Режим DLNA — шлём SetAVTransportURI / Play прямо отсюда.
        if let controlString = snapshot?.dlnaControlURL?.absoluteString,
           let controlURL = URL(string: controlString) {
            let renderer = DLNARenderer(
                id: "ext",
                friendlyName: snapshot?.dlnaRendererName ?? "",
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
            return
        }
        if snapshot?.smartViewURI != nil {
            fail(with: "SmartView-only casting isn't implemented in extension. Connect via DLNA.")
            return
        }

        fail(with: "No TV target configured")
    }

    // MARK: - Errors

    private func fail(with message: String) {
        print("❌ [ext] \(message)")
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
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                                socklen_t(interface.ifa_addr.pointee.sa_len),
                                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: host)
                    break
                }
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
