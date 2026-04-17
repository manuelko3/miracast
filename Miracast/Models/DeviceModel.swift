import Foundation

struct CastDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let modelName: String
    let ipAddress: String
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
        static let smartView = Capabilities(rawValue: 1 << 0) // Samsung SmartView SDK
        static let dlna      = Capabilities(rawValue: 1 << 1) // UPnP AVTransport
    }
}
