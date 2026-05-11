import Foundation

/// Общие данные между main app и Broadcast Upload Extension (App Group IPC).
enum BroadcastPreferences {
    static let suiteName = "group.miracast.Miracast"

    /// Какой транспорт extension должен использовать для уведомления TV.
    enum Transport: String {
        case dlna       // extension сам шлёт SOAP SetAVTransportURI/Play
        case external   // main app сам уведомляет TV (Chromecast / AirPlay)
    }

    private enum Keys {
        static let localIP          = "streaming.localIP"
        static let hlsPort          = "streaming.hlsPort"
        static let hlsToken         = "streaming.hlsToken"
        static let transport        = "streaming.transport"
        static let dlnaControlURL   = "streaming.dlna.controlURL"
        static let dlnaRendererName = "streaming.dlna.rendererName"
        static let smartViewURI     = "streaming.smartView.uri"
        static let smartViewName    = "streaming.smartView.name"
        static let broadcastStarted = "streaming.status.started"
        static let broadcastError   = "streaming.status.error"
    }

    /// Кэшируем — `UserDefaults(suiteName:)` не самая дешёвая операция, а poll'ится каждые 0.5с.
    private static let defaults = UserDefaults(suiteName: suiteName)

    struct Snapshot {
        var localIP: String?
        var hlsPort: UInt16?
        var hlsToken: String?
        var transport: Transport = .external
        var dlnaControlURL: URL?
        var dlnaRendererName: String?
        var smartViewURI: String?
        var smartViewName: String?

        /// Сборка URL стрима из port + token.
        func streamURL(host: String) -> URL? {
            guard let port = hlsPort, let token = hlsToken else { return nil }
            return URL(string: "http://\(host):\(port)/\(token)/stream.m3u8")
        }
    }

    // MARK: - Save (main app)

    static func save(localIP: String?,
                     hlsPort: UInt16?,
                     transport: Transport,
                     renderer: DLNARenderer?,
                     smartViewURI: String?,
                     smartViewName: String?) {
        guard let d = defaults else { return }
        d.set(localIP, forKey: Keys.localIP)
        if let p = hlsPort { d.set(Int(p), forKey: Keys.hlsPort) } else { d.removeObject(forKey: Keys.hlsPort) }
        d.set(transport.rawValue, forKey: Keys.transport)
        if let r = renderer {
            d.set(r.avTransportControlURL.absoluteString, forKey: Keys.dlnaControlURL)
            d.set(r.friendlyName, forKey: Keys.dlnaRendererName)
        } else {
            d.removeObject(forKey: Keys.dlnaControlURL)
            d.removeObject(forKey: Keys.dlnaRendererName)
        }
        d.set(smartViewURI, forKey: Keys.smartViewURI)
        d.set(smartViewName, forKey: Keys.smartViewName)
        d.removeObject(forKey: Keys.hlsToken)
        d.removeObject(forKey: Keys.broadcastStarted)
        d.removeObject(forKey: Keys.broadcastError)
    }

    // MARK: - Load

    static func load() -> Snapshot {
        let d = defaults
        let transportRaw = d?.string(forKey: Keys.transport) ?? Transport.external.rawValue
        return Snapshot(
            localIP: d?.string(forKey: Keys.localIP),
            hlsPort: (d?.object(forKey: Keys.hlsPort) as? Int).flatMap { UInt16(exactly: $0) },
            hlsToken: d?.string(forKey: Keys.hlsToken),
            transport: Transport(rawValue: transportRaw) ?? .external,
            dlnaControlURL: d?.string(forKey: Keys.dlnaControlURL).flatMap(URL.init(string:)),
            dlnaRendererName: d?.string(forKey: Keys.dlnaRendererName),
            smartViewURI: d?.string(forKey: Keys.smartViewURI),
            smartViewName: d?.string(forKey: Keys.smartViewName)
        )
    }

    // MARK: - Status (extension → main app)

    static func reportBroadcastStarted(port: UInt16, token: String) {
        let d = defaults
        d?.set(Int(port), forKey: Keys.hlsPort)
        d?.set(token, forKey: Keys.hlsToken)
        d?.set(true, forKey: Keys.broadcastStarted)
        d?.removeObject(forKey: Keys.broadcastError)
    }

    static func reportBroadcastError(_ message: String) {
        defaults?.set(message, forKey: Keys.broadcastError)
    }

    static var isBroadcasting: Bool {
        defaults?.bool(forKey: Keys.broadcastStarted) ?? false
    }

    static var lastError: String? {
        defaults?.string(forKey: Keys.broadcastError)
    }
}
