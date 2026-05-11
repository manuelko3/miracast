import Foundation
import Combine
import UIKit
import os

/// Подготовка к broadcast и отслеживание его состояния.
///
/// Сам захват и кодирование экрана живут в Broadcast Upload Extension (`MiracastBroadcast`).
/// Главное приложение:
/// 1. Выбирает оптимальный транспорт по capabilities подключённого TV.
/// 2. Сохраняет настройки в shared UserDefaults (App Group) и триггерит системный Broadcast Picker.
/// 3. Следит за shared-статусом: стартовал ли extension, и когда HLS-сервер поднят,
///    уведомляет TV (Chromecast LOAD / AirPlay route) или просто фиксирует факт для DLNA.
final class CastScreenViewModel: ObservableObject {

    enum Route: Equatable {
        case dlna                          // extension сам шлёт SOAP
        case chromecast(host: String)
        case airplay                       // main app: AVPlayer + AVRoutePickerView
    }

    enum State: Equatable {
        case idle
        case preparing       // ждём пока extension поднимет сервер
        case routeStarting   // сервер поднят, отправляем команду на TV / ждём AirPlay route
        case broadcasting(Route)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var airPlayback = AirPlayPlayback()

    private var pendingRoute: Route?
    private var chromecast: ChromecastController?
    private var pollTimer: Timer?
    private var didLaunchRoute = false

    deinit { pollTimer?.invalidate() }

    // MARK: - Entry point

    func prepareAndShowPicker(appState: AppState) {
        guard let plan = Self.selectBestTransport(appState: appState) else {
            state = .error("Please connect to a TV first (Home → Connect device)")
            return
        }

        let ip = NetworkUtils.currentWiFiAddress()
        BroadcastPreferences.save(
            localIP: ip,
            hlsPort: 7000,
            transport: plan.storage,
            renderer: plan.dlnaRenderer,
            smartViewURI: appState.connectedService?.uri,
            smartViewName: appState.connectedService?.name
        )

        state = .preparing
        pendingRoute = plan.route
        didLaunchRoute = false
        startPolling()
        BroadcastPickerTrigger.programmaticallyTap()
    }

    func stopBroadcast() {
        chromecast?.stop(completion: nil)
        chromecast = nil
        airPlayback.stop()
        stopPolling()
        state = .idle
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Transport selection (pure)

    struct Plan {
        let route: Route
        let storage: BroadcastPreferences.Transport
        let dlnaRenderer: DLNARenderer?
    }

    /// Чистая функция (тестируется): выбирает лучший доступный транспорт по приоритету
    /// DLNA → Chromecast → AirPlay. Возвращает `nil`, если ни один не годится.
    static func selectBestTransport(appState: AppState) -> Plan? {
        let caps = appState.connectedCapabilities

        if caps.contains(.dlna), let renderer = appState.connectedRenderer {
            return Plan(route: .dlna, storage: .dlna, dlnaRenderer: renderer)
        }
        if caps.contains(.chromecast), let host = appState.connectedHost {
            return Plan(route: .chromecast(host: host), storage: .external, dlnaRenderer: nil)
        }
        if caps.contains(.airplay) {
            return Plan(route: .airplay, storage: .external, dlnaRenderer: nil)
        }
        return nil
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        if let err = BroadcastPreferences.lastError {
            stopPolling()
            self.state = .error(err)
            return
        }

        guard BroadcastPreferences.isBroadcasting else { return }
        guard let route = pendingRoute else { return }

        // Один раз при первом обнаружении isBroadcasting.
        if !didLaunchRoute {
            didLaunchRoute = true
            launchRoute(route)
        }
    }

    private func launchRoute(_ route: Route) {
        let snapshot = BroadcastPreferences.load()
        let ip = snapshot.localIP ?? NetworkUtils.currentWiFiAddress() ?? "127.0.0.1"
        guard let streamURL = snapshot.streamURL(host: ip) else {
            self.state = .error("Invalid stream URL — token missing")
            return
        }
        Log.broadcast.info("launchRoute \(String(describing: route), privacy: .public) URL=\(streamURL.absoluteString, privacy: .private)")

        switch route {
        case .dlna:
            // Extension сам послал SOAP и уже играет. Сразу переходим в broadcasting.
            self.state = .broadcasting(route)

        case .chromecast(let host):
            self.state = .routeStarting
            let cc = ChromecastController(host: host)
            self.chromecast = cc
            let media = ChromecastController.MediaInfo(
                url: streamURL.absoluteString,
                contentType: "application/vnd.apple.mpegurl",
                title: "iPhone Screen",
                isLive: true
            )
            cc.load(media) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        self.state = .broadcasting(route)
                    case .failure(let err):
                        self.state = .error("Chromecast: \(err.localizedDescription)")
                    }
                }
            }

        case .airplay:
            // Main app запускает AVPlayer с HLS; пользователь выберет AirPlay маршрут через пикер в UI.
            self.state = .routeStarting
            airPlayback.start(streamURL: streamURL) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.state = .broadcasting(route)
                    case .failure(let err):
                        self?.state = .error("AirPlay: \(err.localizedDescription)")
                    }
                }
            }
        }
    }
}
