import SwiftUI
import Combine
import AVKit
import AVFoundation

/// Обёртка над `AVRoutePickerView` — нативный системный пикер выбора AirPlay.
struct AirPlayPickerView: UIViewRepresentable {
    var tintColor: UIColor = .systemBlue
    var activeTintColor: UIColor = .systemGreen

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = tintColor
        v.activeTintColor = activeTintColor
        v.prioritizesVideoDevices = true
        return v
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

enum AirPlayPickerTrigger {
    static func show() {
        let picker = AVRoutePickerView(frame: .zero)
        picker.prioritizesVideoDevices = true
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            }
        }
    }
}

/// AVPlayer-плейбэк HLS-ленты от extension. iOS сама роутит на выбранный AirPlay-приёмник
/// через `allowsExternalPlayback = true` + пикер `AVRoutePickerView`.
///
/// Через KVO ловим статус item'а и playback ошибки.
final class AirPlayPlayback: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var errorMessage: String?

    private var player: AVPlayer?
    private var item: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var startCompletion: ((Result<Void, Error>) -> Void)?

    func start(streamURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        stop()
        startCompletion = completion

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            finishStart(.failure(error))
            return
        }

        let item = AVPlayerItem(url: streamURL)
        self.item = item

        let player = AVPlayer(playerItem: item)
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        self.player = player

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            switch item.status {
            case .readyToPlay:
                self.isPlaying = true
                self.finishStart(.success(()))
            case .failed:
                let err = item.error ?? NSError(domain: "AirPlay", code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "Playback failed"])
                self.errorMessage = err.localizedDescription
                self.finishStart(.failure(err))
            default: break
            }
        }
        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            self?.isPlaying = player.rate > 0
        }

        // Таймаут 8 сек на случай, если status не приходит.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.finishStart(.failure(NSError(domain: "AirPlay", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "Timeout starting playback"])))
        }

        player.play()
    }

    func stop() {
        statusObserver?.invalidate(); statusObserver = nil
        rateObserver?.invalidate(); rateObserver = nil
        player?.pause()
        player = nil
        item = nil
        isPlaying = false
        errorMessage = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func finishStart(_ result: Result<Void, Error>) {
        guard let cb = startCompletion else { return }
        startCompletion = nil
        cb(result)
    }
}
