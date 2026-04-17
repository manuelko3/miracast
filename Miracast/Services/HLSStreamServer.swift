import Foundation
import Network

/// Лёгкий HTTP сервер для раздачи живого HLS-потока (fMP4).
///
/// Endpoints:
///   GET /stream.m3u8     — live playlist
///   GET /init.mp4        — initialization segment (EXT-X-MAP)
///   GET /seg{N}.m4s      — media segments из кольцевого буфера
///
/// Сегменты хранятся в RAM, старые автоматически удаляются при переполнении.
final class HLSStreamServer {

    // MARK: - Config

    /// Сколько последних сегментов держать в буфере.
    static let windowSize = 6
    /// Максимальная длительность одного сегмента (для TARGETDURATION).
    static let targetDuration = 3

    // MARK: - Public

    private(set) var port: UInt16 = 0
    private(set) var isRunning = false

    // MARK: - Private state

    private let accessQueue = DispatchQueue(label: "miracast.hls.state")
    private let listenerQueue = DispatchQueue(label: "miracast.hls.listener")

    private var listener: NWListener?
    private var initSegment: Data?
    private var segments: [Segment] = []   // кольцевой буфер
    private var nextSegmentIndex: Int = 0  // монотонно растущий
    private var mediaSequence: Int = 0     // индекс самого старого ещё доступного сегмента

    private struct Segment {
        let index: Int
        let data: Data
        let duration: Double
    }

    // MARK: - Lifecycle

    /// Стартует на случайном свободном порту и возвращает его при успехе.
    func start(preferredPort: UInt16 = 7000) throws -> UInt16 {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let listener: NWListener
        if let nwPort = NWEndpoint.Port(rawValue: preferredPort) {
            do {
                listener = try NWListener(using: params, on: nwPort)
            } catch {
                // Если порт занят — берём любой свободный.
                listener = try NWListener(using: params)
            }
        } else {
            listener = try NWListener(using: params)
        }

        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let p = self?.listener?.port?.rawValue {
                    self?.port = p
                    print("🌐 HLS server ready on :\(p)")
                }
            case .failed(let e):
                print("❌ HLS listener failed: \(e)")
            default: break
            }
        }

        listener.start(queue: listenerQueue)
        self.listener = listener
        self.isRunning = true

        // Ждём ready максимум 1 секунду для получения порта.
        let deadline = Date().addingTimeInterval(1.0)
        while port == 0 && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        return port
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
        accessQueue.sync {
            let seg = Segment(index: nextSegmentIndex, data: data, duration: duration)
            segments.append(seg)
            nextSegmentIndex += 1
            while segments.count > Self.windowSize {
                let removed = segments.removeFirst()
                mediaSequence = removed.index + 1
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
            if let error = error {
                print("HLS recv err: \(error)")
                conn.cancel()
                return
            }
            var acc = buffer
            if let data = data { acc.append(data) }

            // Смотрим, пришёл ли полностью хедер (двойной CRLF).
            if let range = acc.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) {
                let head = acc[..<range.lowerBound]
                if let text = String(data: head, encoding: .utf8) {
                    self.respond(to: text, on: conn)
                    return
                }
            }

            if isComplete {
                conn.cancel()
                return
            }
            if acc.count > 64 * 1024 { conn.cancel(); return }
            self.readRequest(conn: conn, buffer: acc)
        }
    }

    private func respond(to headerText: String, on conn: NWConnection) {
        let firstLine = headerText.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0].uppercased() == "GET" else {
            send(conn: conn, status: "400 Bad Request", body: Data())
            return
        }
        let path = parts[1]
        print("HLS GET \(path)")

        if path == "/stream.m3u8" {
            let playlist = renderPlaylist()
            send(conn: conn,
                 status: "200 OK",
                 headers: ["Content-Type": "application/vnd.apple.mpegurl",
                           "Cache-Control": "no-cache"],
                 body: Data(playlist.utf8))
            return
        }

        if path == "/init.mp4" {
            let data = accessQueue.sync { initSegment } ?? Data()
            if data.isEmpty { send(conn: conn, status: "404 Not Found", body: Data()); return }
            send(conn: conn,
                 status: "200 OK",
                 headers: ["Content-Type": "video/mp4",
                           "Cache-Control": "no-cache"],
                 body: data)
            return
        }

        if path.hasPrefix("/seg"), path.hasSuffix(".m4s") {
            let numStr = path.dropFirst(4).dropLast(4)
            if let n = Int(numStr),
               let segment = accessQueue.sync(execute: { segments.first(where: { $0.index == n }) }) {
                send(conn: conn,
                     status: "200 OK",
                     headers: ["Content-Type": "video/iso.segment",
                               "Cache-Control": "no-cache"],
                     body: segment.data)
                return
            }
        }

        send(conn: conn, status: "404 Not Found", body: Data())
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
}
