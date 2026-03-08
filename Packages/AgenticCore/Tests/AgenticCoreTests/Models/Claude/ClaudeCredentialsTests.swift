import Foundation
import Testing

@testable import AgenticCore

@Suite("ClaudeCredentials")
struct ClaudeCredentialsTests {

    // MARK: - ClaudeCredentialFile.parse

    /// 驗證合法 JSON 字串可正確解析出 accessToken、refreshToken 與 expiresAt
    @Test
    func parse_validJSON() {
        let json = """
            {"claudeAiOauth":{"accessToken":"tok_abc","refreshToken":"ref_123","expiresAt":1700000000000}}
            """
        let result = ClaudeCredentialFile.parse(from: json)
        #expect(result != nil)
        #expect(result?.claudeAiOauth?.accessToken == "tok_abc")
        #expect(result?.claudeAiOauth?.refreshToken == "ref_123")
        #expect(result?.claudeAiOauth?.expiresAt == 1700000000000)
    }

    /// 驗證含有前後空白與換行的 JSON 仍可正確解析
    @Test
    func parse_jsonWithWhitespace() {
        let json = "  {\"claudeAiOauth\":{\"accessToken\":\"tok\"}}  \n"
        let result = ClaudeCredentialFile.parse(from: json)
        #expect(result != nil)
        #expect(result?.claudeAiOauth?.accessToken == "tok")
    }

    /// 驗證十六進位編碼的 JSON 字串可正確解碼並解析
    @Test
    func parse_hexEncoded() {
        // 將合法 JSON 字串轉為十六進位編碼
        let json = "{\"claudeAiOauth\":{\"accessToken\":\"tok\"}}"
        let hexString = json.utf8.map { String(format: "%02x", $0) }.joined()
        let result = ClaudeCredentialFile.parse(from: hexString)
        #expect(result != nil)
        #expect(result?.claudeAiOauth?.accessToken == "tok")
    }

    /// 驗證帶有 0x 前綴的十六進位字串可正確解碼並解析
    @Test
    func parse_hexWithPrefix() {
        let json = "{\"claudeAiOauth\":{\"accessToken\":\"tok\"}}"
        let hexString = "0x" + json.utf8.map { String(format: "%02x", $0) }.joined()
        let result = ClaudeCredentialFile.parse(from: hexString)
        #expect(result != nil)
        #expect(result?.claudeAiOauth?.accessToken == "tok")
    }

    /// 驗證帶有大寫 0X 前綴的十六進位字串可正確解碼並解析
    @Test
    func parse_hexWithUppercasePrefix() {
        let json = "{\"claudeAiOauth\":{\"accessToken\":\"tok\"}}"
        let hexString = "0X" + json.utf8.map { String(format: "%02X", $0) }.joined()
        let result = ClaudeCredentialFile.parse(from: hexString)
        #expect(result != nil)
    }

    /// 驗證無效 JSON 字串回傳 nil
    @Test
    func parse_invalidJSON_returnsNil() {
        #expect(ClaudeCredentialFile.parse(from: "not json") == nil)
    }

    /// 驗證空字串回傳 nil
    @Test
    func parse_emptyString_returnsNil() {
        #expect(ClaudeCredentialFile.parse(from: "") == nil)
    }

    /// 驗證奇數長度的十六進位字串回傳 nil
    @Test
    func parse_oddLengthHex_returnsNil() {
        #expect(ClaudeCredentialFile.parse(from: "abc") == nil)
    }

    /// 驗證缺少 claudeAiOauth 欄位的 JSON 可解析但 OAuth 為 nil
    @Test
    func parse_noOAuthField() {
        let json = "{}"
        let result = ClaudeCredentialFile.parse(from: json)
        #expect(result != nil)
        #expect(result?.claudeAiOauth == nil)
    }

    // MARK: - ClaudeOAuth.needsRefresh

    /// 驗證 expiresAt 為 nil 時不需要重新整理
    @Test
    func needsRefresh_nilExpiresAt_returnsFalse() {
        let oauth = ClaudeOAuth(accessToken: "tok", expiresAt: nil)
        #expect(oauth.needsRefresh() == false)
    }

    /// 驗證已過期的 Token 需要重新整理
    @Test
    func needsRefresh_expired_returnsTrue() {
        // 設定 expiresAt 為 1 小時前
        let pastMs = (Date().timeIntervalSince1970 - 3600) * 1000
        let oauth = ClaudeOAuth(accessToken: "tok", expiresAt: pastMs)
        #expect(oauth.needsRefresh() == true)
    }

    /// 驗證距到期尚遠的 Token 不需要重新整理
    @Test
    func needsRefresh_farFuture_returnsFalse() {
        // 設定 expiresAt 為 1 小時後
        let futureMs = (Date().timeIntervalSince1970 + 3600) * 1000
        let oauth = ClaudeOAuth(accessToken: "tok", expiresAt: futureMs)
        #expect(oauth.needsRefresh() == false)
    }

    /// 驗證到期時間在預設緩衝區（5 分鐘）內時需要重新整理
    @Test
    func needsRefresh_withinBuffer_returnsTrue() {
        // 設定 expiresAt 為 2 分鐘後（在 5 分鐘緩衝區內）
        let nearFutureMs = (Date().timeIntervalSince1970 + 120) * 1000
        let oauth = ClaudeOAuth(accessToken: "tok", expiresAt: nearFutureMs)
        #expect(oauth.needsRefresh() == true)
    }

    /// 驗證自訂緩衝時間可正確判斷是否需要重新整理
    @Test
    func needsRefresh_customBuffer() {
        // 設定 expiresAt 為 10 秒後，緩衝時間 5 秒
        let futureMs = (Date().timeIntervalSince1970 + 10) * 1000
        let oauth = ClaudeOAuth(accessToken: "tok", expiresAt: futureMs)
        #expect(oauth.needsRefresh(bufferMs: 5000) == false)
    }
}
