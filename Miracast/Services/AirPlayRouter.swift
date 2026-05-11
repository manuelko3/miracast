import SwiftUI
import Combine
import AVKit
import AVFoundation

/// Обёртка над `AVRoutePickerView` — нативный системный пикер выбора AirPlay.
/// iOS сама находит Apple TV и AirPlay 2 ресиверы (Samsung/LG/Sony 2018+) в локальной сети.
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

/// Программный триггер системного AirPlay-пикера — имитирует тап по `AVRoutePickerView`,
/// чтобы показать лист выбора без видимой кнопки.
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

/// Маленький помощник: наш main-app HLS-плеер для AirPlay.
///
/// При AirPlay-only TV мы запускаем Broadcast Upload Extension (экран + системный звук
/// стримится в локальный HLS-сервер), а в главном приложении создаём `AVPlayer`,
/// который играет эту ленту и автоматически перенаправляет видео на AirPlay-устройство,
/// выбранное пользователем через `AVRoutePickerView`.
///
/// Важно: AVPlayer в режиме AirPlay требует, чтобы приложение оставалось активным
/// либо имело entitlement `audio` + `AVAudioSession.sharedInstance().setCategory(.playback)`.
/// Мы ставим `.playback` — видео-стрим не будет прерван при переключении в другое приложение,
/// но iOS может приостановить воспроизведение через ~30с без активности. Для устойчивого
/// screen-casting лучше использовать встроенное iOS Screen Mirroring из Control Center.
final class AirPlayPlayback: ObservableObject {
    @Published var isPlaying = false
    @Published var errorMessage: String?

    private var player: AVPlayer?

    func start(streamURL: URL) {
        stop()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Audio session: \(error.localizedDescription)"
        }

        let item = AVPlayerItem(url: streamURL)
        let player = AVPlayer(playerItem: item)
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.play()
        self.player = player
        self.isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
