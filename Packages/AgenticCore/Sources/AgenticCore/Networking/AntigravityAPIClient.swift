import Foundation

// MARK: - Antigravity API 用戶端

/// 可依賴注入的 Antigravity API 用戶端。
///
/// 提供憑證載入（SQLite + proto tokens + cached token）、權杖重新整理與用量查詢功能。
/// 透過閉包注入，讓 TCA 與 CLI 可各自提供不同的實作（正式版、模擬版等）。
public struct AntigravityAPIClient: Sendable {

    /// 從本機 SQLite 資料庫或快取檔案載入 Antigravity 憑證。
    public var loadCredentials: @Sendable () throws -> AntigravityCredential?

    /// 若權杖已過期或即將過期，使用 Google OAuth 重新整理存取權杖。
    public var refreshTokenIfNeeded: @Sendable (_ current: AntigravityCredential) async throws -> AntigravityCredential

    /// 從 Cloud Code API 取得用量資料。
    public var fetchUsage: @Sendable (_ accessToken: String) async throws -> AntigravityUsageResponse

    public init(
        loadCredentials: @escaping @Sendable () throws -> AntigravityCredential?,
        refreshTokenIfNeeded: @escaping @Sendable (_ current: AntigravityCredential) async throws -> AntigravityCredential,
        fetchUsage: @escaping @Sendable (_ accessToken: String) async throws -> AntigravityUsageResponse
    ) {
        self.loadCredentials = loadCredentials
        self.refreshTokenIfNeeded = refreshTokenIfNeeded
        self.fetchUsage = fetchUsage
    }
}

// MARK: - 錯誤

/// Antigravity API 錯誤。
public enum AntigravityAPIError: LocalizedError, Sendable {

    /// 找不到憑證。
    case credentialsNotFound

    /// 權杖重新整理失敗，附帶狀態碼與訊息。
    case refreshFailed(statusCode: Int, message: String)

    /// 無可用的重新整理權杖。
    case noRefreshToken

    /// HTTP 錯誤，附帶狀態碼與訊息。
    case httpError(statusCode: Int, message: String)

    /// 無效的回應。
    case invalidResponse

    /// 解碼失敗，附帶底層錯誤與原始回應。
    case decodingFailed(underlyingError: any Error, rawResponse: String)

    /// SQLite 讀取失敗。
    case sqliteReadFailed

    public var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            "Antigravity credentials not found. Please log in via Antigravity IDE first."
        case let .refreshFailed(statusCode, message):
            "Token refresh failed (\(statusCode)): \(message)"
        case .noRefreshToken:
            "No refresh token available. Please re-login via Antigravity IDE."
        case let .httpError(statusCode, message):
            "Antigravity API error (\(statusCode)): \(message)"
        case .invalidResponse:
            "Invalid response from Antigravity API"
        case let .decodingFailed(underlyingError, rawResponse):
            """
            Failed to decode Antigravity API response: \
            \(underlyingError.localizedDescription)
            Raw response: \(rawResponse.prefix(500))
            """
        case .sqliteReadFailed:
            "Failed to read Antigravity SQLite database."
        }
    }
}

// MARK: - 正式版實作

extension AntigravityAPIClient {

