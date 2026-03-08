import Foundation
import Testing

@testable import AgenticCore

@Suite("ProtobufDecoder")
struct ProtobufDecoderTests {

    // MARK: - Tests

    /// 驗證有效的 Protobuf 資料能正確解碼出 accessToken、refreshToken 與到期時間
    @Test
    func decode_validData() {
        let data = buildProtobufData(accessToken: "myAccessToken", refreshToken: "myRefreshToken", expirySeconds: 1700000000)
        let base64 = data.base64EncodedString()
        let result = ProtobufDecoder.decodeAntigravityTokens(from: base64)
        #expect(result != nil)
        #expect(result?.accessToken == "myAccessToken")
        #expect(result?.refreshToken == "myRefreshToken")
        #expect(result?.expirySeconds == 1700000000)
    }

    /// 驗證無效的 Base64 字串回傳 nil
    @Test
    func decode_invalidBase64_returnsNil() {
        #expect(ProtobufDecoder.decodeAntigravityTokens(from: "!!!invalid!!!") == nil)
    }

    /// 驗證空資料回傳 nil
    @Test
    func decode_emptyData_returnsNil() {
        let base64 = Data().base64EncodedString()
        #expect(ProtobufDecoder.decodeAntigravityTokens(from: base64) == nil)
    }

    /// 驗證缺少 field 6 的 Protobuf 資料回傳 nil
    @Test
    func decode_missingField6_returnsNil() {
        // 建構使用 field 1 取代 field 6 的訊息
        var outer = Data()
        outer.append(contentsOf: encodeVarint(fieldTag(1, wireType: 2)))
        let inner = Data([0x00])
        outer.append(contentsOf: encodeVarint(UInt64(inner.count)))
        outer.append(inner)
        let base64 = outer.base64EncodedString()
        #expect(ProtobufDecoder.decodeAntigravityTokens(from: base64) == nil)
    }

    /// 驗證空的 accessToken 回傳 nil
    @Test
    func decode_emptyAccessToken_returnsNil() {
        let data = buildProtobufData(accessToken: "", refreshToken: "rt", expirySeconds: 100)
        let base64 = data.base64EncodedString()
        #expect(ProtobufDecoder.decodeAntigravityTokens(from: base64) == nil)
    }

    /// 驗證空的 refreshToken 回傳 nil
    @Test
    func decode_emptyRefreshToken_returnsNil() {
        let data = buildProtobufData(accessToken: "at", refreshToken: "", expirySeconds: 100)
        let base64 = data.base64EncodedString()
        #expect(ProtobufDecoder.decodeAntigravityTokens(from: base64) == nil)
    }
}

// MARK: - Helper Methods

private extension ProtobufDecoderTests {

    /// 建構 Antigravity Token 的 Protobuf wire-format 測試資料
    ///
    /// 外層訊息：field 6（length-delimited）包含內層訊息。
    /// 內層訊息：field 1 = accessToken、field 3 = refreshToken、field 4 = { field 1 = expirySeconds }。
    /// - Parameters:
    ///   - accessToken: 存取權杖字串
    ///   - refreshToken: 重新整理權杖字串
    ///   - expirySeconds: 到期時間（Unix 秒）
    /// - Returns: 編碼後的 Protobuf `Data`
    func buildProtobufData(
        accessToken: String,
        refreshToken: String,
        expirySeconds: Int64
    ) -> Data {
        // 建構到期時間子訊息：field 1 = varint
        var expiryMsg = Data()
        expiryMsg.append(contentsOf: encodeVarint(fieldTag(1, wireType: 0)))
        expiryMsg.append(contentsOf: encodeVarint(UInt64(bitPattern: expirySeconds)))

        // 建構內層訊息
        var inner = Data()
        // field 1 = accessToken
        inner.append(contentsOf: encodeVarint(fieldTag(1, wireType: 2)))
        let atBytes = Array(accessToken.utf8)
        inner.append(contentsOf: encodeVarint(UInt64(atBytes.count)))
        inner.append(contentsOf: atBytes)
        // field 3 = refreshToken
        inner.append(contentsOf: encodeVarint(fieldTag(3, wireType: 2)))
        let rtBytes = Array(refreshToken.utf8)
        inner.append(contentsOf: encodeVarint(UInt64(rtBytes.count)))
        inner.append(contentsOf: rtBytes)
        // field 4 = expiry sub-message
        inner.append(contentsOf: encodeVarint(fieldTag(4, wireType: 2)))
        inner.append(contentsOf: encodeVarint(UInt64(expiryMsg.count)))
        inner.append(expiryMsg)

        // 建構外層訊息
        var outer = Data()
        // field 6 = inner message
        outer.append(contentsOf: encodeVarint(fieldTag(6, wireType: 2)))
        outer.append(contentsOf: encodeVarint(UInt64(inner.count)))
        outer.append(inner)

        return outer
    }

    /// 計算 Protobuf field tag（field number + wire type）
    /// - Parameters:
    ///   - fieldNumber: 欄位編號
    ///   - wireType: Wire type（0 = varint, 2 = length-delimited）
    /// - Returns: 編碼後的 field tag
    func fieldTag(_ fieldNumber: Int, wireType: Int) -> UInt64 {
        UInt64(fieldNumber << 3 | wireType)
    }

    /// 將 UInt64 編碼為 Protobuf varint 格式的位元組陣列
    /// - Parameter value: 要編碼的無號整數
    /// - Returns: varint 編碼後的位元組陣列
    func encodeVarint(_ value: UInt64) -> [UInt8] {
        var v = value
        var result: [UInt8] = []
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            result.append(byte)
        } while v != 0
        return result
    }
}
