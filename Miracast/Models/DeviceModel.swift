import Foundation

struct CastDevice: Identifiable, Hashable {
    let id: String
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
        case samsungTV
        case other

        var iconName: String {
            switch self {
            case .tv: return "tv"
            case .chromecast: return "airplayvideo"
            case .appleTV: return "appletv"
            case .roku: return "rectangle.on.rectangle"
            case .samsungTV: return "tv"
            case .other: return "tv.and.mediabox"
            }
        }
    }

    // Инициализатор с кастомным ID
    init(id: String, name: String, modelName: String, ipAddress: String, deviceType: DeviceType, isConnected: Bool = false, signalStrength: Int = 100) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.ipAddress = ipAddress
        self.deviceType = deviceType
        self.isConnected = isConnected
        self.signalStrength = signalStrength
    }

    // Инициализатор с автоматическим UUID
    init(name: String, modelName: String, ipAddress: String, deviceType: DeviceType, isConnected: Bool = false, signalStrength: Int = 100) {
        self.id = UUID().uuidString
        self.name = name
        self.modelName = modelName
        self.ipAddress = ipAddress
        self.deviceType = deviceType
        self.isConnected = isConnected
        self.signalStrength = signalStrength
    }
}
