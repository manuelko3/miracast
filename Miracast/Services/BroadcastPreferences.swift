import Foundation

/// Общие данные между main app и Broadcast Upload Extension.
///
/// Main app перед запуском broadcast сохраняет сюда информацию о целевом TV;
/// Extension читает её в `broadcastStarted(withSetupInfo:)` чтобы знать,
/// куда отправлять URL HLS-потока.
enum BroadcastPreferences {
    static let suiteName = "group.miracast.Miracast"

    private enum Keys {
        static let localIP          = "streaming.localIP"
        static let hlsPort          = "streaming.hlsPort"
        static let dlnaControlURL   = "streaming.dlna.controlURL"
        static let dlnaRendererName = "streaming.dlna.rendererName"
        static let smartViewURI     = "streaming.smartView.uri"
        static let smartViewName    = "streaming.smartView.name"
        // Extension → main app: статус трансляции.
        static let broadcastStarted = "streaming.status.started"
        static let broadcastError   = "streaming.status.error"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    struct Snapshot {
        var localIP: String?
        var hlsPort: UInt16?
        var dlnaControlURL: URL?
        var dlnaRendererName: String?
        var smartViewURI: String?
        var smartViewName: String?
    }

    // MARK: - Save (main app)

    static func save(localIP: String?,
                     hlsPort: UInt16?,
                     renderer: DLNARenderer?,
                     smartViewURI: String?,
                     smartViewName: String?) {
        guard let d = defaults else { return }
        d.set(localIP, forKey: Keys.localIP)
        if let p = hlsPort { d.set(Int(p), forKey: Keys.hlsPort) } else { d.removeObject(forKey: Keys.hlsPort) }
        if let r = renderer {
            d.set(r.avTransportControlURL.absoluteString, forKey: Keys.dlnaControlURL)
            d.set(r.friendlyName, forKey: Keys.dlnaRendererName)
        } else {
            d.removeObject(forKey: Keys.dlnaControlURL)
            d.removeObject(forKey: Keys.dlnaRendererName)
        }
        d.set(smartViewURI, forKey: Keys.smartViewURI)
        d.set(smartViewName, forKey: Keys.smartViewName)
        // Сбрасываем предыдущий статус
        d.removeObject(forKey: Keys.broadcastStarted)
        d.removeObject(forKey: Keys.broadcastError)
    }

    // MARK: - Load (extension)

    static func load() -> Snapshot {
        let d = defaults
        return Snapshot(
            localIP: d?.string(forKey: Keys.localIP),
            hlsPort: (d?.object(forKey: Keys.hlsPort) as? Int).flatMap { UInt16(exactly: $0) },
            dlnaControlURL: d?.string(forKey: Keys.dlnaControlURL).flatMap(URL.init(string:)),
            dlnaRendererName: d?.string(forKey: Keys.dlnaRendererName),
            smartViewURI: d?.string(forKey: Keys.smartViewURI),
            smartViewName: d?.string(forKey: Keys.smartViewName)
        )
    }

    // MARK: - Status (extension → main app)

    static func reportBroadcastStarted(port: UInt16) {
        let d = defaults
        d?.set(Int(port), forKey: Keys.hlsPort)
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
