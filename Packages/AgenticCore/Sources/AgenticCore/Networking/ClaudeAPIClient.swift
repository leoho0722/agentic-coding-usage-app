import Foundation
import Security

// MARK: - Claude API Client

/// A dependency-injectable Claude Code API client.
///
/// Provides credential loading (file + Keychain fallback), token refresh with write-back,
/// and usage fetching. Closure-based injection so TCA and CLI can each provide their own
/// implementations (live, mock, etc.).
public struct ClaudeAPIClient: Sendable {
    /// Load Claude Code OAuth credentials from `~/.claude/.credentials.json` or Keychain.
    public var loadCredentials: @Sendable () throws -> ClaudeOAuth?
    /// Refresh the access token if expired/expiring. Returns updated credentials.
    /// Writes refreshed tokens back to the original source.
    public var refreshTokenIfNeeded: @Sendable (_ current: ClaudeOAuth) async throws -> ClaudeOAuth
    /// Fetch usage data from the Claude API.
    public var fetchUsage: @Sendable (_ accessToken: String) async throws -> ClaudeUsageResponse

    public init(
        loadCredentials: @escaping @Sendable () throws -> ClaudeOAuth?,
        refreshTokenIfNeeded: @escaping @Sendable (_ current: ClaudeOAuth) async throws -> ClaudeOAuth,
        fetchUsage: @escaping @Sendable (_ accessToken: String) async throws -> ClaudeUsageResponse
    ) {
        self.loadCredentials = loadCredentials
        self.refreshTokenIfNeeded = refreshTokenIfNeeded
        self.fetchUsage = fetchUsage
    }
}

// MARK: - Errors

public enum ClaudeAPIError: LocalizedError, Sendable {
    case credentialsNotFound
    case refreshFailed(statusCode: Int, message: String)
    case noRefreshToken
    case httpError(statusCode: Int, message: String)
    case invalidResponse
    case decodingFailed(underlyingError: any Error, rawResponse: String)

    public var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            "Claude Code credentials not found. Please log in via terminal: claude login"
        case let .refreshFailed(statusCode, message):
            "Token refresh failed (\(statusCode)): \(message)"
        case .noRefreshToken:
            "No refresh token available. Please re-login via terminal: claude login"
        case let .httpError(statusCode, message):
            "Claude API error (\(statusCode)): \(message)"
        case .invalidResponse:
            "Invalid response from Claude API"
        case let .decodingFailed(underlyingError, rawResponse):
            "Failed to decode Claude API response: \(underlyingError.localizedDescription)\nRaw response: \(rawResponse.prefix(500))"
        }
    }
}

// MARK: - Live Implementation

extension ClaudeAPIClient {
    public static func live(clientID: String) -> ClaudeAPIClient {
        ClaudeAPIClient(
        loadCredentials: {
            // 1. Try file first
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let credentialPath = homeDir.appendingPathComponent(ClaudeConstants.credentialRelativePath)

            if let fileData = FileManager.default.contents(atPath: credentialPath.path),
               let fileText = String(data: fileData, encoding: .utf8),
               let file = ClaudeCredentialFile.parse(from: fileText),
               let oauth = file.claudeAiOauth
            {
                return oauth
            }

            // 2. Fallback to macOS Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: ClaudeConstants.keychainService,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }

            // Keychain data may be plain JSON or hex-encoded
            if let text = String(data: data, encoding: .utf8),
               let file = ClaudeCredentialFile.parse(from: text),
               let oauth = file.claudeAiOauth
            {
                return oauth
            }

            return nil
        },

        refreshTokenIfNeeded: { current in
            guard current.needsRefresh() else { return current }

            guard let refreshToken = current.refreshToken else {
                throw ClaudeAPIError.noRefreshToken
            }

            let refreshRequest = ClaudeTokenRefreshRequest(refreshToken: refreshToken, clientID: clientID)
            var request = URLRequest(url: URL(string: ClaudeConstants.refreshURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(refreshRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeAPIError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ClaudeAPIError.refreshFailed(
                    statusCode: httpResponse.statusCode,
                    message: message
                )
            }

            let refreshResponse = try JSONDecoder().decode(ClaudeTokenRefreshResponse.self, from: data)

            // Build updated credentials
            let nowMs = Date().timeIntervalSince1970 * 1000
            let expiresAtMs: Double? = if let expiresIn = refreshResponse.expiresIn {
                nowMs + Double(expiresIn) * 1000
            } else {
                current.expiresAt
            }

            let updated = ClaudeOAuth(
                accessToken: refreshResponse.accessToken,
                refreshToken: refreshResponse.refreshToken ?? current.refreshToken,
                expiresAt: expiresAtMs,
                subscriptionType: current.subscriptionType
            )

            // Write back to credential file
            writeBackCredentials(updated)

            return updated
        },

        fetchUsage: { accessToken in
            var request = URLRequest(url: URL(string: ClaudeConstants.usageURL)!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeAPIError.invalidResponse
            }

            // Handle 401 — token may have expired between refresh check and actual request
            guard httpResponse.statusCode != 401 else {
                throw ClaudeAPIError.httpError(
                    statusCode: 401,
                    message: "Unauthorized — token may have expired"
                )
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ClaudeAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
            } catch {
                let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
                throw ClaudeAPIError.decodingFailed(underlyingError: error, rawResponse: rawJSON)
            }
        }
    )
    }
}

// MARK: - Write-back Helper

/// Write refreshed credentials back to `~/.claude/.credentials.json`.
private func writeBackCredentials(_ oauth: ClaudeOAuth) {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let credentialPath = homeDir.appendingPathComponent(ClaudeConstants.credentialRelativePath)

    // Read existing file to preserve other keys
    var existingDict: [String: Any] = [:]
    if let fileData = FileManager.default.contents(atPath: credentialPath.path),
       let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any]
    {
        existingDict = json
    }

    // Build the claudeAiOauth sub-dict
    var oauthDict: [String: Any] = [
        "accessToken": oauth.accessToken,
    ]
    if let refreshToken = oauth.refreshToken {
        oauthDict["refreshToken"] = refreshToken
    }
    if let expiresAt = oauth.expiresAt {
        oauthDict["expiresAt"] = expiresAt
    }
    if let subscriptionType = oauth.subscriptionType {
        oauthDict["subscriptionType"] = subscriptionType
    }

    existingDict["claudeAiOauth"] = oauthDict

    // Write back
    if let data = try? JSONSerialization.data(withJSONObject: existingDict, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: credentialPath)
    }
}
