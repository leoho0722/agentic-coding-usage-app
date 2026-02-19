import Foundation

// MARK: - Codex 憑證檔案結構

/// `~/.config/codex/auth.json`（或 `~/.codex/auth.json`）的根結構。
public struct CodexCredentialFile: Codable, Sendable {
    
    /// 權杖資料。
    public let tokens: CodexTokens?
   
    /// 最後一次重新整理的 ISO 8601 時間戳記。
    public let lastRefresh: String?

    enum CodingKeys: String, CodingKey {
        case tokens
        case lastRefresh = "last_refresh"
    }

    public init(tokens: CodexTokens? = nil, lastRefresh: String? = nil) {
        self.tokens = tokens
        self.lastRefresh = lastRefresh
    }
}

/// 憑證檔案中的權杖承載資料。
public struct CodexTokens: Codable, Sendable, Equatable {
    
    /// 存取權杖。
    public var accessToken: String
   
    /// 重新整理權杖。
    public var refreshToken: String?
 
    /// 帳號識別碼。
    public var accountId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case accountId = "account_id"
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        accountId: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountId = accountId
    }
}

/// 執行中的憑證容器，結合權杖與重新整理的中繼資料。
public struct CodexOAuth: Sendable, Equatable {
   
    /// 存取權杖。
    public var accessToken: String
   
    /// 重新整理權杖。
    public var refreshToken: String?
   
    /// 帳號識別碼。
    public var accountId: String?
  
    /// 最後一次重新整理的日期。
    public var lastRefresh: Date?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        accountId: String? = nil,
        lastRefresh: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountId = accountId
        self.lastRefresh = lastRefresh
    }

    /// 判斷權杖是否需要重新整理。
    ///
    /// Codex 使用以時間為基準的重新整理策略：權杖壽命超過 `last_refresh` 後 8 天即需重新整理。
    ///
    /// - Parameter maxAgeDays: 權杖最大有效天數（預設 8 天）。
    /// - Returns: 若需要重新整理則回傳 `true`。
    public func needsRefresh(maxAgeDays: Double = 8.0) -> Bool {
        guard let lastRefresh else { return true }
        let ageSeconds = Date().timeIntervalSince(lastRefresh)
        let maxAgeSeconds = maxAgeDays * 24 * 60 * 60
        return ageSeconds >= maxAgeSeconds
    }
}

// MARK: - 權杖重新整理

/// Codex OAuth 權杖重新整理的回應。
public struct CodexTokenRefreshResponse: Codable, Sendable {
   
    /// 新的存取權杖。
    public let accessToken: String
   
    /// 新的重新整理權杖。
    public let refreshToken: String?
  
    /// ID 權杖。
    public let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
    }
}

// MARK: - 常數

/// Codex 相關常數。
public enum CodexConstants {

    /// Codex OAuth 用戶端識別碼預設值（base64 編碼）。
    public static let defaultClientID = decodeBase64("YXBwX0VNb2FtRUVaNzNmMENrWGFYcDdocmFubg==")

    /// 主要憑證檔案相對於家目錄的路徑。
    public static let credentialRelativePath = ".config/codex/auth.json"
   
    /// 備用憑證檔案相對於家目錄的路徑。
    public static let credentialFallbackPath = ".codex/auth.json"
   
    /// Codex 使用的 macOS 鑰匙圈服務名稱。
    public static let keychainService = "Codex Auth"
   
    /// 權杖重新整理的 URL。
    public static let refreshURL = "https://auth.openai.com/oauth/token"
   
    /// 用量 API 的 URL。
    public static let usageURL = "https://chatgpt.com/backend-api/wham/usage"
}

// MARK: - 解析工具

extension CodexCredentialFile {
    
    /// 嘗試從原始文字解析憑證 JSON。
    ///
    /// 處理 macOS 鑰匙圈回傳十六進位編碼 UTF-8 位元組的特殊情況。
    ///
    /// - Parameter text: 原始文字。
    /// - Returns: 解析成功的 ``CodexCredentialFile``，失敗時回傳 `nil`。
    public static func parse(from text: String) -> CodexCredentialFile? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 先嘗試直接 JSON 解析
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(CodexCredentialFile.self, from: data) {
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
        return try? JSONDecoder().decode(CodexCredentialFile.self, from: data)
    }

    /// 透過解析 `lastRefresh` 日期，轉換為執行中的 ``CodexOAuth``。
    ///
    /// - Returns: 轉換成功的 ``CodexOAuth``，無權杖資料時回傳 `nil`。
    public func toOAuth() -> CodexOAuth? {
        guard let tokens else { return nil }

        var refreshDate: Date?
        if let lastRefresh {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            refreshDate = formatter.date(from: lastRefresh)
            if refreshDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                refreshDate = formatter.date(from: lastRefresh)
            }
        }

        return CodexOAuth(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            accountId: tokens.accountId,
            lastRefresh: refreshDate
        )
    }
}
