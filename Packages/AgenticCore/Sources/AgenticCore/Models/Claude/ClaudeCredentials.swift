import Foundation

// MARK: - Claude Code 憑證檔案結構

/// `~/.claude/.credentials.json` 的根結構。
public struct ClaudeCredentialFile: Codable, Sendable {
   
    /// Claude AI OAuth 憑證。
    public let claudeAiOauth: ClaudeOAuth?

    public init(claudeAiOauth: ClaudeOAuth? = nil) {
        self.claudeAiOauth = claudeAiOauth
    }
}

/// Claude Code 儲存的 OAuth 憑證。
public struct ClaudeOAuth: Codable, Sendable, Equatable {
    
    /// 存取權杖。
    public var accessToken: String
    
    /// 重新整理權杖。
    public var refreshToken: String?
   
    /// 權杖到期時間，以 Unix 時間戳記（**毫秒**）表示。
    public var expiresAt: Double?
    
    /// 訂閱類型字串（例如 `"pro"`、`"max"`、`"free"`）。
    public var subscriptionType: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Double? = nil,
        subscriptionType: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
    }

    /// 判斷權杖是否已過期或即將過期（在 `bufferMs` 緩衝時間內）。
    ///
    /// - Parameter bufferMs: 在實際到期前的緩衝毫秒數（預設 5 分鐘）。
    /// - Returns: 若需要重新整理則回傳 `true`。
    public func needsRefresh(bufferMs: Double = 5 * 60 * 1000) -> Bool {
        guard let expiresAt else { return false }
        let nowMs = Date().timeIntervalSince1970 * 1000
        return nowMs >= (expiresAt - bufferMs)
    }
}

// MARK: - 權杖重新整理

/// Claude OAuth 權杖重新整理的請求 Body。
public struct ClaudeTokenRefreshRequest: Codable, Sendable {
    
    /// 授權類型（固定為 `"refresh_token"`）。
    public let grantType: String
    
    /// 重新整理權杖。
    public let refreshToken: String
    
    /// 用戶端識別碼。
    public let clientId: String
   
    /// 權限範圍。
    public let scope: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
        case scope
    }

    /// 建立權杖重新整理請求。
    ///
    /// - Parameters:
    ///   - refreshToken: 重新整理權杖。
    ///   - clientID: 用戶端識別碼。
    public init(refreshToken: String, clientID: String) {
        self.grantType = "refresh_token"
        self.refreshToken = refreshToken
        self.clientId = clientID
        self.scope = ClaudeConstants.scopes
    }
}

/// Claude OAuth 權杖重新整理的回應。
public struct ClaudeTokenRefreshResponse: Codable, Sendable {
    
    /// 新的存取權杖。
    public let accessToken: String
   
    /// 新的重新整理權杖（可能為 `nil`）。
    public let refreshToken: String?
  
    /// 權杖有效期限（單位：秒）。
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: Int? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}

// MARK: - 常數

/// Claude Code 相關常數。
public enum ClaudeConstants {

    /// Claude Code OAuth 用戶端識別碼預設值（base64 編碼）。
    public static let defaultClientID = decodeBase64("OWQxYzI1MGEtZTYxYi00NGQ5LTg4ZWQtNTk0NGQxOTYyZjVl")

    /// OAuth 權限範圍。
    public static let scopes = "user:profile user:inference user:sessions:claude_code user:mcp_servers"
   
    /// 憑證檔案相對於家目錄的路徑。
    public static let credentialRelativePath = ".claude/.credentials.json"
   
    /// Claude Code 使用的 macOS 鑰匙圈服務名稱。
    public static let keychainService = "Claude Code-credentials"
   
    /// OAuth 權杖重新整理的 URL。
    public static let refreshURL = "https://platform.claude.com/v1/oauth/token"
  
    /// 用量 API 的 URL。
    public static let usageURL = "https://api.anthropic.com/api/oauth/usage"
}

// MARK: - 十六進位解碼工具

extension ClaudeCredentialFile {
    
    /// 嘗試從原始文字解析憑證 JSON。
    ///
    /// 處理 macOS 鑰匙圈回傳十六進位編碼 UTF-8 位元組的特殊情況。
    ///
    /// - Parameter text: 原始文字。
    /// - Returns: 解析成功的 ``ClaudeCredentialFile``，失敗時回傳 `nil`。
    public static func parse(from text: String) -> ClaudeCredentialFile? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 先嘗試直接 JSON 解析
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(ClaudeCredentialFile.self, from: data) {
            return parsed
        }

        // 嘗試十六進位解碼（macOS 鑰匙圈有時回傳十六進位編碼的位元組）
        var hex = trimmed
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        guard !hex.isEmpty,
              hex.count % 2 == 0,
              hex.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index ..< nextIndex], radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }

        let data = Data(bytes)
        return try? JSONDecoder().decode(ClaudeCredentialFile.self, from: data)
    }
}
