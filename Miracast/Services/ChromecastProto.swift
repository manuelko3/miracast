import Foundation

/// Минимальный ручной кодер/декодер protobuf'а для CASTV2 CastMessage.
///
/// Поддерживает только нужные нам wire types (varint, length-delimited) — этого достаточно
/// для всех полей CastMessage (1..6). Реализация без зависимостей, тестируемая в изоляции.
enum ChromecastProto {

    // MARK: - Encode

    static func encodeVarint(_ value: UInt64) -> Data {
        var out = Data()
        var v = value
        while v >= 0x80 {
            out.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        out.append(UInt8(v & 0x7F))
        return out
    }

    static func encodeVarintField(fieldNumber: Int, value: UInt64) -> Data {
        let tag = (UInt64(fieldNumber) << 3) | 0 // wire type 0
        var out = encodeVarint(tag)
        out.append(encodeVarint(value))
        return out
    }

    static func encodeStringField(fieldNumber: Int, value: String) -> Data {
        let tag = (UInt64(fieldNumber) << 3) | 2 // wire type 2
        var out = encodeVarint(tag)
        let bytes = Data(value.utf8)
        out.append(encodeVarint(UInt64(bytes.count)))
        out.append(bytes)
        return out
    }

    // MARK: - Decode

    /// Декодирует CastMessage в словарь fieldNumber → Any.
    /// varint поля возвращаются как `Int`, length-delimited — как `String` (UTF-8).
    static func decodeMessage(_ data: Data) -> [Int: Any] {
        var out: [Int: Any] = [:]
        var i = data.startIndex
        while i < data.endIndex {
            guard let (tag, tagLen) = readVarint(data, at: i) else { break }
            i += tagLen
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)

            switch wireType {
            case 0:
                guard let (v, n) = readVarint(data, at: i) else { return out }
                i += n
                out[fieldNumber] = Int(v)
            case 2:
                guard let (len, n) = readVarint(data, at: i) else { return out }
                i += n
                let end = i + Int(len)
                guard end <= data.endIndex else { return out }
                let sub = data.subdata(in: i..<end)
                out[fieldNumber] = String(data: sub, encoding: .utf8) ?? ""
                i = end
            case 5: i += 4
            case 1: i += 8
            default: return out
            }
        }
        return out
    }

    static func readVarint(_ data: Data, at start: Data.Index) -> (UInt64, Int)? {
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
}
