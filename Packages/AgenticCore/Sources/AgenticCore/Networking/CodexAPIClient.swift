import Foundation
import Security

// MARK: - Codex API Client

/// A dependency-injectable Codex API client.
///
/// Provides credential loading (file + Keychain fallback), token refresh with write-back,
/// and usage fetching. Closure-based injection so TCA and CLI can each provide their own
/// implementations (live, mock, etc.).
public struct CodexAPIClient: Sendable {
    /// Load Codex OAuth credentials from config files or Keychain.
    public var loadCredentials: @Sendable () throws -> CodexOAuth?
    /// Refresh the access token if expired/expiring. Returns updated credentials.
    public var refreshTokenIfNeeded: @Sendable (_ current: CodexOAuth) async throws -> CodexOAuth
    /// Fetch usage data from the Codex API. Returns headers and body response.
    public var fetchUsage: @Sendable (_ accessToken: String, _ accountId: String?) async throws -> (CodexUsageHeaders, CodexUsageResponse)

    public init(
        loadCredentials: @escaping @Sendable () throws -> CodexOAuth?,
        refreshTokenIfNeeded: @escaping @Sendable (_ current: CodexOAuth) async throws -> CodexOAuth,
        fetchUsage: @escaping @Sendable (_ accessToken: String, _ accountId: String?) async throws -> (CodexUsageHeaders, CodexUsageResponse)
    ) {
        self.loadCredentials = loadCredentials
        self.refreshTokenIfNeeded = refreshTokenIfNeeded
        self.fetchUsage = fetchUsage
    }
}

// MARK: - Errors

public enum CodexAPIError: LocalizedError, Sendable {
    case credentialsNotFound
    case refreshFailed(statusCode: Int, message: String)
    case noRefreshToken
    case httpError(statusCode: Int, message: String)
    case invalidResponse
    case decodingFailed(underlyingError: any Error, rawResponse: String)

    public var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            "Codex credentials not found. Please log in via terminal: codex auth login"
        case let .refreshFailed(statusCode, message):
            "Token refresh failed (\(statusCode)): \(message)"
        case .noRefreshToken:
            "No refresh token available. Please re-login via terminal: codex auth login"
        case let .httpError(statusCode, message):
            "Codex API error (\(statusCode)): \(message)"
        case .invalidResponse:
            "Invalid response from Codex API"
        case let .decodingFailed(underlyingError, rawResponse):
            "Failed to decode Codex API response: \(underlyingError.localizedDescription)\nRaw response: \(rawResponse.prefix(500))"
        }
    }
}

// MARK: - Live Implementation

extension CodexAPIClient {
    public static let live = CodexAPIClient(
        loadCredentials: {
            let fileManager = FileManager.default
            let homeDir = fileManager.homeDirectoryForCurrentUser

            // 1. Try primary path: ~/.config/codex/auth.json
            let primaryPath = homeDir.appendingPathComponent(CodexConstants.credentialRelativePath)
            if let oauth = loadCredentialFile(at: primaryPath) {
                return oauth
            }

            // 2. Try fallback path: ~/.codex/auth.json
            let fallbackPath = homeDir.appendingPathComponent(CodexConstants.credentialFallbackPath)
            if let oauth = loadCredentialFile(at: fallbackPath) {
                return oauth
            }

            // 3. Try CODEX_HOME environment variable
            if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] {
                let envPath = URL(fileURLWithPath: codexHome).appendingPathComponent("auth.json")
                if let oauth = loadCredentialFile(at: envPath) {
                    return oauth
                }
            }

            // 4. Fallback to macOS Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: CodexConstants.keychainService,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }

            if let text = String(data: data, encoding: .utf8),
               let file = CodexCredentialFile.parse(from: text),
               let oauth = file.toOAuth()
            {
                return oauth
            }

            return nil
        },

        refreshTokenIfNeeded: { current in
            guard current.needsRefresh() else { return current }

            guard let refreshToken = current.refreshToken else {
                throw CodexAPIError.noRefreshToken
            }

            // Codex uses form-urlencoded POST (not JSON)
            var request = URLRequest(url: URL(string: CodexConstants.refreshURL)!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let bodyParams = [
                "grant_type=refresh_token",
                "client_id=\(CodexConstants.clientID)",
                "refresh_token=\(refreshToken)",
            ].joined(separator: "&")
            request.httpBody = bodyParams.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CodexAPIError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw CodexAPIError.refreshFailed(
                    statusCode: httpResponse.statusCode,
                    message: message
                )
            }

            let refreshResponse = try JSONDecoder().decode(CodexTokenRefreshResponse.self, from: data)

            let updated = CodexOAuth(
                accessToken: refreshResponse.accessToken,
                refreshToken: refreshResponse.refreshToken ?? current.refreshToken,
                accountId: current.accountId,
                lastRefresh: Date()
            )

            // Write back to credential file (best-effort; may fail silently in sandboxed apps)
            writeBackCodexCredentials(updated)

            return updated
        },

        fetchUsage: { accessToken, accountId in
            var request = URLRequest(url: URL(string: CodexConstants.usageURL)!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            // Include account ID header if available
            if let accountId, !accountId.isEmpty {
                request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CodexAPIError.invalidResponse
            }

            // Handle 401 — token may have expired between refresh check and actual request
            guard httpResponse.statusCode != 401 else {
                throw CodexAPIError.httpError(
                    statusCode: 401,
                    message: "Unauthorized — token may have expired"
                )
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw CodexAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            // Parse headers
            let headers = CodexUsageHeaders.from(httpResponse: httpResponse)

            // Parse body
            do {
                let body = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
                return (headers, body)
            } catch {
                let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
                throw CodexAPIError.decodingFailed(underlyingError: error, rawResponse: rawJSON)
            }
        }
    )
}

// MARK: - Private Helpers

/// Load and parse a Codex credential file at the given path.
private func loadCredentialFile(at url: URL) -> CodexOAuth? {
    guard let fileData = FileManager.default.contents(atPath: url.path),
          let fileText = String(data: fileData, encoding: .utf8),
          let file = CodexCredentialFile.parse(from: fileText),
          let oauth = file.toOAuth()
    else {
        return nil
    }
    return oauth
}

/// Write refreshed credentials back to the primary Codex credential file.
/// Best-effort: may fail silently in sandboxed apps with read-only entitlement.
private func writeBackCodexCredentials(_ oauth: CodexOAuth) {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let credentialPath = homeDir.appendingPathComponent(CodexConstants.credentialRelativePath)

    // Read existing file to preserve other keys
    var existingDict: [String: Any] = [:]
    if let fileData = FileManager.default.contents(atPath: credentialPath.path),
       let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any]
    {
        existingDict = json
    }

    // Build the tokens sub-dict
    var tokensDict: [String: Any] = [
        "access_token": oauth.accessToken,
    ]
    if let refreshToken = oauth.refreshToken {
        tokensDict["refresh_token"] = refreshToken
    }
    if let accountId = oauth.accountId {
        tokensDict["account_id"] = accountId
    }

    existingDict["tokens"] = tokensDict

    // Update last_refresh
    if let lastRefresh = oauth.lastRefresh {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        existingDict["last_refresh"] = formatter.string(from: lastRefresh)
    }

    // Write back
    if let data = try? JSONSerialization.data(withJSONObject: existingDict, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: credentialPath)
    }
}
