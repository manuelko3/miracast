import Foundation
import Combine
import SmartView

/// Подключение к Smart TV / каст-устройству.
///
/// Хранит и `Service` (SmartView SDK), и `DLNARenderer` одновременно: одно и то же
/// физическое устройство может быть доступно по нескольким протоколам, и `Capabilities`
/// определяет какой именно транспорт мы используем для трансляции.
final class ConnectionState: ObservableObject {
    @Published var isDeviceConnected = false
    @Published var connectedDeviceName = ""

    /// SmartView SDK сервис (Samsung Tizen 2015+).
    @Published var connectedService: Service?

    /// DLNA MediaRenderer (старые Samsung, прочие DLNA-TV).
    @Published var connectedRenderer: DLNARenderer?

    /// Полный набор протоколов, по которым устройство видно.
    /// CastScreen выбирает транспорт: DLNA > SmartView > Chromecast > AirPlay > DIAL.
    @Published var connectedCapabilities: CastDevice.Capabilities = []

    /// IP-адрес (Chromecast / AirPlay / FireTV).
    @Published var connectedHost: String?

    /// device description URL для DIAL (нужен для запуска YouTube на FireTV/Roku).
    @Published var connectedDIALLocation: URL?

    func reset() {
        isDeviceConnected = false
        connectedDeviceName = ""
        connectedService = nil
        connectedRenderer = nil
        connectedCapabilities = []
        connectedHost = nil
        connectedDIALLocation = nil
    }
}
