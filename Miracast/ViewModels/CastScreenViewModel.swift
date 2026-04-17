import Foundation
import Combine
import UIKit

/// Подготовка к broadcast и отслеживание его состояния.
///
/// Сам захват и кодирование теперь живут в Broadcast Upload Extension (`MiracastBroadcast`).
/// Главное приложение:
/// 1. Собирает информацию о целевом TV и кладёт её в shared UserDefaults (App Group).
/// 2. Показывает системный Broadcast Picker.
/// 3. Следит за shared-статусом: стартовал ли extension, были ли ошибки.
final class CastScreenViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case preparing
        case broadcasting
        case error(String)
    }

    @Published var state: State = .idle

    private var pollTimer: Timer?

    deinit { pollTimer?.invalidate() }

    /// Подготавливает App Group defaults и показывает пикер.
    /// Пользователь тапает "Start Broadcast" в системном листе — дальше работает extension.
    func prepareAndShowPicker(appState: AppState) {
        guard appState.connectedRenderer != nil || appState.connectedService != nil else {
            state = .error("Please connect to a TV first (Home → Connect device)")
            return
        }

        let ip = NetworkUtils.currentWiFiAddress()
        BroadcastPreferences.save(
            localIP: ip,
            hlsPort: 7000,
            renderer: appState.connectedRenderer,
            smartViewURI: appState.connectedService?.uri,
            smartViewName: appState.connectedService?.name
        )

        state = .preparing
        startPolling()

        // Имитируем тап по системному пикеру — открывается лист с MiracastBroadcast.
        BroadcastPickerTrigger.programmaticallyTap()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Status polling

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        if let err = BroadcastPreferences.lastError {
            stopPolling()
            DispatchQueue.main.async { self.state = .error(err) }
            return
        }
        if BroadcastPreferences.isBroadcasting {
            DispatchQueue.main.async {
                if self.state != .broadcasting { self.state = .broadcasting }
            }
        }
    }
}
