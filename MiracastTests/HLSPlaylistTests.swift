import XCTest
@testable import Miracast

final class HLSPlaylistTests: XCTestCase {

    func testEmptyPlaylistHasRequiredHeaders() {
        let playlist = HLSPlaylist.render(segments: [], mediaSequence: 0, targetDuration: 3)
        XCTAssertTrue(playlist.hasPrefix("#EXTM3U\n"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:7"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
        XCTAssertTrue(playlist.contains(#"#EXT-X-MAP:URI="init.mp4""#))
    }

    func testPlaylistContainsAllSegments() {
        let segs = [
            HLSPlaylist.Segment(index: 0, duration: 2.500),
            HLSPlaylist.Segment(index: 1, duration: 2.750),
            HLSPlaylist.Segment(index: 2, duration: 3.000),
        ]
        let playlist = HLSPlaylist.render(segments: segs, mediaSequence: 0, targetDuration: 3)

        XCTAssertTrue(playlist.contains("#EXTINF:2.500,"))
        XCTAssertTrue(playlist.contains("seg0.m4s"))
        XCTAssertTrue(playlist.contains("#EXTINF:2.750,"))
        XCTAssertTrue(playlist.contains("seg1.m4s"))
        XCTAssertTrue(playlist.contains("#EXTINF:3.000,"))
        XCTAssertTrue(playlist.contains("seg2.m4s"))
    }

    func testMediaSequenceReflectsEvictedSegments() {
        // После эвикта первых трёх сегментов media-sequence должен сдвинуться к индексу первого
        // оставшегося — иначе плеер думает что это новый поток и перезагружает init.
        let segs = [
            HLSPlaylist.Segment(index: 3, duration: 3.0),
            HLSPlaylist.Segment(index: 4, duration: 3.0),
        ]
        let playlist = HLSPlaylist.render(segments: segs, mediaSequence: 3, targetDuration: 3)
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:3"))
        XCTAssertFalse(playlist.contains("seg0.m4s"))
        XCTAssertFalse(playlist.contains("seg1.m4s"))
        XCTAssertFalse(playlist.contains("seg2.m4s"))
        XCTAssertTrue(playlist.contains("seg3.m4s"))
        XCTAssertTrue(playlist.contains("seg4.m4s"))
    }

    func testNoEndlistMarker() {
        // EVENT-плейлист без #EXT-X-ENDLIST — обязательно для live.
        let segs = [HLSPlaylist.Segment(index: 0, duration: 3.0)]
        let playlist = HLSPlaylist.render(segments: segs, mediaSequence: 0, targetDuration: 3)
        XCTAssertFalse(playlist.contains("#EXT-X-ENDLIST"))
    }

    func testCustomInitSegmentURI() {
        let playlist = HLSPlaylist.render(segments: [], mediaSequence: 0, targetDuration: 3,
                                          initSegmentURI: "video-init.mp4")
        XCTAssertTrue(playlist.contains(#"#EXT-X-MAP:URI="video-init.mp4""#))
    }

    func testSegmentDurationFormatting() {
        // Длительность должна форматироваться с 3 знаками после запятой (точность IDR/GOP).
        let segs = [HLSPlaylist.Segment(index: 0, duration: 1.0/3.0)]
        let playlist = HLSPlaylist.render(segments: segs, mediaSequence: 0, targetDuration: 3)
        XCTAssertTrue(playlist.contains("#EXTINF:0.333,"))
    }
}
