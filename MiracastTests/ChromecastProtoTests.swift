import XCTest
@testable import Miracast

final class ChromecastProtoTests: XCTestCase {

    // MARK: - varint

    func testEncodeVarintSingleByte() {
        XCTAssertEqual(ChromecastProto.encodeVarint(0), Data([0x00]))
        XCTAssertEqual(ChromecastProto.encodeVarint(1), Data([0x01]))
        XCTAssertEqual(ChromecastProto.encodeVarint(127), Data([0x7F]))
    }

    func testEncodeVarintMultiByte() {
        XCTAssertEqual(ChromecastProto.encodeVarint(128), Data([0x80, 0x01]))
        XCTAssertEqual(ChromecastProto.encodeVarint(300), Data([0xAC, 0x02]))
        XCTAssertEqual(ChromecastProto.encodeVarint(16384), Data([0x80, 0x80, 0x01]))
    }

    func testReadVarintRoundTrip() {
        for value: UInt64 in [0, 1, 127, 128, 255, 300, 16384, 1_000_000, UInt64.max] {
            let encoded = ChromecastProto.encodeVarint(value)
            guard let (decoded, consumed) = ChromecastProto.readVarint(encoded, at: encoded.startIndex) else {
                XCTFail("Failed to decode \(value)"); continue
            }
            XCTAssertEqual(decoded, value, "varint round-trip mismatch for \(value)")
            XCTAssertEqual(consumed, encoded.count, "varint consumed wrong length for \(value)")
        }
    }

    // MARK: - varint field

    func testEncodeVarintFieldProtocolVersion() {
        // field 1, wire type 0, value 0
        // tag = (1 << 3) | 0 = 0x08, value = 0x00
        let encoded = ChromecastProto.encodeVarintField(fieldNumber: 1, value: 0)
        XCTAssertEqual(encoded, Data([0x08, 0x00]))
    }

    func testEncodeVarintFieldPayloadType() {
        // field 5, wire type 0, value 0
        // tag = (5 << 3) | 0 = 0x28
        let encoded = ChromecastProto.encodeVarintField(fieldNumber: 5, value: 0)
        XCTAssertEqual(encoded, Data([0x28, 0x00]))
    }

    // MARK: - string field

    func testEncodeStringFieldEmpty() {
        // field 2, wire type 2, length 0
        // tag = (2 << 3) | 2 = 0x12, length = 0x00
        let encoded = ChromecastProto.encodeStringField(fieldNumber: 2, value: "")
        XCTAssertEqual(encoded, Data([0x12, 0x00]))
    }

    func testEncodeStringFieldShort() {
        // field 2, wire type 2, length 6, "sender"
        let encoded = ChromecastProto.encodeStringField(fieldNumber: 2, value: "sender")
        var expected = Data([0x12, 0x06])
        expected.append(Data("sender".utf8))
        XCTAssertEqual(encoded, expected)
    }

    // MARK: - full CastMessage round-trip

    func testCastMessageRoundTrip() {
        var message = Data()
        message.append(ChromecastProto.encodeVarintField(fieldNumber: 1, value: 0))                                   // protocol_version
        message.append(ChromecastProto.encodeStringField(fieldNumber: 2, value: "sender-0"))                          // source_id
        message.append(ChromecastProto.encodeStringField(fieldNumber: 3, value: "receiver-0"))                        // destination_id
        message.append(ChromecastProto.encodeStringField(fieldNumber: 4, value: "urn:x-cast:com.google.cast.receiver")) // namespace
        message.append(ChromecastProto.encodeVarintField(fieldNumber: 5, value: 0))                                   // payload_type
        message.append(ChromecastProto.encodeStringField(fieldNumber: 6, value: #"{"type":"LAUNCH"}"#))                // payload_utf8

        let fields = ChromecastProto.decodeMessage(message)

        XCTAssertEqual(fields[1] as? Int, 0)
        XCTAssertEqual(fields[2] as? String, "sender-0")
        XCTAssertEqual(fields[3] as? String, "receiver-0")
        XCTAssertEqual(fields[4] as? String, "urn:x-cast:com.google.cast.receiver")
        XCTAssertEqual(fields[5] as? Int, 0)
        XCTAssertEqual(fields[6] as? String, #"{"type":"LAUNCH"}"#)
    }

    func testDecodeMessageWithUnicodePayload() {
        let payload = #"{"name":"тв 📺"}"#
        var message = Data()
        message.append(ChromecastProto.encodeStringField(fieldNumber: 6, value: payload))

        let fields = ChromecastProto.decodeMessage(message)
        XCTAssertEqual(fields[6] as? String, payload)
    }

    func testDecodeMalformedMessageDoesNotCrash() {
        // truncated length-delimited (says length 10 but only 3 bytes follow)
        let malformed = Data([0x12, 0x0A, 0x61, 0x62, 0x63])
        let fields = ChromecastProto.decodeMessage(malformed)
        XCTAssertTrue(fields.isEmpty || fields[2] != nil)
    }
}
