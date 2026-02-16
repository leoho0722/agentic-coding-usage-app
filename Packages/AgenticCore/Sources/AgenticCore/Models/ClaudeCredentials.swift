import Foundation

// MARK: - Claude Code Credential File Structure

/// Root structure of `~/.claude/.credentials.json`.
public struct ClaudeCredentialFile: Codable, Sendable {
    public let claudeAiOauth: ClaudeOAuth?

    public init(claudeAiOauth: ClaudeOAuth? = nil) {
        self.claudeAiOauth = claudeAiOauth
    }
}

/// OAuth credentials stored by Claude Code.
public struct ClaudeOAuth: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    /// Token expiration as Unix timestamp in **milliseconds**.
    public var expiresAt: Double?
    /// Subscription type string (e.g. "pro", "max", "free").
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

    /// Whether the token has expired or is about to expire (within `bufferMs`).
    /// - Parameter bufferMs: Buffer in milliseconds before actual expiry (default 5 minutes).
    public func needsRefresh(bufferMs: Double = 5 * 60 * 1000) -> Bool {
        guard let expiresAt else { return false }
        let nowMs = Date().timeIntervalSince1970 * 1000
        return nowMs >= (expiresAt - bufferMs)
    }
}

// MARK: - Token Refresh

/// Request body for Claude OAuth token refresh.
public struct ClaudeTokenRefreshRequest: Codable, Sendable {
    public let grantType: String
    public let refreshToken: String
    public let clientId: String
    public let scope: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
        case scope
    }

    public init(refreshToken: String) {
        self.grantType = "refresh_token"
        self.refreshToken = refreshToken
        self.clientId = ClaudeConstants.clientID
        self.scope = ClaudeConstants.scopes
    }
}

/// Response from Claude OAuth token refresh.
public struct ClaudeTokenRefreshResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    /// Token lifetime in seconds.
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - Constants

public enum ClaudeConstants {
    /// Claude Code's own OAuth client ID (public, used for token refresh).
    public static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    public static let scopes = "user:profile user:inference user:sessions:claude_code user:mcp_servers"
    /// Credential file path relative to home directory.
    public static let credentialRelativePath = ".claude/.credentials.json"
    /// macOS Keychain service name used by Claude Code.
    public static let keychainService = "Claude Code-credentials"
    /// Refresh URL for OAuth tokens.
    public static let refreshURL = "https://platform.claude.com/v1/oauth/token"
    /// Usage API URL.
    public static let usageURL = "https://api.anthropic.com/api/oauth/usage"
}

// MARK: - Hex Decoding Utility

extension ClaudeCredentialFile {
    /// Attempts to parse credential JSON from raw text.
    /// Handles the macOS Keychain edge case where data is returned as hex-encoded UTF-8 bytes.
    public static func parse(from text: String) -> ClaudeCredentialFile? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct JSON parse first
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(ClaudeCredentialFile.self, from: data)
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
        return try? JSONDecoder().decode(ClaudeCredentialFile.self, from: data)
    }
}
