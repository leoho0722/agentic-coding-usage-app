import Foundation

// MARK: - GitHub API 用戶端

/// 可依賴注入的 GitHub API 用戶端。
///
/// 透過閉包注入，讓 TCA 與 CLI 可各自提供不同的實作（正式版、模擬版等）。
public struct GitHubAPIClient: Sendable {
    
    /// 取得已驗證使用者的基本資料。
    public var fetchUser: @Sendable (_ accessToken: String) async throws -> GitHubUser
    
    /// 取得 Copilot 狀態，包含方案與配額快照（內部 API）。
    public var fetchCopilotStatus: @Sendable (
        _ accessToken: String
    ) async throws -> CopilotStatusResponse
    
    /// 以指定的閉包建立實例。
    ///
    /// - Parameters:
    ///   - fetchUser: 取得已驗證使用者的基本資料。
    ///   - fetchCopilotStatus: 取得 Copilot 狀態，包含方案與配額快照（內部 API）。
    public init(
        fetchUser: @escaping @Sendable (_ accessToken: String) async throws -> GitHubUser,
        fetchCopilotStatus: @escaping @Sendable (
            _ accessToken: String
        ) async throws -> CopilotStatusResponse
    ) {
        self.fetchUser = fetchUser
        self.fetchCopilotStatus = fetchCopilotStatus
    }
}

// MARK: - 正式版實作

extension GitHubAPIClient {
    
    /// 使用 `URLSession` 的正式版實作。
    public static let live = GitHubAPIClient(
        fetchUser: { accessToken in
            let request = RequestBuilder(url: GitHubEndpoint.user.url)
                .method(.get)
                .bearerToken(accessToken)
                .header("Accept", "application/json")
                .header("X-GitHub-Api-Version", "2022-11-28")
                .build()
            
            do {
                return try await HTTPClient().fetch(request, responseType: GitHubUser.self)
            } catch let error as HTTPClientError {
                throw error.toGitHubAPIError()
            }
        },
        fetchCopilotStatus: { accessToken in
            let request = RequestBuilder(url: GitHubEndpoint.copilotStatus.url)
                .method(.get)
                .header("Accept", "application/json")
                .header("Authorization", "token \(accessToken)")
                .header("X-Github-Api-Version", "2025-04-01")
                .header("Editor-Version", "vscode/1.96.2")
                .header("Editor-Plugin-Version", "copilot-chat/0.26.7")
                .header("User-Agent", "GitHubCopilotChat/0.26.7")
                .build()
            
            do {
                return try await HTTPClient().fetch(request, responseType: CopilotStatusResponse.self)
            } catch let error as HTTPClientError {
                throw error.toGitHubAPIError()
            }
        }
    )
}

// MARK: - 輔助工具

/// GitHub API 錯誤。
public enum GitHubAPIError: LocalizedError, Sendable {
    
    /// HTTP 錯誤，附帶狀態碼與訊息。
    case httpError(statusCode: Int, message: String)
    
    /// 無效的回應。
    case invalidResponse
    
    /// 解碼失敗，附帶底層錯誤與原始回應。
    case decodingFailed(underlyingError: any Error, rawResponse: String)
    
    public var errorDescription: String? {
        switch self {
        case let .httpError(statusCode, message):
            "GitHub API error (\(statusCode)): \(message)"
        case .invalidResponse:
            "Invalid response from GitHub API"
        case let .decodingFailed(underlyingError, rawResponse):
            """
            Failed to decode API response: \
            \(underlyingError.localizedDescription)
            Raw response: \(rawResponse.prefix(500))
            """
        }
    }
}

extension HTTPClientError {
    
    /// 將 `HTTPClientError` 轉換為對應的 ``GitHubAPIError``。
    ///
    /// - Returns: 對應的 ``GitHubAPIError``。
    func toGitHubAPIError() -> GitHubAPIError {
        switch self {
        case .invalidResponse:
                .invalidResponse
        case let .httpError(statusCode, message, _):
                .httpError(statusCode: statusCode, message: message)
        case let .decodingFailed(underlyingError, rawResponse):
                .decodingFailed(underlyingError: underlyingError, rawResponse: rawResponse)
        }
    }
}
