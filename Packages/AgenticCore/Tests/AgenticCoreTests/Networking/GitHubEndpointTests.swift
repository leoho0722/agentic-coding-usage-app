import Foundation
import Testing

@testable import AgenticCore

@Suite("GitHubEndpoint")
struct GitHubEndpointTests {

    /// 驗證 user 端點產生正確的 API URL
    @Test
    func userEndpoint_url() {
        #expect(GitHubEndpoint.user.url.absoluteString == "https://api.github.com/user")
    }

    /// 驗證 copilotStatus 端點產生正確的 API URL
    @Test
    func copilotStatusEndpoint_url() {
        #expect(GitHubEndpoint.copilotStatus.url.absoluteString == "https://api.github.com/copilot_internal/user")
    }

    /// 驗證 deviceCode 端點產生正確的 OAuth 裝置碼 URL
    @Test
    func deviceCodeEndpoint_url() {
        let endpoint = GitHubEndpoint.deviceCode(clientID: "test_id")
        #expect(endpoint.url.absoluteString == "https://github.com/login/device/code")
    }

    /// 驗證 pollAccessToken 端點產生正確的 OAuth 存取權杖 URL
    @Test
    func pollAccessTokenEndpoint_url() {
        let endpoint = GitHubEndpoint.pollAccessToken(clientID: "test_id", deviceCode: "dc_123")
        #expect(endpoint.url.absoluteString == "https://github.com/login/oauth/access_token")
    }
}
