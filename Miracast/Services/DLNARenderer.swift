import Foundation

/// DLNA / UPnP AVTransport MediaRenderer.
/// Работает на Samsung TV начиная с 2010 года, LG, Sony, Philips и пр.
struct DLNARenderer: Identifiable, Hashable {
    /// USN из SSDP ответа — стабильный уникальный идентификатор.
    let id: String
    let friendlyName: String
    let manufacturer: String
    let modelName: String
    /// Адрес device description XML, напр. http://192.168.1.42:7676/smp_2_
    let location: URL
    /// Базовый URL (scheme://host:port), относительно которого резолвятся controlURL.
    let baseURL: URL
    /// Control endpoint сервиса `urn:schemas-upnp-org:service:AVTransport:1`.
    let avTransportControlURL: URL
    /// Хост для показа в UI.
    var host: String { baseURL.host ?? "?" }

    static func == (lhs: DLNARenderer, rhs: DLNARenderer) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
