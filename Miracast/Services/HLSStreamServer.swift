import Foundation
import Network
import os

/// Лёгкий HTTP сервер для раздачи живого HLS-потока (fMP4).
///
/// Endpoints:
///   GET /<token>/stream.m3u8 — live playlist
///   GET /<token>/init.mp4    — initialization segment
///   GET /<token>/seg{N}.m4s  — media segments из кольцевого буфера
///
/// Безопасность:
///   1. Listener ограничен Wi-Fi интерфейсом (никакого cellular / VPN раскрытия).
///   2. Все URL содержат случайный 32-символьный токен в первом сегменте пути.
///      Без правильного токена сервер возвращает 404 — посторонний в той же сети не
///      сможет случайно угадать URL и получить экран пользователя.
final class HLSStreamServer {

    private let log = Logger(subsystem: "miracast.Miracast", category: "hls")

    // MARK: - Config

    static let windowSize = 6
    static let targetDuration = 3

    // MARK: - Public

    private(set) var port: UInt16 = 0
    private(set) var isRunning = false
    private(set) var token: String = ""

    // MARK: - Private state

    private let accessQueue = DispatchQueue(label: "miracast.hls.state")
    private let listenerQueue = DispatchQueue(label: "miracast.hls.listener")

    private var listener: NWListener?
    private var initSegment: Data?
    private var segments: [Segment] = []
    private var nextSegmentIndex: Int = 0
    private var mediaSequence: Int = 0
    private var firstSegmentContinuation: CheckedContinuation<Void, Never>?
    private var firstSegmentDelivered = false

    private struct Segment {
        let index: Int
        let data: Data
        let duration: Double
    }

    // MARK: - Lifecycle

    /// Стартует на свободном порту. Корректно ждёт `listener.ready` через continuation,
    /// никакого busy-wait. Возвращает (port, token).
    func start(preferredPort: UInt16 = 7000) async throws -> (port: UInt16, token: String) {
        self.token = Self.makeToken()
        self.firstSegmentDelivered = false
        self.firstSegmentContinuation = nil

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi   // блокируем cellular / VPN

        let listener: NWListener
        if let nwPort = NWEndpoint.Port(rawValue: preferredPort) {
            do { listener = try NWListener(using: params, on: nwPort) }
            catch { listener = try NWListener(using: params) }
        } else {
            listener = try NWListener(using: params)
        }
        self.listener = listener

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(UInt16, String), Error>) in
            var resumed = false

