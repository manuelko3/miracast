import Foundation

struct CastDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let modelName: String
    var ipAddress: String
    var isConnected: Bool = false
    var signalStrength: Int // 0-100

    var deviceType: DeviceType
    /// Транспорт, который умеет обслуживать это устройство.
    /// Несколько флагов могут быть выставлены одновременно (напр. Samsung Tizen — и SmartView, и DLNA).
    var capabilities: Capabilities = []

    enum DeviceType {
        case tv
        case chromecast
        case appleTV
        case roku
        case other

        var iconName: String {
            switch self {
            case .tv: return "tv"
            case .chromecast: return "airplayvideo"
            case .appleTV: return "appletv"
            case .roku: return "rectangle.on.rectangle"
            case .other: return "tv.and.mediabox"
            }
        }
    }

    struct Capabilities: OptionSet, Hashable {
        let rawValue: Int
        static let smartView  = Capabilities(rawValue: 1 << 0) // Samsung SmartView SDK
        static let dlna       = Capabilities(rawValue: 1 << 1) // UPnP AVTransport (универсально)
        static let airplay    = Capabilities(rawValue: 1 << 2) // Apple TV / AirPlay 2 ресиверы
        static let chromecast = Capabilities(rawValue: 1 << 3) // Google Cast (Chromecast / Android TV)
        static let dial       = Capabilities(rawValue: 1 << 4) // DIAL — запуск приложений (Fire TV и др.)

        /// Короткие бейджи для UI.
        var badges: [(label: String, color: String)] {
            var out: [(String, String)] = []
            if contains(.dlna)       { out.append(("DLNA", "blue")) }
            if contains(.smartView)  { out.append(("SmartView", "purple")) }
            if contains(.airplay)    { out.append(("AirPlay", "black")) }
            if contains(.chromecast) { out.append(("Cast", "red")) }
            if contains(.dial)       { out.append(("DIAL", "orange")) }
            return out
        }
    }
}
