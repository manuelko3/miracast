import Foundation

struct CastDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let modelName: String
    let ipAddress: String
    var isConnected: Bool = false
    var signalStrength: Int // 0-100
    
    // Для отображения иконки по типу устройства
    var deviceType: DeviceType
    
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
}
