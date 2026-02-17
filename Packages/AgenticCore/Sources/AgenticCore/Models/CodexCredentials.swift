import Foundation

// MARK: - Codex Credential File Structure

/// Root structure of `~/.config/codex/auth.json` (or `~/.codex/auth.json`).
public struct CodexCredentialFile: Codable, Sendable {
    public let tokens: CodexTokens?
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

/// Token payload inside the credential file.
public struct CodexTokens: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
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

/// Live credential container combining tokens + refresh metadata.
public struct CodexOAuth: Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var accountId: String?
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

    /// Whether the token should be refreshed.
    /// Codex uses age-based refresh: token age > 8 days from `last_refresh`.
    public func needsRefresh(maxAgeDays: Double = 8.0) -> Bool {
        guard let lastRefresh else { return true }
        let ageSeconds = Date().timeIntervalSince(lastRefresh)
        let maxAgeSeconds = maxAgeDays * 24 * 60 * 60
        return ageSeconds >= maxAgeSeconds
    }
}

// MARK: - Token Refresh

/// Response from Codex OAuth token refresh.
public struct CodexTokenRefreshResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}

// MARK: - Constants

public enum CodexConstants {
    /// Codex's OAuth client ID (public, used for token refresh).
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    /// Primary credential file path relative to home directory.
    public static let credentialRelativePath = ".config/codex/auth.json"
    /// Fallback credential file path relative to home directory.
    public static let credentialFallbackPath = ".codex/auth.json"
    /// macOS Keychain service name used by Codex.
    public static let keychainService = "Codex Auth"
    /// Token refresh URL.
    public static let refreshURL = "https://auth.openai.com/oauth/token"
    /// Usage API URL.
    public static let usageURL = "https://chatgpt.com/backend-api/wham/usage"
}

// MARK: - Parsing Utilities

extension CodexCredentialFile {
    /// Attempts to parse credential JSON from raw text.
    /// Handles the macOS Keychain edge case where data is returned as hex-encoded UTF-8 bytes.
    public static func parse(from text: String) -> CodexCredentialFile? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct JSON parse first
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(CodexCredentialFile.self, from: data)
        {
            return parsed
        }

        // Try hex-decode (macOS Keychain sometimes returns hex-encoded bytes)
        var hex = trimmed
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        guard !hex.isEmpty, hex.count % 2 == 0,
              hex.allSatisfy({ $0.isHexDigit })
        else {
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

    /// Convert to a live `CodexOAuth` by parsing the `lastRefresh` date.
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
