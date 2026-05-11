import Foundation
import Network

/// SSDP M-SEARCH поиск MediaRenderer'ов (DLNA) и DIAL-устройств (Fire TV, Roku, Chromecast).
/// После получения SSDP-ответа скачивает device description XML и парсит AVTransport controlURL.
final class DLNADiscovery {

    /// Устройство, поддерживающее DIAL — умеет запускать зарегистрированные приложения (YouTube, Netflix).
    /// Стриминг произвольного контента не поддерживает.
    struct DIALHit {
        let host: String
        let friendlyName: String
        let manufacturer: String
        let modelName: String
        /// URL device description XML — через GET на него TV вернёт заголовок `Application-URL`.
        let location: URL
    }

    private let queue = DispatchQueue(label: "miracast.dlna.discovery")
    private var connections: [NWConnection] = []
    private var seenUSN = Set<String>()
    private var isRunning = false

    private let onFound: (DLNARenderer) -> Void
    private let onDIAL: ((DIALHit) -> Void)?

    init(onFound: @escaping (DLNARenderer) -> Void,
         onDIAL: ((DIALHit) -> Void)? = nil) {
        self.onFound = onFound
        self.onDIAL = onDIAL
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        seenUSN.removeAll()

        // Посылаем M-SEARCH несколько раз с разными таргетами.
        let targets = [
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "urn:schemas-upnp-org:service:AVTransport:1",
            "urn:dial-multiscreen-org:service:dial:1",
            "ssdp:all"
        ]
        for target in targets {
            sendMSearch(target: target)
        }
    }

    func stop() {
        isRunning = false
        for c in connections { c.cancel() }
        connections.removeAll()
    }

    // MARK: - M-SEARCH

    private func sendMSearch(target: String) {
        let request = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(target)\r
        USER-AGENT: iOS UPnP/1.1 Miracast/1.0\r
        \r

        """
        guard let data = request.data(using: .utf8) else { return }

        let conn = NWConnection(
            host: NWEndpoint.Host("239.255.255.250"),
            port: NWEndpoint.Port(integerLiteral: 1900),
            using: .udp
        )

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                conn.send(content: data, completion: .contentProcessed { _ in })
                self.receive(on: conn)
            case .failed, .cancelled:
                break
            default:
                break
            }
        }

        conn.start(queue: queue)
        connections.append(conn)

        // Повтор через 2 и 4 секунды, SSDP может терять пакеты.
        for delay in [2.0, 4.0] {
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.isRunning else { return }
                if conn.state == .ready {
                    conn.send(content: data, completion: .contentProcessed { _ in })
                }
            }
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, _ in
            guard let self = self, self.isRunning else { return }
            if let data = data, let text = String(data: data, encoding: .utf8) {
                self.parseSSDPResponse(text)
            }
            if conn.state == .ready { self.receive(on: conn) }
        }
    }

    // MARK: - Parse SSDP

    private func parseSSDPResponse(_ text: String) {
        var location: String?
        var usn: String?
        var st: String?
        var server: String?

        for raw in text.components(separatedBy: "\r\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "location": location = value
            case "usn":      usn = value
            case "st", "nt": st = value
            case "server":   server = value
            default: break
            }
        }

        guard let locationStr = location,
              let locationURL = URL(string: locationStr),
              let usnStr = usn else { return }

        // Нас интересуют MediaRenderer'ы (DLNA) и DIAL-устройства.
        let stLower = st?.lowercased() ?? ""
        let serverLower = server?.lowercased() ?? ""
        let isRenderer = stLower.contains("mediarenderer") ||
                         stLower.contains("avtransport") ||
                         serverLower.contains("dlnadoc")
        let isDIAL = stLower.contains("dial-multiscreen")

        if !isRenderer && !isDIAL { return }
        if seenUSN.contains(usnStr) { return }
        seenUSN.insert(usnStr)

        fetchDeviceDescription(location: locationURL, usn: usnStr, wantsDIAL: isDIAL)
    }

    // MARK: - Device description

    private func fetchDeviceDescription(location: URL, usn: String, wantsDIAL: Bool) {
        var req = URLRequest(url: location, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 4)
        req.httpMethod = "GET"

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }

            let parser = DeviceDescriptionParser()
            let xmlParser = XMLParser(data: data)
            xmlParser.delegate = parser
            xmlParser.parse()

            let host = location.host ?? "?"

            // DLNA MediaRenderer — если есть AVTransport.
            if let renderer = self.buildRenderer(parser: parser, location: location, usn: usn) {
                DispatchQueue.main.async { self.onFound(renderer) }
            }

            // DIAL — если устройство с DIAL или если wantsDIAL (пришло по DIAL target).
            if wantsDIAL || parser.hasDIAL {
                let hit = DIALHit(
                    host: host,
                    friendlyName: parser.friendlyName ?? host,
                    manufacturer: parser.manufacturer ?? "",
                    modelName: parser.modelName ?? "",
                    location: location
                )
                DispatchQueue.main.async { self.onDIAL?(hit) }
            }
        }.resume()
    }

    private func buildRenderer(parser: DeviceDescriptionParser, location: URL, usn: String) -> DLNARenderer? {
        guard let controlPath = parser.avTransportControlURL else { return nil }
        guard let scheme = location.scheme, let host = location.host else { return nil }
        let port = location.port.map { ":\($0)" } ?? ""
        guard let baseURL = URL(string: "\(scheme)://\(host)\(port)") else { return nil }

        let controlURL: URL
        if let absolute = URL(string: controlPath), absolute.scheme != nil {
            controlURL = absolute
        } else {
            let path = controlPath.hasPrefix("/") ? controlPath : "/" + controlPath
            guard let u = URL(string: "\(scheme)://\(host)\(port)\(path)") else { return nil }
            controlURL = u
        }

        return DLNARenderer(
            id: usn,
            friendlyName: parser.friendlyName ?? host,
            manufacturer: parser.manufacturer ?? "",
            modelName: parser.modelName ?? "",
            location: location,
            baseURL: baseURL,
            avTransportControlURL: controlURL
        )
    }

}

// MARK: - XML parser

private final class DeviceDescriptionParser: NSObject, XMLParserDelegate {
    var friendlyName: String?
    var manufacturer: String?
    var modelName: String?
    var avTransportControlURL: String?
    var hasDIAL: Bool = false

    private var currentElement = ""
    private var buffer = ""

    // Текущее описание сервиса внутри <service>...</service>.
    private var inService = false
    private var currentServiceType: String?
    private var currentControlURL: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        buffer = ""
        if elementName == "service" {
            inService = true
            currentServiceType = nil
            currentControlURL = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if inService {
            switch elementName {
            case "serviceType": currentServiceType = value
            case "controlURL":  currentControlURL = value
            case "service":
                if let type = currentServiceType {
                    if type.contains("AVTransport"), let url = currentControlURL {
                        avTransportControlURL = url
                    }
                    if type.contains("dial-multiscreen") {
                        hasDIAL = true
                    }
                }
                inService = false
            default: break
            }
        } else {
            switch elementName {
            case "friendlyName": if friendlyName == nil { friendlyName = value }
            case "manufacturer": if manufacturer == nil { manufacturer = value }
            case "modelName":    if modelName == nil { modelName = value }
            default: break
            }
        }
        buffer = ""
    }
}
