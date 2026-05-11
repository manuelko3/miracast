import Foundation
import Network

/// Поиск устройств через Bonjour/mDNS. Ловим:
///   _airplay._tcp   — Apple TV, AirPlay 2 TV (Samsung/LG/Sony 2018+)
///   _raop._tcp      — Remote Audio Output (Apple TV, HomePod, AirPlay колонки)
///   _googlecast._tcp — Chromecast, Android TV, Google TV, Nest Hub
///   _amzn-wplay._tcp — Amazon Fire TV
///
/// Резолв IP делается через NWConnection с минимальным таймаутом 1с,
/// разовый запрос на endpoint (не держим соединение, только узнаём адрес).
final class BonjourDiscovery {

    struct Hit {
        let name: String
        let ipAddress: String?
        let kind: Kind
        enum Kind { case airplay, chromecast, fireTV }
    }

    private let onFound: (Hit) -> Void
    private var browsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "miracast.bonjour")
    private var resolvedEndpoints = Set<String>()   // дедуп резолвов

    init(onFound: @escaping (Hit) -> Void) {
        self.onFound = onFound
    }

    func start() {
        stop()
        resolvedEndpoints.removeAll()

        let services: [(String, Hit.Kind)] = [
            ("_airplay._tcp",      .airplay),
            ("_raop._tcp",         .airplay),
            ("_googlecast._tcp",   .chromecast),
            ("_amzn-wplay._tcp",   .fireTV)
        ]
        for (type, kind) in services {
            startBrowser(type: type, kind: kind)
        }
    }

    func stop() {
        for b in browsers { b.cancel() }
        browsers.removeAll()
    }

    // MARK: - Private

    private func startBrowser(type: String, kind: Hit.Kind) {
        let params = NWParameters()
        params.includePeerToPeer = false

        let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            for result in results {
                guard case let .service(name, _, _, _) = result.endpoint else { continue }
                let display = self.cleanName(name)
                if self.shouldSkip(name: display) { continue }

                // Дедуп: один и тот же endpoint резолвим один раз.
                let key = "\(type)|\(name)"
                if self.resolvedEndpoints.contains(key) { continue }
                self.resolvedEndpoints.insert(key)

                self.resolveHost(for: result) { ip in
                    DispatchQueue.main.async {
                        self.onFound(Hit(name: display, ipAddress: ip, kind: kind))
                    }
                }
            }
        }

        browser.start(queue: queue)
        browsers.append(browser)
    }

    /// Одноразовый резолв endpoint'а в IP. Используем NWConnection потому что у NWBrowser
    /// нет публичного API получить адрес сервиса без `NWListener.NewConnectionHandler`'а.
    private func resolveHost(for result: NWBrowser.Result, completion: @escaping (String?) -> Void) {
        let conn = NWConnection(to: result.endpoint, using: .tcp)
        var done = false
        let finish: (String?) -> Void = { ip in
            if done { return }
            done = true
            conn.cancel()
            completion(ip)
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let ip: String? = {
                    guard let endpoint = conn.currentPath?.remoteEndpoint else { return nil }
                    if case let .hostPort(host, _) = endpoint {
                        switch host {
                        case .ipv4(let a): return "\(a)"
                        case .ipv6(let a): return "\(a)"
                        case .name(let n, _): return n
                        @unknown default: return nil
                        }
                    }
                    return nil
                }()
                finish(ip)
            case .failed, .cancelled:
                finish(nil)
            default: break
            }
        }
        conn.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 1.0) { finish(nil) }
    }

    private func cleanName(_ name: String) -> String {
        name.replacingOccurrences(of: "\\032", with: " ")
            .replacingOccurrences(of: "\\ ", with: " ")
    }

    private func shouldSkip(name: String) -> Bool {
        let lower = name.lowercased()
        let skip = ["airpods", "homepod", "printer", "scanner",
                    "macbook", "imac", "mac mini", "iphone", "ipad"]
        return skip.contains(where: { lower.contains($0) })
    }
}
