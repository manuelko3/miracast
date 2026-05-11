import Foundation
import Network

/// Поиск устройств через Bonjour/mDNS. Ловим:
///   _airplay._tcp   — Apple TV, AirPlay 2 TV (некоторые Samsung/LG/Sony с 2018+)
///   _raop._tcp      — Remote Audio Output (Apple TV, HomePod, AirPlay колонки)
///   _googlecast._tcp — Chromecast, Android TV, Google TV, Nest Hub
///   _amzn-wplay._tcp — Amazon Fire TV
///
/// Для Chromecast и Fire TV мы получаем только факт существования —
/// стриминг на них требует Google Cast SDK / DIAL API, которые пока не реализованы.
/// Устройство в списке будет помечено соответствующими capabilities.
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

    init(onFound: @escaping (Hit) -> Void) {
        self.onFound = onFound
    }

    func start() {
        stop()

        let services: [(String, Hit.Kind)] = [
            ("_airplay._tcp",      .airplay),
            ("_raop._tcp",         .airplay),     // тоже AirPlay
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
                // Фильтруем ненужное — принтеры, компы, колонки (но колонки через raop мы пропускаем лишь частично).
                if self.shouldSkip(name: display, kind: kind) { continue }

                // Разрешаем endpoint в IP через отдельное соединение — это даст хост.
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

    private func resolveHost(for result: NWBrowser.Result, completion: @escaping (String?) -> Void) {
        let conn = NWConnection(to: result.endpoint, using: .tcp)
        var done = false
        conn.stateUpdateHandler = { state in
            guard !done else { return }
            switch state {
            case .ready:
                done = true
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
                conn.cancel()
                completion(ip)
            case .failed, .cancelled:
                done = true
                completion(nil)
            default: break
            }
        }
        conn.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 1.5) {
            if !done {
                done = true
                conn.cancel()
                completion(nil)
            }
        }
    }

    private func cleanName(_ name: String) -> String {
        name.replacingOccurrences(of: "\\032", with: " ")
            .replacingOccurrences(of: "\\ ", with: " ")
    }

    private func shouldSkip(name: String, kind: Hit.Kind) -> Bool {
        let lower = name.lowercased()
        // Пропускаем чистые колонки/наушники (raop) и не-TV AirPlay сервисы.
        let skip = ["airpods", "homepod", "printer", "scanner",
                    "macbook", "imac", "mac mini", "iphone", "ipad"]
        return skip.contains(where: { lower.contains($0) })
    }
}
