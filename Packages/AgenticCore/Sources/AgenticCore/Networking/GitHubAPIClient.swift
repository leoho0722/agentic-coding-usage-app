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
            let request = GitHubEndpoint.user.makeRequest(accessToken: accessToken)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)
            return try JSONDecoder().decode(GitHubUser.self, from: data)
        },
        fetchCopilotStatus: { accessToken in
            let request = GitHubEndpoint.copilotStatus.makeRequest(accessToken: accessToken)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)
            do {
                return try JSONDecoder().decode(CopilotStatusResponse.self, from: data)
            } catch let decodingError {
                let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
                throw GitHubAPIError.decodingFailed(
                    underlyingError: decodingError,
                    rawResponse: rawJSON
                )
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

/// 驗證 HTTP 回應的狀態碼是否為成功（2xx）。
///
/// - Parameters:
///   - response: URL 回應物件。
///   - data: 回應資料，用於錯誤訊息。
/// - Throws: 狀態碼非 2xx 時拋出 ``GitHubAPIError``。
private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw GitHubAPIError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
    }
}
