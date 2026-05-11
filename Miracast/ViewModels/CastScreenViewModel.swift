import Foundation
import Combine
import UIKit

/// Подготовка к broadcast и отслеживание его состояния.
///
/// Сам захват и кодирование экрана живут в Broadcast Upload Extension (`MiracastBroadcast`).
/// Главное приложение:
/// 1. Выбирает оптимальный транспорт по capabilities подключённого TV.
/// 2. Сохраняет настройки в shared UserDefaults (App Group) и триггерит системный Broadcast Picker.
/// 3. Следит за shared-статусом: стартовал ли extension, и когда HLS-сервер поднят,
///    уведомляет TV напрямую (Chromecast LOAD / AirPlay route / DLNA уже сам шлёт SOAP).
final class CastScreenViewModel: ObservableObject {

    enum Route: Equatable {
        case dlna                          // extension сам шлёт SOAP
        case chromecast(host: String)
        case airplay                       // main app: AVPlayer + AVRoutePickerView
    }

    enum State: Equatable {
        case idle
        case preparing
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

    /// Подготавливает App Group defaults и показывает пикер.
    func prepareAndShowPicker(appState: AppState) {
        let caps = appState.connectedCapabilities
        guard caps.isEmpty == false || appState.connectedRenderer != nil || appState.connectedService != nil else {
            state = .error("Please connect to a TV first (Home → Connect device)")
            return
        }

        // Выбор транспорта по приоритету.
        // DLNA > SmartView > Chromecast > AirPlay.
        let route: Route
        let storageTransport: BroadcastPreferences.Transport
        let saveRenderer: DLNARenderer?

        if caps.contains(.dlna), let renderer = appState.connectedRenderer {
            route = .dlna
            storageTransport = .dlna
            saveRenderer = renderer
        } else if caps.contains(.chromecast), let host = appState.connectedHost {
            route = .chromecast(host: host)
            storageTransport = .external
            saveRenderer = nil
        } else if caps.contains(.airplay) {
            route = .airplay
            storageTransport = .external
            saveRenderer = nil
        } else if caps.contains(.smartView) {
            state = .error("This TV supports only Samsung SmartView. Pick a DLNA-compatible renderer (most TVs have one).")
            return
        } else if caps.contains(.dial) {
            state = .error("This TV supports only DIAL (YouTube/Netflix app launch). Screen streaming needs DLNA / AirPlay / Chromecast.")
            return
        } else {
            state = .error("No supported transport for this device")
            return
        }

        let ip = NetworkUtils.currentWiFiAddress()
        BroadcastPreferences.save(
            localIP: ip,
            hlsPort: 7000,
            transport: storageTransport,
            renderer: saveRenderer,
            smartViewURI: appState.connectedService?.uri,
            smartViewName: appState.connectedService?.name
        )

        state = .preparing
        pendingRoute = route
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

        guard BroadcastPreferences.isBroadcasting else { return }
        guard let route = pendingRoute else { return }

        // Первый раз — уведомляем TV и переходим в broadcasting.
        if !didLaunchRoute {
            didLaunchRoute = true
            launchRoute(route)
        }
        if case .broadcasting = state { return }
        DispatchQueue.main.async { self.state = .broadcasting(route) }
    }

    private func launchRoute(_ route: Route) {
        let snapshot = BroadcastPreferences.load()
        let ip = snapshot.localIP ?? NetworkUtils.currentWiFiAddress() ?? "127.0.0.1"
        let port = snapshot.hlsPort ?? 7000
        guard let streamURL = URL(string: "http://\(ip):\(port)/stream.m3u8") else {
            DispatchQueue.main.async { self.state = .error("Invalid stream URL") }
            return
        }

        switch route {
        case .dlna:
            // Extension уже послал SOAP сам.
            break

        case .chromecast(let host):
            let cc = ChromecastController(host: host)
            self.chromecast = cc
            let media = ChromecastController.MediaInfo(
                url: streamURL.absoluteString,
                contentType: "application/vnd.apple.mpegurl",
                title: "iPhone Screen",
                isLive: true
            )
            cc.load(media) { [weak self] result in
                if case .failure(let err) = result {
                    DispatchQueue.main.async { self?.state = .error("Chromecast: \(err.localizedDescription)") }
                }
            }

        case .airplay:
            // Main app запускает AVPlayer с HLS; пользователь выберет AirPlay маршрут через пикер в UI.
            airPlayback.start(streamURL: streamURL)
        }
    }
}
