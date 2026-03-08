import Foundation
import Testing

@testable import AgenticCore

@Suite("AntigravityCredentials")
struct AntigravityCredentialsTests {

    // MARK: - AntigravityProtoTokens.isExpired

    /// 驗證已過期的 ProtoTokens 回傳 true
    @Test
    func isExpired_pastExpiry_returnsTrue() {
        let pastSeconds = Int64(Date().timeIntervalSince1970) - 3600
        let tokens = AntigravityProtoTokens(
            accessToken: "at", refreshToken: "rt", expirySeconds: pastSeconds
        )
        #expect(tokens.isExpired() == true)
    }

    /// 驗證距到期尚遠的 ProtoTokens 回傳 false
    @Test
    func isExpired_farFuture_returnsFalse() {
        let futureSeconds = Int64(Date().timeIntervalSince1970) + 3600
        let tokens = AntigravityProtoTokens(
            accessToken: "at", refreshToken: "rt", expirySeconds: futureSeconds
        )
        #expect(tokens.isExpired() == false)
    }

    /// 驗證到期時間在預設緩衝區（5 分鐘）內時視為已過期
    @Test
    func isExpired_withinBuffer_returnsTrue() {
        // 2 minutes from now (within default 5-minute buffer)
        let nearFuture = Int64(Date().timeIntervalSince1970) + 120
        let tokens = AntigravityProtoTokens(
            accessToken: "at", refreshToken: "rt", expirySeconds: nearFuture
        )
        #expect(tokens.isExpired() == true)
    }

    /// 驗證自訂緩衝秒數可正確判斷是否已過期
    @Test
    func isExpired_customBuffer() {
        let tenSecondsAhead = Int64(Date().timeIntervalSince1970) + 10
        let tokens = AntigravityProtoTokens(
            accessToken: "at", refreshToken: "rt", expirySeconds: tenSecondsAhead
        )
        #expect(tokens.isExpired(bufferSeconds: 5) == false)
        #expect(tokens.isExpired(bufferSeconds: 15) == true)
    }

    // MARK: - AntigravityCredential.needsRefresh

    /// 驗證 expirySeconds 為 nil 時不需要重新整理
    @Test
    func needsRefresh_nilExpiry_returnsFalse() {
        let cred = AntigravityCredential(
            accessToken: "at", expirySeconds: nil, source: .apiKey
        )
        #expect(cred.needsRefresh() == false)
    }

    /// 驗證已過期的憑證需要重新整理
    @Test
    func needsRefresh_expired_returnsTrue() {
        let pastSeconds = Int64(Date().timeIntervalSince1970) - 600
        let cred = AntigravityCredential(
            accessToken: "at", expirySeconds: pastSeconds, source: .protoToken
        )
        #expect(cred.needsRefresh() == true)
    }

    /// 驗證距到期尚遠的憑證不需要重新整理
    @Test
    func needsRefresh_farFuture_returnsFalse() {
        let futureSeconds = Int64(Date().timeIntervalSince1970) + 3600
        let cred = AntigravityCredential(
            accessToken: "at", expirySeconds: futureSeconds, source: .refreshedToken
        )
        #expect(cred.needsRefresh() == false)
    }

    /// 驗證自訂緩衝秒數可正確判斷憑證是否需要重新整理
    @Test
    func needsRefresh_customBuffer() {
        let tenSecondsAhead = Int64(Date().timeIntervalSince1970) + 10
        let cred = AntigravityCredential(
            accessToken: "at", expirySeconds: tenSecondsAhead, source: .protoToken
        )
        #expect(cred.needsRefresh(bufferSeconds: 5) == false)
        #expect(cred.needsRefresh(bufferSeconds: 15) == true)
    }
}
