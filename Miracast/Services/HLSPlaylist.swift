import Foundation

/// Чистая (тестируемая) генерация HLS live playlist'а для fMP4-стрима.
///
/// Вынесена из `HLSStreamServer`, чтобы можно было покрыть unit-тестами без поднятия сокета.
enum HLSPlaylist {

    struct Segment: Equatable {
        let index: Int
        let duration: Double
    }

    /// EXT-X-VERSION: 7 — обязательно для fMP4 (#EXT-X-MAP).
    /// EXT-X-PLAYLIST-TYPE: EVENT — live stream без ENDLIST.
    static func render(segments: [Segment],
                       mediaSequence: Int,
                       targetDuration: Int,
                       initSegmentURI: String = "init.mp4") -> String {
        var out = ""
        out += "#EXTM3U\n"
        out += "#EXT-X-VERSION:7\n"
        out += "#EXT-X-TARGETDURATION:\(targetDuration)\n"
        out += "#EXT-X-MEDIA-SEQUENCE:\(mediaSequence)\n"
        out += "#EXT-X-PLAYLIST-TYPE:EVENT\n"
        out += "#EXT-X-MAP:URI=\"\(initSegmentURI)\"\n"
        for seg in segments {
            out += String(format: "#EXTINF:%.3f,\n", seg.duration)
            out += "seg\(seg.index).m4s\n"
        }
        return out
    }
}
