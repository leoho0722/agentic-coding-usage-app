import Foundation

// MARK: - Antigravity 憑證模型

/// SQLite 中 `antigravityAuthStatus` 的 JSON 結構。
public struct AntigravityAuthStatus: Codable, Sendable {

    /// API 金鑰。
    public let apiKey: String?

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
}

/// Protobuf 解碼後的權杖資料。
public struct AntigravityProtoTokens: Sendable, Equatable {

    /// 存取權杖。
    public let accessToken: String

    /// 重新整理權杖。
    public let refreshToken: String

    /// 到期秒數（Unix 時間戳記）。
    public let expirySeconds: Int64

    public init(accessToken: String, refreshToken: String, expirySeconds: Int64) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirySeconds = expirySeconds
    }

    /// 判斷權杖是否已過期（含 5 分鐘緩衝）。
    public func isExpired(bufferSeconds: Int64 = 300) -> Bool {
        let now = Int64(Date().timeIntervalSince1970)
        return now >= (expirySeconds - bufferSeconds)
    }
}

// MARK: - 執行期憑證容器

/// 統一的執行期憑證容器，包含存取權杖與來源資訊。
public struct AntigravityCredential: Sendable, Equatable {

    /// 存取權杖。
    public let accessToken: String

    /// 重新整理權杖（僅 proto token 或 refreshed token 來源有值）。
    public let refreshToken: String?

    /// 到期秒數（Unix 時間戳記）。
    public let expirySeconds: Int64?

    /// 憑證來源。
    public let source: CredentialSource

    /// 憑證來源列舉。
    public enum CredentialSource: String, Sendable, Equatable {
        /// 來自 SQLite authStatus 中的 API key。
        case apiKey
        /// 來自 proto 格式解碼的權杖。
        case protoToken
        /// 經 OAuth 重新整理後的權杖。
        case refreshedToken
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expirySeconds: Int64? = nil,
        source: CredentialSource
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirySeconds = expirySeconds
        self.source = source
    }

    /// 判斷是否需要重新整理（僅適用於有到期資訊的憑證）。
    public func needsRefresh(bufferSeconds: Int64 = 300) -> Bool {
        guard let expirySeconds else { return false }
        let now = Int64(Date().timeIntervalSince1970)
        return now >= (expirySeconds - bufferSeconds)
    }
}

// MARK: - 權杖重新整理回應

/// Google OAuth 權杖重新整理回應。
public struct AntigravityTokenRefreshResponse: Codable, Sendable {

    /// 新的存取權杖。
    public let accessToken: String

    /// 權杖有效期限（單位：秒）。
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }

    public init(accessToken: String, expiresIn: Int? = nil) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
    }
}

// MARK: - 常數

/// Antigravity 相關常數。
public enum AntigravityConstants {

    /// Google OAuth 用戶端識別碼預設值（base64 編碼）。
    public static let defaultClientID = decodeBase64(
        "MTA3MTAwNjA2MDU5MS10bWhzc2luMmgyMWxjcmUyMzV2dG9sb2poNGc0MDNlcC5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbQ=="
    )

    /// Google OAuth 用戶端密鑰預設值（base64 編碼，installed app，非真正機密）。
    public static let defaultClientSecret = decodeBase64("R09DU1BYLUs1OEZXUjQ4NkxkTEoxbUxCOHNYQzR6NnFEQWY=")

    /// SQLite 資料庫相對於家目錄的路徑。
    public static let dbRelativePath =
        "Library/Application Support/Antigravity/User/globalStorage/state.vscdb"

    /// SQLite 中儲存認證狀態的鍵名。
    public static let authStatusKey = "antigravityAuthStatus"

    /// SQLite 中儲存 proto 格式權杖的鍵名。
    public static let protoTokenKey = "jetskiStateSync.agentManagerInitState"

    /// Cloud Code 用量 API 的主要 URL。
    public static let usageURL =
        "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"

    /// Cloud Code 用量 API 的備用 URL。
    public static let usageFallbackURL =
        "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"

    /// Google OAuth 權杖重新整理的 URL。
    public static let refreshURL = "https://oauth2.googleapis.com/token"

    /// 快取權杖的檔案名稱。
    public static let cachedTokenFileName = "antigravity_cached_token.json"

    /// 需從用量顯示中排除的模型 ID 集合（與 OpenUsage 參考實作同步）。
    public static let modelBlacklist: Set<String> = [
        "MODEL_CHAT_20706",
        "MODEL_CHAT_23310",
        "MODEL_GOOGLE_GEMINI_2_5_FLASH",
        "MODEL_GOOGLE_GEMINI_2_5_FLASH_THINKING",
        "MODEL_GOOGLE_GEMINI_2_5_FLASH_LITE",
        "MODEL_GOOGLE_GEMINI_2_5_PRO",
        "MODEL_PLACEHOLDER_M19",
        "MODEL_PLACEHOLDER_M9",
        "MODEL_PLACEHOLDER_M12",
        "tab_flash_lite_preview",
        "tab_jump_flash_lite_preview",
    ]

    /// 需從用量顯示中排除的模型顯示名稱集合。
    public static let displayNameBlacklist: Set<String> = [
        "Gemini 2.5 Flash",
        "Gemini 2.5 Flash Thinking",
        "Gemini 2.5 Pro",
    ]
}
