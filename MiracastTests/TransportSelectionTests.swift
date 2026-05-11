import XCTest
@testable import Miracast

final class TransportSelectionTests: XCTestCase {

    private func makeRenderer() -> DLNARenderer {
        DLNARenderer(
            id: "uuid:test",
            friendlyName: "Test TV",
            manufacturer: "Test",
            modelName: "Test",
            location: URL(string: "http://192.168.1.10:8080/description")!,
            baseURL: URL(string: "http://192.168.1.10:8080")!,
            avTransportControlURL: URL(string: "http://192.168.1.10:8080/control")!
        )
    }

    // MARK: - DLNA — highest priority

    func testDLNAWinsOverEverything() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.dlna, .chromecast, .airplay, .smartView],
            renderer: makeRenderer(),
            host: "192.168.1.10"
        )
        XCTAssertEqual(plan?.route, .dlna)
        XCTAssertEqual(plan?.storage, .dlna)
        XCTAssertNotNil(plan?.dlnaRenderer)
    }

    func testDLNACapabilityWithoutRendererFallsThrough() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.dlna, .chromecast],
            renderer: nil,
            host: "1.2.3.4"
        )
        XCTAssertEqual(plan?.route, .chromecast(host: "1.2.3.4"))
    }

    // MARK: - Chromecast

    func testChromecastWhenNoDLNA() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.chromecast, .airplay],
            renderer: nil,
            host: "10.0.0.5"
        )
        XCTAssertEqual(plan?.route, .chromecast(host: "10.0.0.5"))
        XCTAssertEqual(plan?.storage, .external)
        XCTAssertNil(plan?.dlnaRenderer)
    }

    func testChromecastCapabilityWithoutHostFallsThrough() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.chromecast, .airplay],
            renderer: nil,
            host: nil
        )
        XCTAssertEqual(plan?.route, .airplay)
    }

    // MARK: - AirPlay

    func testAirPlayFallback() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.airplay], renderer: nil, host: nil
        )
        XCTAssertEqual(plan?.route, .airplay)
        XCTAssertEqual(plan?.storage, .external)
    }

    // MARK: - Negative

    func testNoCapabilitiesReturnsNil() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [], renderer: nil, host: nil
        )
        XCTAssertNil(plan)
    }

    func testSmartViewOnlyReturnsNil() {
        // SmartView сам по себе не подходит для трансляции экрана — это control-канал.
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.smartView], renderer: nil, host: nil
        )
        XCTAssertNil(plan)
    }

    func testDIALOnlyReturnsNil() {
        let plan = CastScreenViewModel.selectBestTransport(
            capabilities: [.dial], renderer: nil, host: nil
        )
        XCTAssertNil(plan)
    }
}