    /// 建立使用 `URLSession` 的正式版實作。
    ///
    /// - Parameters:
    ///   - clientID: Google OAuth 用戶端識別碼。
    ///   - clientSecret: Google OAuth 用戶端密鑰。
    /// - Returns: 已設定好的 ``AntigravityAPIClient`` 實例。
    public static func live(clientID: String, clientSecret: String) -> AntigravityAPIClient {
        AntigravityAPIClient(
            loadCredentials: {
                // 在 App Sandbox 中，FileManager.homeDirectoryForCurrentUser 回傳容器路徑，
                // 需使用 getpwuid 取得真實家目錄，搭配 absolute-path entitlement 存取。
                let homeDir: URL = if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
                    URL(fileURLWithPath: String(cString: dir))
                } else {
                    FileManager.default.homeDirectoryForCurrentUser
                }
                let dbPath = homeDir.appendingPathComponent(AntigravityConstants.dbRelativePath).path

                // 1. 嘗試從 proto tokens 載入（優先）
                let protoValue = SQLiteReader.readValue(from: dbPath, forKey: AntigravityConstants.protoTokenKey)
                if let protoValue,
                   let tokens = ProtobufDecoder.decodeAntigravityTokens(from: protoValue) {
                    return AntigravityCredential(
                        accessToken: tokens.accessToken,
                        refreshToken: tokens.refreshToken,
                        expirySeconds: tokens.expirySeconds,
                        source: .protoToken
                    )
                }

                // 2. 嘗試從快取權杖檔案載入
                if let cached = loadCachedToken() {
                    return AntigravityCredential(
                        accessToken: cached.accessToken,
                        refreshToken: cached.refreshToken,
                        expirySeconds: cached.expirySeconds,
                        source: .refreshedToken
                    )
                }

                // 3. 嘗試從 authStatus 中的 API key 載入
                let authStatusJSON = SQLiteReader.readValue(from: dbPath, forKey: AntigravityConstants.authStatusKey)
                if let authStatusJSON,
                   let data = authStatusJSON.data(using: .utf8),
                   let authStatus = try? JSONDecoder().decode(AntigravityAuthStatus.self, from: data),
                   let apiKey = authStatus.apiKey,
                   !apiKey.isEmpty {
                    return AntigravityCredential(
                        accessToken: apiKey,
                        source: .apiKey
                    )
                }

                return nil
            },
            refreshTokenIfNeeded: { current in
                guard current.needsRefresh() else {
                    return current
                }

                guard let refreshToken = current.refreshToken else {
                    throw AntigravityAPIError.noRefreshToken
                }

                // Google OAuth 使用 form-urlencoded POST
                var request = URLRequest(url: URL(string: AntigravityConstants.refreshURL)!)
                request.httpMethod = "POST"
                request.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "Content-Type"
                )

                let bodyParams = [
                    "grant_type=refresh_token",
                    "client_id=\(clientID)",
                    "client_secret=\(clientSecret)",
                    "refresh_token=\(refreshToken)",
                ].joined(separator: "&")
                request.httpBody = bodyParams.data(using: .utf8)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AntigravityAPIError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw AntigravityAPIError.refreshFailed(
                        statusCode: httpResponse.statusCode,
                        message: message
                    )
                }

                let refreshResponse = try JSONDecoder().decode(
                    AntigravityTokenRefreshResponse.self,
                    from: data
                )

                let now = Int64(Date().timeIntervalSince1970)
                let newExpiry: Int64 = if let expiresIn = refreshResponse.expiresIn {
                    now + Int64(expiresIn)
                } else {
                    current.expirySeconds ?? (now + 3600)
                }

                let updated = AntigravityCredential(
                    accessToken: refreshResponse.accessToken,
                    refreshToken: refreshToken,
                    expirySeconds: newExpiry,
                    source: .refreshedToken
                )

                // 將更新後的權杖寫入快取
                saveCachedToken(updated)

                return updated
            },
            fetchUsage: { accessToken in
                // 嘗試主要 URL，失敗時使用備用 URL
                do {
                    return try await fetchModels(accessToken: accessToken, urlString: AntigravityConstants.usageURL)
                } catch {
                    return try await fetchModels(accessToken: accessToken, urlString: AntigravityConstants.usageFallbackURL)
                }
            }
        )
    }
}

// MARK: - 私有輔助

/// 從指定 URL 取得模型用量資料。
private func fetchModels(accessToken: String, urlString: String) async throws -> AntigravityUsageResponse {
    var request = URLRequest(url: URL(string: urlString)!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("antigravity", forHTTPHeaderField: "User-Agent")
    request.httpBody = "{}".data(using: .utf8)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AntigravityAPIError.invalidResponse
    }

    guard httpResponse.statusCode != 401 else {
        throw AntigravityAPIError.httpError(
            statusCode: 401,
            message: "Unauthorized — token may have expired"
        )
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AntigravityAPIError.httpError(
            statusCode: httpResponse.statusCode,
            message: message
        )
    }

    do {
        return try JSONDecoder().decode(AntigravityUsageResponse.self, from: data)
    } catch {
        let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
        throw AntigravityAPIError.decodingFailed(
            underlyingError: error,
            rawResponse: rawJSON
        )
    }
}

/// 快取權杖結構。
private struct CachedAntigravityToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expirySeconds: Int64?
}

/// 從本機快取檔案載入權杖。
private func loadCachedToken() -> CachedAntigravityToken? {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let cacheURL = cacheDir?.appendingPathComponent(AntigravityConstants.cachedTokenFileName),
          let data = FileManager.default.contents(atPath: cacheURL.path) else {
        return nil
    }
    return try? JSONDecoder().decode(CachedAntigravityToken.self, from: data)
}

/// 將權杖寫入本機快取檔案。
private func saveCachedToken(_ credential: AntigravityCredential) {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let cacheURL = cacheDir?.appendingPathComponent(AntigravityConstants.cachedTokenFileName) else {
        return
    }
    let cached = CachedAntigravityToken(
        accessToken: credential.accessToken,
        refreshToken: credential.refreshToken,
        expirySeconds: credential.expirySeconds
    )
    if let data = try? JSONEncoder().encode(cached) {
        try? data.write(to: cacheURL)
    }
}
