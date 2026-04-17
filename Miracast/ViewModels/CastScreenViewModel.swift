import Foundation
import Combine
import UIKit
import SwiftUI

/// Оркестрация стриминга экрана:
/// 1. Поднимаем локальный HLS HTTP-сервер (порт 7000).
/// 2. Запускаем захват экрана + кодирование, сегменты отдаются серверу.
/// 3. Сообщаем TV URL `http://<iphone-ip>:<port>/stream.m3u8`:
///    - через SmartView канал (Samsung Tizen), если connectedService != nil
///    - через DLNA AVTransport SetAVTransportURI+Play, если connectedRenderer != nil
final class CastScreenViewModel: ObservableObject {

    // MARK: - Published state

    enum State: Equatable {
        case idle
        case starting(String)
        case streaming(URL)
        case error(String)
    }

    @Published var state: State = .idle

    var isStreaming: Bool {
        if case .streaming = state { return true }
        return false
    }

    // MARK: - Private

    private let server = HLSStreamServer()
    private let encoder = ScreenStreamEncoder()
    private let dlna = DLNAController()

    init() {
        encoder.delegate = self
    }

    // MARK: - Public

    func start(appState: AppState) {
        guard case .idle = state else { return }

        if appState.connectedRenderer == nil && appState.connectedService == nil {
            state = .error("Please connect to a TV first (Home → Connect device)")
            return
        }

        state = .starting("Starting HTTP server…")

        // 1. HTTP сервер
        let port: UInt16
        do {
            port = try server.start()
        } catch {
            state = .error("Failed to start local server: \(error.localizedDescription)")
            return
        }

        guard let ip = NetworkUtils.currentWiFiAddress() else {
            server.stop()
            state = .error("Cannot determine Wi-Fi IP. Check network permission.")
            return
        }
        guard let streamURL = URL(string: "http://\(ip):\(port)/stream.m3u8") else {
            server.stop()
            state = .error("Invalid stream URL")
            return
        }
        print("📡 Stream URL: \(streamURL.absoluteString)")

        // 2. Кодирование
        state = .starting("Starting screen capture…")
        encoder.start { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.server.stop()
                self.state = .error("Capture failed: \(error.localizedDescription)")
                return
            }

            // 3. Посылаем URL на TV. Даём пол секунды, чтобы энкодер успел выдать init-сегмент и пару кусков.
            self.state = .starting("Notifying TV…")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                self.sendToTV(streamURL: streamURL, appState: appState) { success, message in
                    DispatchQueue.main.async {
                        if success {
                            self.state = .streaming(streamURL)
                        } else {
                            self.stop()
                            self.state = .error(message ?? "TV refused the stream")
                        }
                    }
                }
            }
        }
    }

    func stop() {
        encoder.stop()
        server.stop()
        state = .idle
    }

    // MARK: - Private

    private func sendToTV(streamURL: URL,
                          appState: AppState,
                          completion: @escaping (Bool, String?) -> Void) {
        // Приоритет: DLNA (универсально и надёжно). SmartView — fallback.
        if let renderer = appState.connectedRenderer {
            dlna.playMedia(on: renderer,
                           url: streamURL,
                           mimeType: "application/vnd.apple.mpegurl",
                           title: "iPhone Screen") { result in
                switch result {
                case .success: completion(true, nil)
                case .failure(let e): completion(false, "DLNA: \(e.localizedDescription)")
                }
            }
            return
        }

        if let service = appState.connectedService {
            let channel = service.createChannel("com.miracast.browser")
            channel.connect(nil) { _, error in
                if let error = error {
                    completion(false, "SmartView: \(error.localizedDescription)")
                    return
                }
                channel.publish(event: "openURL",
                                message: ["url": streamURL.absoluteString] as AnyObject)
                completion(true, nil)
            }
            return
        }

        completion(false, "No connected TV")
    }
}

// MARK: - Encoder delegate

extension CastScreenViewModel: ScreenStreamEncoderDelegate {
    func encoder(_ encoder: ScreenStreamEncoder, didProduceInitSegment data: Data) {
        server.setInitSegment(data)
    }

    func encoder(_ encoder: ScreenStreamEncoder, didProduceMediaSegment data: Data, duration: Double) {
        server.appendSegment(data, duration: duration)
    }

    func encoder(_ encoder: ScreenStreamEncoder, didFailWith error: Error) {
        DispatchQueue.main.async {
            self.stop()
            self.state = .error("Encoder: \(error.localizedDescription)")
        }
    }
}
