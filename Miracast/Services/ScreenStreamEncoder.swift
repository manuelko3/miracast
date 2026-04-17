import Foundation
import AVFoundation
import ReplayKit
import UIKit
import UniformTypeIdentifiers

/// Захват экрана через ReplayKit + realtime H.264 кодирование в fragmented MP4 (HLS-совместимые сегменты).
///
/// Использует AVAssetWriter с `outputFileTypeProfile = .mpeg4AppleHLS` (iOS 14+).
/// Сегменты отдаются в HLSStreamServer через делегат.
final class ScreenStreamEncoder: NSObject {

    // MARK: - Config

    /// Целевая длительность сегмента.
    let segmentDuration: CMTime = CMTime(value: 2, timescale: 1)
    /// Битрейт видео. ~4 Mbps хватает на 720p live stream к TV.
    let videoBitRate: Int = 4_000_000

    // MARK: - Public

    weak var delegate: ScreenStreamEncoderDelegate?
    private(set) var isRunning = false

    // MARK: - Private

    private let writingQueue = DispatchQueue(label: "miracast.encoder.write")
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var didStartSession = false
    private var sessionStartTime: CMTime = .zero

    // MARK: - Lifecycle

    func start(completion: @escaping (Error?) -> Void) {
        guard !isRunning else { completion(nil); return }
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            completion(NSError(domain: "ScreenStreamEncoder", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "Screen recording is not available on this device"]))
            return
        }
        recorder.isMicrophoneEnabled = false

        do {
            try setupWriter()
        } catch {
            completion(error)
            return
        }

        // Формат CMSampleBuffer'ов от ReplayKit — BGRA пиксели; AVAssetWriter справляется сам.
        recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ RPScreenRecorder capture error: \(error)")
                self.delegate?.encoder(self, didFailWith: error)
                return
            }
            guard bufferType == .video else { return }
            self.writingQueue.async { self.append(sampleBuffer: sampleBuffer) }
        }, completionHandler: { [weak self] error in
            if let error = error {
                print("❌ startCapture failed: \(error)")
                self?.tearDownWriter()
                completion(error)
                return
            }
            self?.isRunning = true
            completion(nil)
        })
    }

    func stop(completion: (() -> Void)? = nil) {
        guard isRunning else { completion?(); return }
        isRunning = false

        let recorder = RPScreenRecorder.shared()
        recorder.stopCapture { [weak self] error in
            if let error = error {
                print("⚠️ stopCapture error: \(error)")
            }
            self?.writingQueue.async {
                self?.videoInput?.markAsFinished()
                if self?.writer?.status == .writing {
                    self?.writer?.finishWriting {
                        DispatchQueue.main.async {
                            self?.tearDownWriter()
                            completion?()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.tearDownWriter()
                        completion?()
                    }
                }
            }
        }
    }

    // MARK: - Writer setup

    private func setupWriter() throws {
        let contentType = UTType("public.mpeg-4") ?? UTType.movie
        let writer = AVAssetWriter(contentType: contentType)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = segmentDuration
        writer.initialSegmentStartTime = .zero
        writer.shouldOptimizeForNetworkUse = true
        writer.delegate = self

        // Определяем разрешение экрана и ориентацию.
        let screen = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        // Не уходим в нативное 1242x2688 — масштабируем до 720p, TV это хватит.
        let targetHeight: CGFloat = 1280
        let aspect = screen.width / screen.height
        let width = (targetHeight * aspect).rounded(.down)
        let height = targetHeight

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(width),
            AVVideoHeightKey: Int(height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoAllowFrameReorderingKey: false,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
        _ = scale // silence warning: пока не используем scale — берём фиксированный 720p

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        if writer.canAdd(input) {
            writer.add(input)
        } else {
            throw NSError(domain: "ScreenStreamEncoder", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to writer"])
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "ScreenStreamEncoder", code: -3,
                                          userInfo: [NSLocalizedDescriptionKey: "startWriting failed"])
        }

        self.writer = writer
        self.videoInput = input
        self.didStartSession = false
    }

    private func tearDownWriter() {
        writer = nil
        videoInput = nil
        didStartSession = false
    }

    // MARK: - Feed

    private func append(sampleBuffer: CMSampleBuffer) {
        guard let writer = writer, let input = videoInput else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !didStartSession {
            sessionStartTime = pts
            writer.startSession(atSourceTime: pts)
            didStartSession = true
        }

        if input.isReadyForMoreMediaData {
            if !input.append(sampleBuffer) {
                if let err = writer.error {
                    print("❌ append failed: \(err)")
                    delegate?.encoder(self, didFailWith: err)
                }
            }
        }
    }
}

// MARK: - AVAssetWriterDelegate

extension ScreenStreamEncoder: AVAssetWriterDelegate {
    func assetWriter(_ writer: AVAssetWriter,
                     didOutputSegmentData segmentData: Data,
                     segmentType: AVAssetSegmentType,
                     segmentReport: AVAssetSegmentReport?) {
        switch segmentType {
        case .initialization:
            delegate?.encoder(self, didProduceInitSegment: segmentData)
        case .separable:
            let duration = segmentReport?
                .trackReports
                .first?
                .duration
                .seconds ?? segmentDuration.seconds
            delegate?.encoder(self, didProduceMediaSegment: segmentData, duration: duration)
        @unknown default:
            break
        }
    }
}

// MARK: - Delegate

protocol ScreenStreamEncoderDelegate: AnyObject {
    func encoder(_ encoder: ScreenStreamEncoder, didProduceInitSegment data: Data)
    func encoder(_ encoder: ScreenStreamEncoder, didProduceMediaSegment data: Data, duration: Double)
    func encoder(_ encoder: ScreenStreamEncoder, didFailWith error: Error)
}
