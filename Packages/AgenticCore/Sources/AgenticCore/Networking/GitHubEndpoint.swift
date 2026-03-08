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
}