            listener.newConnectionHandler = { [weak self] conn in
                self?.handle(connection: conn)
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    if !resumed, let p = listener.port?.rawValue {
                        resumed = true
                        self.port = p
                        self.isRunning = true
                        self.log.info("ready on :\(p, privacy: .public)")
                        cont.resume(returning: (p, self.token))
                    }
                case .failed(let e):
                    if !resumed {
                        resumed = true
                        cont.resume(throwing: e)
                    } else {
                        self.log.error("listener failed: \(e.localizedDescription, privacy: .public)")
                    }
                default: break
                }
            }

            listener.start(queue: listenerQueue)
        }
    }

    func stop() {
        isRunning = false
        listener?.cancel()
        listener = nil
        accessQueue.sync {
            segments.removeAll()
            initSegment = nil
            nextSegmentIndex = 0
            mediaSequence = 0
        }
    }

    // MARK: - Feed

    func setInitSegment(_ data: Data) {
        accessQueue.sync { self.initSegment = data }
    }

    func appendSegment(_ data: Data, duration: Double) {
        var notifyContinuation: CheckedContinuation<Void, Never>?
        accessQueue.sync {
            let seg = Segment(index: nextSegmentIndex, data: data, duration: duration)
            segments.append(seg)
            nextSegmentIndex += 1
            while segments.count > Self.windowSize {
                let removed = segments.removeFirst()
                mediaSequence = removed.index + 1
            }
            // Первый медиа-сегмент готов → разбудим того, кто ждал.
            if !firstSegmentDelivered, initSegment != nil {
                firstSegmentDelivered = true
                notifyContinuation = firstSegmentContinuation
                firstSegmentContinuation = nil
            }
        }
        notifyContinuation?.resume()
    }

    /// Дожидается публикации init-segment'а и первого media-segment'а.
    /// Возвращается сразу, если они уже есть. Защищает от выдачи "пустого плейлиста".
    func waitForFirstSegment() async {
        let alreadyHave: Bool = accessQueue.sync {
            firstSegmentDelivered
        }
        if alreadyHave { return }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            accessQueue.sync {
                if firstSegmentDelivered {
                    cont.resume()
                } else {
                    firstSegmentContinuation = cont
                }
            }
        }
    }

    // MARK: - Connection

    private func handle(connection conn: NWConnection) {
        conn.start(queue: listenerQueue)
        readRequest(conn: conn, buffer: Data())
    }

    private func readRequest(conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if error != nil { conn.cancel(); return }
            var acc = buffer
            if let data = data { acc.append(data) }

            if let range = acc.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) {
                let head = acc[..<range.lowerBound]
                if let text = String(data: head, encoding: .utf8) {
                    self.respond(to: text, on: conn)
                    return
                }
            }

            if isComplete { conn.cancel(); return }
            if acc.count > 64 * 1024 { conn.cancel(); return }
            self.readRequest(conn: conn, buffer: acc)
        }
    }

    private func respond(to headerText: String, on conn: NWConnection) {
        let firstLine = headerText.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0].uppercased() == "GET" else {
            send(conn: conn, status: "400 Bad Request", body: Data()); return
        }
        let rawPath = parts[1]

        // Удаляем query string (если есть).
        let path = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawPath

        // Все ресурсы должны начинаться с /<token>/.
        let prefix = "/\(token)/"
        guard path.hasPrefix(prefix) else {
            send(conn: conn, status: "404 Not Found", body: Data()); return
        }
        let relative = String(path.dropFirst(prefix.count))

        switch relative {
        case "stream.m3u8":
            let playlist = renderPlaylist()
            send(conn: conn,
                 status: "200 OK",
                 headers: ["Content-Type": "application/vnd.apple.mpegurl",
                           "Cache-Control": "no-cache"],
                 body: Data(playlist.utf8))

        case "init.mp4":
            let data = accessQueue.sync { initSegment } ?? Data()
            if data.isEmpty { send(conn: conn, status: "404 Not Found", body: Data()); return }
            send(conn: conn,
                 status: "200 OK",
                 headers: ["Content-Type": "video/mp4",
                           "Cache-Control": "no-cache"],
                 body: data)

        default:
            if relative.hasPrefix("seg"), relative.hasSuffix(".m4s"),
               let n = Int(relative.dropFirst(3).dropLast(4)),
               let segment = accessQueue.sync(execute: { segments.first(where: { $0.index == n }) }) {
                send(conn: conn,
                     status: "200 OK",
                     headers: ["Content-Type": "video/iso.segment",
                               "Cache-Control": "no-cache"],
                     body: segment.data)
            } else {
                send(conn: conn, status: "404 Not Found", body: Data())
            }
        }
    }

    private func renderPlaylist() -> String {
        accessQueue.sync {
            var out = ""
            out += "#EXTM3U\n"
            out += "#EXT-X-VERSION:7\n"
            out += "#EXT-X-TARGETDURATION:\(Self.targetDuration)\n"
            out += "#EXT-X-MEDIA-SEQUENCE:\(mediaSequence)\n"
            out += "#EXT-X-PLAYLIST-TYPE:EVENT\n"
            out += "#EXT-X-MAP:URI=\"init.mp4\"\n"
            for seg in segments {
                out += String(format: "#EXTINF:%.3f,\n", seg.duration)
                out += "seg\(seg.index).m4s\n"
            }
            return out
        }
    }

    private func send(conn: NWConnection,
                      status: String,
                      headers: [String: String] = [:],
                      body: Data) {
        var h = "HTTP/1.1 \(status)\r\n"
        h += "Content-Length: \(body.count)\r\n"
        h += "Connection: close\r\n"
        for (k, v) in headers { h += "\(k): \(v)\r\n" }
        h += "\r\n"
        var out = Data(h.utf8)
        out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: - Token

    private static func makeToken() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
