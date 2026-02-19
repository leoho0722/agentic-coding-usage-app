import Foundation

// MARK: - Protobuf 解碼器

/// 最小化的 protobuf wire-format 解碼器，專用於解碼 Antigravity 的權杖資料。
///
/// Wire path：outer field 6 → inner field 1（accessToken）、
/// field 3（refreshToken）、field 4.1（expirySeconds）
public enum ProtobufDecoder {

    /// 從 base64 編碼的 protobuf 資料中解碼 Antigravity 權杖。
    ///
    /// - Parameter base64String: base64 編碼的 protobuf 資料。
    /// - Returns: 解碼後的權杖，失敗時回傳 `nil`。
    public static func decodeAntigravityTokens(from base64String: String) -> AntigravityProtoTokens? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }

        // 解析外層訊息
        let outerFields = parseMessage(data)

        // 取得 field 6（length-delimited）
        guard let innerData = outerFields.lengthDelimited[6]?.first else {
            return nil
        }

        // 解析內層訊息
        let innerFields = parseMessage(innerData)

        // field 1 = accessToken（length-delimited）
        guard let accessTokenData = innerFields.lengthDelimited[1]?.first,
              let accessToken = String(data: accessTokenData, encoding: .utf8),
              !accessToken.isEmpty else {
            return nil
        }

        // field 3 = refreshToken（length-delimited）
        guard let refreshTokenData = innerFields.lengthDelimited[3]?.first,
              let refreshToken = String(data: refreshTokenData, encoding: .utf8),
              !refreshToken.isEmpty else {
            return nil
        }

        // field 4 = 巢狀訊息，其 field 1 = expirySeconds（varint）
        var expirySeconds: Int64 = 0
        if let expiryData = innerFields.lengthDelimited[4]?.first {
            let expiryFields = parseMessage(expiryData)
            if let value = expiryFields.varints[1] {
                expirySeconds = value
            }
        }

        return AntigravityProtoTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expirySeconds: expirySeconds
        )
    }
}

// MARK: - 私有輔助

private extension ProtobufDecoder {

    /// 解析後的 protobuf 欄位集合。
    struct ParsedFields {
        
        /// varint 類型欄位（field number → value）。
        var varints: [Int: Int64] = [:]
        
        /// length-delimited 類型欄位（field number → [data]，同一 field 可出現多次）。
        var lengthDelimited: [Int: [Data]] = [:]
    }

    /// 解析 protobuf wire-format 訊息。
    ///
    /// - Parameter data: 原始位元組資料。
    /// - Returns: 解析後的欄位集合。
    static func parseMessage(_ data: Data) -> ParsedFields {
        var fields = ParsedFields()
        var offset = 0

        while offset < data.count {
            guard let tag = readVarint(data, offset: &offset) else {
                break
            }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch wireType {
            case 0: // Varint
                guard let value = readVarint(data, offset: &offset) else {
                    return fields
                }
                fields.varints[fieldNumber] = value

            case 2: // Length-delimited
                guard let length = readVarint(data, offset: &offset) else {
                    return fields
                }
                let len = Int(length)
                guard offset + len <= data.count else {
                    return fields
                }
                let chunk = data[offset ..< offset + len]
                fields.lengthDelimited[fieldNumber, default: []].append(Data(chunk))
                offset += len

            case 1: // 64-bit fixed
                offset += 8

            case 5: // 32-bit fixed
                offset += 4

            default:
                return fields
            }
        }

        return fields
    }

    /// 從位元組資料中讀取 varint。
    ///
    /// - Parameters:
    ///   - data: 原始位元組資料。
    ///   - offset: 目前的讀取位置，讀取後會自動前進。
    /// - Returns: 讀取到的 varint 值，失敗時回傳 `nil`。
    static func readVarint(_ data: Data, offset: inout Int) -> Int64? {
        var result: Int64 = 0
        var shift = 0

        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= Int64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift >= 64 { return nil }
        }

        return nil
    }
}
