import XCTest
@testable import Miracast

final class BroadcastPreferencesTests: XCTestCase {

    // MARK: - Snapshot.streamURL

    func testStreamURLWithPortAndToken() {
        var s = BroadcastPreferences.Snapshot()
        s.hlsPort = 7000
        s.hlsToken = "abc123"
        let url = s.streamURL(host: "192.168.1.5")
        XCTAssertEqual(url?.absoluteString, "http://192.168.1.5:7000/abc123/stream.m3u8")
    }

    func testStreamURLNilWithoutToken() {
        var s = BroadcastPreferences.Snapshot()
        s.hlsPort = 7000
        s.hlsToken = nil
        XCTAssertNil(s.streamURL(host: "192.168.1.5"))
    }

    func testStreamURLNilWithoutPort() {
        var s = BroadcastPreferences.Snapshot()
        s.hlsPort = nil
        s.hlsToken = "abc"
        XCTAssertNil(s.streamURL(host: "192.168.1.5"))
    }

    func testStreamURLAcceptsLoopback() {
        var s = BroadcastPreferences.Snapshot()
        s.hlsPort = 12345
        s.hlsToken = "deadbeef"
        let url = s.streamURL(host: "127.0.0.1")
        XCTAssertEqual(url?.absoluteString, "http://127.0.0.1:12345/deadbeef/stream.m3u8")
    }

    // MARK: - Transport enum

    func testTransportRawValueRoundTrip() {
        XCTAssertEqual(BroadcastPreferences.Transport(rawValue: "dlna"), .dlna)
        XCTAssertEqual(BroadcastPreferences.Transport(rawValue: "external"), .external)
        XCTAssertNil(BroadcastPreferences.Transport(rawValue: "unknown"))
    }

    func testTransportRawValues() {
        XCTAssertEqual(BroadcastPreferences.Transport.dlna.rawValue, "dlna")
        XCTAssertEqual(BroadcastPreferences.Transport.external.rawValue, "external")
    }
}
