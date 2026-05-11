import Foundation
import Network
import Security

/// Минимальный клиент Chromecast / Google Cast (CASTV2 protocol).
///
/// Реализован без google-cast-sdk. Протокол:
/// 1. TLS-соединение на tcp://<host>:8009 (Chromecast использует self-signed сертификат —
///    верификацию отключаем явно).
/// 2. Сообщения сериализуются как 4-байтовый big-endian длиной + protobuf-сообщение `CastMessage`.
///    Мы вручную кодируем/декодируем 6 полей proto без библиотеки.
/// 3. Поверх protobuf передаётся JSON в поле `payload_utf8` по namespace.
///
/// Сценарий `load(url:)`:
///   CONNECT (receiver) → LAUNCH "CC1AD845" (Default Media Receiver) → ждём RECEIVER_STATUS
///   → берём sessionId + transportId → CONNECT (transportId) → LOAD → готово.
///
/// После LOAD Chromecast уже сам подтягивает медиа по URL — наш main app может
/// продолжать работу (или быть закрыт), стрим не прервётся, потому что HLS раздаёт
/// Broadcast Upload Extension в отдельном процессе.
final class ChromecastController {

    struct MediaInfo {
        var url: String
        var contentType: String   // "application/vnd.apple.mpegurl" для HLS
        var title: String
        var isLive: Bool          // true — STREAM_TYPE_LIVE, false — BUFFERED
    }

    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "miracast.chromecast")
    private var connection: NWConnection?
    private var receiveBuffer = Data()

    private let senderID = "sender-0"
    private let receiverID = "receiver-0"
    private var currentTransportID: String?
    private var currentSessionID: String?
    private var requestCounter: Int = 1
    /// requestId, отправленный с LOAD-сообщением. MEDIA_STATUS считается ответом на наш LOAD
    /// только если у него `requestId == loadRequestID`. Это защищает от ложного "успех" из
    /// предыдущей сессии Chromecast, которая могла висеть.
    private var loadRequestID: Int?

    private var pendingLoad: ((Result<Void, Error>) -> Void)?
    private var heartbeatTimer: DispatchSourceTimer?
    private var timeoutWorkItem: DispatchWorkItem?

    init(host: String, port: UInt16 = 8009) {
        self.host = host
        self.port = port
    }

    // MARK: - Public API

    func load(_ media: MediaInfo, completion: @escaping (Result<Void, Error>) -> Void) {
        self.pendingLoad = completion
        self.pendingMedia = media
        connect()

        // Общий таймаут сценария.
        let wi = DispatchWorkItem { [weak self] in
            self?.finishLoad(.failure(NSError(domain: "Chromecast", code: -100,
                                              userInfo: [NSLocalizedDescriptionKey: "Timeout (10s)"])))
        }
        timeoutWorkItem = wi
        queue.asyncAfter(deadline: .now() + 10, execute: wi)
    }

    func stop(completion: ((Error?) -> Void)? = nil) {
        if let transportID = currentTransportID {
            let payload: [String: Any] = ["type": "STOP", "requestId": nextRequestID()]
            sendJSON(payload: payload,
                     namespace: "urn:x-cast:com.google.cast.media",
                     destinationID: transportID)
        }
        // Закрываем через 0.3 сек чтобы STOP успел улететь.
        queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.teardown()
            completion?(nil)
        }
    }

    // MARK: - Private

    private var pendingMedia: MediaInfo?

    private func connect() {
        let tls = NWProtocolTLS.Options()
        // Отключаем верификацию — Chromecast использует самоподписанный сертификат.
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions,
            { _, _, complete in complete(true) }, queue)

        let params = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        let conn = NWConnection(host: NWEndpoint.Host(host),
                                port: NWEndpoint.Port(rawValue: port) ?? 8009,
                                using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.onConnected()
            case .failed(let e), .waiting(let e):
                self.finishLoad(.failure(e))
            case .cancelled:
                break
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func onConnected() {
        receive()
        // 1. CONNECT в receiver.
        sendJSON(payload: ["type": "CONNECT", "userAgent": "Miracast/1.0"],
                 namespace: "urn:x-cast:com.google.cast.tp.connection",
                 destinationID: receiverID)

        // 2. Heartbeat каждые 5 сек (PING / PONG).
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.sendJSON(payload: ["type": "PING"],
                          namespace: "urn:x-cast:com.google.cast.tp.heartbeat",
                          destinationID: self.receiverID)
        }
        timer.resume()
        heartbeatTimer = timer

        // 3. LAUNCH Default Media Receiver.
        sendJSON(payload: ["type": "LAUNCH", "requestId": nextRequestID(), "appId": "CC1AD845"],
                 namespace: "urn:x-cast:com.google.cast.receiver",
                 destinationID: receiverID)
    }

    private func receive() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64_000) { [weak self] data, _, _, err in
            guard let self = self else { return }
            if let err = err {
                self.finishLoad(.failure(err))
                return
            }
            if let data = data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.drainBuffer()
            }
            if conn.state == .ready {
                self.receive()
            }
        }
    }

    private func drainBuffer() {
        while receiveBuffer.count >= 4 {
            let lenBytes = receiveBuffer.prefix(4)
            let length = Int(
                (UInt32(lenBytes[lenBytes.startIndex]) << 24) |
                (UInt32(lenBytes[lenBytes.startIndex + 1]) << 16) |
                (UInt32(lenBytes[lenBytes.startIndex + 2]) << 8) |
                 UInt32(lenBytes[lenBytes.startIndex + 3])
            )
            guard receiveBuffer.count >= 4 + length else { return }
            let messageData = receiveBuffer.subdata(in: (receiveBuffer.startIndex + 4)..<(receiveBuffer.startIndex + 4 + length))
            receiveBuffer.removeSubrange(receiveBuffer.startIndex..<(receiveBuffer.startIndex + 4 + length))
            handleProtobufMessage(messageData)
        }
    }

    private func handleProtobufMessage(_ data: Data) {
        let fields = decodeProto(data)
        guard let payload = fields[6] as? String,
              let namespace = fields[4] as? String,
              let json = parseJSON(payload) else { return }

        switch namespace {
        case "urn:x-cast:com.google.cast.receiver":
            handleReceiverStatus(json)
        case "urn:x-cast:com.google.cast.media":
            handleMediaStatus(json)
        case "urn:x-cast:com.google.cast.tp.heartbeat":
            // PING от приёмника → отвечаем PONG.
            if let type = json["type"] as? String, type == "PING" {
                sendJSON(payload: ["type": "PONG"],
                         namespace: "urn:x-cast:com.google.cast.tp.heartbeat",
                         destinationID: receiverID)
            }
        case "urn:x-cast:com.google.cast.tp.connection":
            if let type = json["type"] as? String, type == "CLOSE" {
                finishLoad(.failure(NSError(domain: "Chromecast", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "Connection closed by receiver"])))
            }
        default: break
        }
    }

    private func handleReceiverStatus(_ json: [String: Any]) {
        guard let type = json["type"] as? String, type == "RECEIVER_STATUS" else { return }
        guard let status = json["status"] as? [String: Any],
              let apps = status["applications"] as? [[String: Any]],
              let first = apps.first,
              let sessionId = first["sessionId"] as? String,
              let transportId = first["transportId"] as? String else { return }

        // Приложение ещё только запускается — дождёмся появления appId-плеера.
        let appId = first["appId"] as? String ?? ""
        guard !appId.isEmpty else { return }

        // Уже обработали этот session? Пропускаем.
        if currentSessionID == sessionId { return }
        currentSessionID = sessionId
        currentTransportID = transportId

        // 1. CONNECT ко вновь созданной сессии.
        sendJSON(payload: ["type": "CONNECT"],
                 namespace: "urn:x-cast:com.google.cast.tp.connection",
                 destinationID: transportId)

        // 2. LOAD медиа.
        guard let media = pendingMedia else { return }
        let streamType = media.isLive ? "LIVE" : "BUFFERED"
        let rid = nextRequestID()
        loadRequestID = rid
        let loadPayload: [String: Any] = [
            "type": "LOAD",
            "requestId": rid,
            "sessionId": sessionId,
            "autoplay": true,
            "currentTime": 0,
            "media": [
                "contentId": media.url,
                "contentType": media.contentType,
                "streamType": streamType,
                "metadata": [
                    "metadataType": 0,
                    "title": media.title
                ]
            ]
        ]
        sendJSON(payload: loadPayload,
                 namespace: "urn:x-cast:com.google.cast.media",
                 destinationID: transportId)
        Log.chromecast.info("LOAD sent requestId=\(rid, privacy: .public) url=\(media.url, privacy: .public)")
    }

    private func handleMediaStatus(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }
        let responseRid = (json["requestId"] as? Int) ?? -1

        if type == "LOAD_FAILED" || type == "INVALID_REQUEST" || type == "LOAD_CANCELLED" {
            // Если есть requestId — реагируем только на свой; если его нет, считаем что наш и есть.
            if responseRid == loadRequestID || loadRequestID == nil {
                let msg = (json["reason"] as? String) ?? type
                finishLoad(.failure(NSError(domain: "Chromecast", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "Load failed: \(msg)"])))
            }
            return
        }

        if type == "MEDIA_STATUS" {
            // Принимаем только MEDIA_STATUS с нашим requestId — иначе это эхо предыдущей сессии.
            guard let expected = loadRequestID, responseRid == expected else { return }
            // Уточняем что плеер действительно играет / буферизует наш контент.
            let statusArray = json["status"] as? [[String: Any]] ?? []
            let playerState = statusArray.first?["playerState"] as? String ?? ""
            Log.chromecast.info("MEDIA_STATUS playerState=\(playerState, privacy: .public)")
            // Любое валидное состояние после LOAD значит "приёмник принял медиа".
            finishLoad(.success(()))
        }
    }

    private func sendJSON(payload: [String: Any], namespace: String, destinationID: String) {
        guard let conn = connection else { return }
        let jsonData = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        var message = Data()
        encodeVarintField(fieldNumber: 1, value: 0, into: &message)      // protocol_version = 0 (CASTV2_1_0)
        encodeStringField(fieldNumber: 2, value: senderID, into: &message)
        encodeStringField(fieldNumber: 3, value: destinationID, into: &message)
        encodeStringField(fieldNumber: 4, value: namespace, into: &message)
        encodeVarintField(fieldNumber: 5, value: 0, into: &message)      // payload_type = 0 (STRING)
        encodeStringField(fieldNumber: 6, value: jsonString, into: &message)

        var framed = Data()
        let len = UInt32(message.count)
        framed.append(UInt8((len >> 24) & 0xFF))
        framed.append(UInt8((len >> 16) & 0xFF))
        framed.append(UInt8((len >> 8) & 0xFF))
        framed.append(UInt8(len & 0xFF))
        framed.append(message)

        conn.send(content: framed, completion: .contentProcessed { _ in })
    }

    private func nextRequestID() -> Int {
        defer { requestCounter += 1 }
        return requestCounter
    }

    private func finishLoad(_ result: Result<Void, Error>) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let cb = self.pendingLoad else { return }
            self.pendingLoad = nil
            self.timeoutWorkItem?.cancel()
            DispatchQueue.main.async { cb(result) }
        }
    }

    private func teardown() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        connection?.cancel()
        connection = nil
        receiveBuffer.removeAll()
        currentTransportID = nil
        currentSessionID = nil
        pendingMedia = nil
        loadRequestID = nil
    }

    // MARK: - Protobuf (минимальный ручной кодер/декодер)

    private func encodeVarint(_ value: UInt64, into out: inout Data) {
        var v = value
        while v >= 0x80 {
            out.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        out.append(UInt8(v & 0x7F))
    }

    private func encodeVarintField(fieldNumber: Int, value: UInt64, into out: inout Data) {
        let tag = (UInt64(fieldNumber) << 3) | 0 // wire type 0
        encodeVarint(tag, into: &out)
        encodeVarint(value, into: &out)
    }

    private func encodeStringField(fieldNumber: Int, value: String, into out: inout Data) {
        let tag = (UInt64(fieldNumber) << 3) | 2 // wire type 2 (length-delimited)
        encodeVarint(tag, into: &out)
        let bytes = Data(value.utf8)
        encodeVarint(UInt64(bytes.count), into: &out)
        out.append(bytes)
    }

    /// Декодирует protobuf CastMessage в словарь fieldNumber → Any (Int для varint, String для bytes).
    private func decodeProto(_ data: Data) -> [Int: Any] {
        var out: [Int: Any] = [:]
        var i = data.startIndex
        while i < data.endIndex {
            guard let (tag, tagLen) = readVarint(data, at: i) else { break }
            i += tagLen
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)

            switch wireType {
            case 0: // varint
                guard let (v, n) = readVarint(data, at: i) else { return out }
                i += n
                out[fieldNumber] = Int(v)
            case 2: // length-delimited
                guard let (len, n) = readVarint(data, at: i) else { return out }
                i += n
                let end = i + Int(len)
                guard end <= data.endIndex else { return out }
                let sub = data.subdata(in: i..<end)
                out[fieldNumber] = String(data: sub, encoding: .utf8) ?? ""
                i = end
            case 5: // fixed32
                i += 4
            case 1: // fixed64
                i += 8
            default:
                return out
            }
        }
        return out
    }

    private func readVarint(_ data: Data, at start: Data.Index) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var idx = start
        var consumed = 0
        while idx < data.endIndex {
            let byte = data[idx]
            result |= UInt64(byte & 0x7F) << shift
            consumed += 1
            idx = data.index(after: idx)
            if (byte & 0x80) == 0 {
                return (result, consumed)
            }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
