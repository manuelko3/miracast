import Foundation
import SmartView

/// Технические данные о подключаемом устройстве, собранные из разных discovery-каналов.
/// Один `ConnectableDevice` соответствует одному физическому TV. Какие-то из полей могут
/// быть nil — это значит, что соответствующий протокол не был обнаружен для этого устройства.
///
/// Используется внутри `DeviceDiscoveryViewModel` вместо четырёх параллельных словарей.
struct ConnectableDevice {
    let deviceID: UUID

    var smartViewService: Service?
    var dlnaRenderer: DLNARenderer?
    var dialLocation: URL?
    var host: String?
}
