import Foundation

/// SOAP-клиент для DLNA AVTransport:1.
/// Отправляет команды SetAVTransportURI / Play / Stop / Pause на выбранный рендерер.
final class DLNAController {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    enum ControllerError: Error {
        case httpStatus(Int, body: String)
        case invalidResponse
    }

    // MARK: - Public API

    /// Задаёт URI текущего медиа и запускает воспроизведение.
    func playMedia(on renderer: DLNARenderer,
                   url: URL,
                   mimeType: String,
                   title: String = "Miracast Screen",
                   completion: @escaping (Result<Void, Error>) -> Void) {
        setAVTransportURI(on: renderer, mediaURL: url, mimeType: mimeType, title: title) { [weak self] result in
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success:
                self?.play(on: renderer, completion: completion)
            }
        }
    }

    func stop(on renderer: DLNARenderer, completion: @escaping (Result<Void, Error>) -> Void) {
        let body = """
        <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
          <InstanceID>0</InstanceID>
        </u:Stop>
        """
        send(action: "Stop", body: body, to: renderer, completion: completion)
    }

    // MARK: - Private

    private func setAVTransportURI(on renderer: DLNARenderer,
                                   mediaURL: URL,
                                   mimeType: String,
                                   title: String,
                                   completion: @escaping (Result<Void, Error>) -> Void) {
        let metadata = didlLiteMetadata(url: mediaURL, mimeType: mimeType, title: title)
        let body = """
        <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
          <InstanceID>0</InstanceID>
          <CurrentURI>\(xmlEscape(mediaURL.absoluteString))</CurrentURI>
          <CurrentURIMetaData>\(xmlEscape(metadata))</CurrentURIMetaData>
        </u:SetAVTransportURI>
        """
        send(action: "SetAVTransportURI", body: body, to: renderer, completion: completion)
    }

    private func play(on renderer: DLNARenderer,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        let body = """
        <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
          <InstanceID>0</InstanceID>
          <Speed>1</Speed>
        </u:Play>
        """
        send(action: "Play", body: body, to: renderer, completion: completion)
    }

    // MARK: - SOAP transport

    private func send(action: String,
                      body: String,
                      to renderer: DLNARenderer,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
                    s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>\(body)</s:Body>
        </s:Envelope>
        """

        var req = URLRequest(url: renderer.avTransportControlURL, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.addValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.addValue("\"urn:schemas-upnp-org:service:AVTransport:1#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        req.httpBody = envelope.data(using: .utf8)

        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(ControllerError.invalidResponse)); return
            }
            if (200..<300).contains(http.statusCode) {
                completion(.success(()))
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                completion(.failure(ControllerError.httpStatus(http.statusCode, body: body)))
            }
        }.resume()
    }

    // MARK: - DIDL-Lite / XML

    private func didlLiteMetadata(url: URL, mimeType: String, title: String) -> String {
        // Минимально-совместимый DIDL-Lite. Поле dlna:profileName подбираем по MIME.
        let profile = dlnaProfile(for: mimeType)
        let upnpClass = mimeType.hasPrefix("video/") ? "object.item.videoItem" :
                        mimeType.hasPrefix("audio/") ? "object.item.audioItem.musicTrack" :
                                                        "object.item.imageItem.photo"
        let proto = "http-get:*:\(mimeType):\(profile)"
        return """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" \
        xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" \
        xmlns:dlna="urn:schemas-dlna-org:metadata-1-0/">
          <item id="miracast-screen" parentID="0" restricted="1">
            <dc:title>\(title)</dc:title>
            <upnp:class>\(upnpClass)</upnp:class>
            <res protocolInfo="\(proto)">\(url.absoluteString)</res>
          </item>
        </DIDL-Lite>
        """
    }

    private func dlnaProfile(for mimeType: String) -> String {
        switch mimeType {
        case "application/vnd.apple.mpegurl", "application/x-mpegurl":
            return "DLNA.ORG_PN=HLS;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000"
        case "video/mp4":
            return "DLNA.ORG_PN=AVC_MP4_HP_HD_AAC;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000"
        case "video/mpeg":
            return "DLNA.ORG_PN=MPEG_TS_SD_NA_ISO;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000"
        default:
            return "*"
        }
    }

    private func xmlEscape(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&", with: "&amp;")
        r = r.replacingOccurrences(of: "<", with: "&lt;")
        r = r.replacingOccurrences(of: ">", with: "&gt;")
        r = r.replacingOccurrences(of: "\"", with: "&quot;")
        r = r.replacingOccurrences(of: "'", with: "&apos;")
        return r
    }
}
