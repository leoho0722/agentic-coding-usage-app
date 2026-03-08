import Foundation
import Testing

@testable import AgenticCore

@Suite("CodexCredentials")
struct CodexCredentialsTests {

    // MARK: - CodexCredentialFile.parse

    /// 驗證合法 JSON 字串可正確解析出 tokens 與 lastRefresh
    @Test
    func parse_validJSON() {
        let json = """
            {"tokens":{"access_token":"at","refresh_token":"rt","account_id":"aid"},"last_refresh":"2025-01-15T10:30:00Z"}
            """
        let result = CodexCredentialFile.parse(from: json)
        #expect(result != nil)
        #expect(result?.tokens?.accessToken == "at")
        #expect(result?.tokens?.refreshToken == "rt")
        #expect(result?.tokens?.accountId == "aid")
        #expect(result?.lastRefresh == "2025-01-15T10:30:00Z")
    }

    /// 驗證缺少 tokens 欄位的 JSON 可解析但 tokens 為 nil
    @Test
    func parse_noTokens() {
        let json = "{}"
        let result = CodexCredentialFile.parse(from: json)
        #expect(result != nil)
        #expect(result?.tokens == nil)
    }

    /// 驗證無效 JSON 字串回傳 nil
    @Test
    func parse_invalidJSON_returnsNil() {
        #expect(CodexCredentialFile.parse(from: "invalid") == nil)
    }

    /// 驗證十六進位編碼的 JSON 字串可正確解碼並解析
    @Test
    func parse_hexEncoded() {
        let json = "{\"tokens\":{\"access_token\":\"at\"}}"
        let hex = json.utf8.map { String(format: "%02x", $0) }.joined()
        let result = CodexCredentialFile.parse(from: hex)
        #expect(result != nil)
        #expect(result?.tokens?.accessToken == "at")
    }

    // MARK: - toOAuth

    /// 驗證含有 tokens 的憑證檔可正確轉換為 OAuth 物件
    @Test
    func toOAuth_withTokens() {
        let file = CodexCredentialFile(
            tokens: CodexTokens(accessToken: "at", refreshToken: "rt", accountId: "aid"),
            lastRefresh: "2025-01-15T10:30:00Z"
        )
        let oauth = file.toOAuth()
        #expect(oauth != nil)
        #expect(oauth?.accessToken == "at")
        #expect(oauth?.refreshToken == "rt")
        #expect(oauth?.accountId == "aid")
        #expect(oauth?.lastRefresh != nil)
    }

    /// 驗證缺少 tokens 時 toOAuth 回傳 nil
    @Test
    func toOAuth_noTokens_returnsNil() {
        let file = CodexCredentialFile(tokens: nil)
        #expect(file.toOAuth() == nil)
    }

    /// 驗證含有小數秒的 ISO 8601 時間字串可正確解析為 lastRefresh
    @Test
    func toOAuth_withFractionalSeconds() {
        let file = CodexCredentialFile(
            tokens: CodexTokens(accessToken: "at"),
            lastRefresh: "2025-01-15T10:30:00.123Z"
        )
        let oauth = file.toOAuth()
        #expect(oauth?.lastRefresh != nil)
    }

    /// 驗證 lastRefresh 為 nil 時 OAuth 的 lastRefresh 也為 nil
    @Test
    func toOAuth_nilLastRefresh() {
        let file = CodexCredentialFile(
            tokens: CodexTokens(accessToken: "at"),
            lastRefresh: nil
        )
        let oauth = file.toOAuth()
        #expect(oauth?.lastRefresh == nil)
    }

    // MARK: - CodexOAuth.needsRefresh

    /// 驗證 lastRefresh 為 nil 時需要重新整理
    @Test
    func needsRefresh_nilLastRefresh_returnsTrue() {
        let oauth = CodexOAuth(accessToken: "at", lastRefresh: nil)
        #expect(oauth.needsRefresh() == true)
    }

    /// 驗證剛重新整理過的 Token 不需要再次重新整理
    @Test
    func needsRefresh_recentRefresh_returnsFalse() {
        let oauth = CodexOAuth(accessToken: "at", lastRefresh: Date())
        #expect(oauth.needsRefresh() == false)
    }

    /// 驗證超過 8 天未重新整理的 Token 需要重新整理
    @Test
    func needsRefresh_over8Days_returnsTrue() {
        let ninetyDaysAgo = Date().addingTimeInterval(-9 * 24 * 60 * 60)
        let oauth = CodexOAuth(accessToken: "at", lastRefresh: ninetyDaysAgo)
        #expect(oauth.needsRefresh() == true)
    }

    /// 驗證自訂最大有效天數可正確判斷是否需要重新整理
    @Test
    func needsRefresh_customMaxAge() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        let oauth = CodexOAuth(accessToken: "at", lastRefresh: twoDaysAgo)
        // 2 days old, with 1-day max age → needs refresh
        #expect(oauth.needsRefresh(maxAgeDays: 1.0) == true)
        // 2 days old, with 3-day max age → does not need refresh
        #expect(oauth.needsRefresh(maxAgeDays: 3.0) == false)
    }
}
