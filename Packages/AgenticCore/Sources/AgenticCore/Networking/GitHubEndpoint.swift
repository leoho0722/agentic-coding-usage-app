import Foundation

// MARK: - GitHub 常數

/// GitHub 相關常數。
public enum GitHubConstants {
    /// GitHub OAuth App 用戶端識別碼預設值（base64 編碼）。
    public static let defaultClientID = decodeBase64("T3YyM2xpT3FyRk42NG9UWTRqUlY=")
}

// MARK: - GitHub 端點

/// AgenticUsage 使用的 GitHub API 端點定義。
public enum GitHubEndpoint: Sendable {
    
    /// `GET /user` -- 已驗證的使用者基本資料。
    case user
   
    /// `GET /copilot_internal/user` -- Copilot 內部狀態（方案、配額快照）。
    case copilotStatus

    // MARK: - OAuth 裝置流程

    /// `POST https://github.com/login/device/code` -- 請求裝置驗證碼。
    case deviceCode(clientID: String)
    
    /// `POST https://github.com/login/oauth/access_token` -- 輪詢存取權杖。
    case pollAccessToken(clientID: String, deviceCode: String)

    /// 此端點的完整 URL。
    public var url: URL {
        switch self {
        case .user:
            return URL(string: "https://api.github.com/user")!

        case .copilotStatus:
            return URL(string: "https://api.github.com/copilot_internal/user")!

        case .deviceCode:
            return URL(string: "https://github.com/login/device/code")!

        case .pollAccessToken:
            return URL(string: "https://github.com/login/oauth/access_token")!
        }
    }

    /// 建構此端點的 `URLRequest`。
    ///
    /// - Parameter accessToken: 選填的存取權杖，用於需要驗證的端點。
    /// - Returns: 已設定好 HTTP 方法、標頭與 Body 的 `URLRequest`。
    public func makeRequest(accessToken: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch self {
        case .user:
            request.httpMethod = "GET"
            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        case .copilotStatus:
            request.httpMethod = "GET"
            if let accessToken {
                request.setValue("token \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            // Copilot 內部 API 需要編輯器風格的標頭
            request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
            request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
            request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
            request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")

        case let .deviceCode(clientID):
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["client_id": clientID, "scope": "user"]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        case let .pollAccessToken(clientID, deviceCode):
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "client_id": clientID,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return request
    }
}
