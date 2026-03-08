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
    
    /// 以指定的閉包建立實例。
    ///
    /// - Parameters:
    ///   - loadCredentials: 從本機 SQLite 資料庫或快取檔案載入 Antigravity 憑證。
    ///   - refreshTokenIfNeeded: 若權杖已過期或即將過期，使用 Google OAuth 重新整理存取權杖。
    ///   - fetchUsage: 從 Cloud Code API 取得用量資料。
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
                let dbPath = FileManager.default.realHomeDirectory.appendingPathComponent(AntigravityConstants.dbRelativePath).path
                
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
                if let cached = Self.loadCachedToken() {
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
                
                let request = RequestBuilder(urlString: AntigravityConstants.refreshURL)
                    .method(.post)
                    .formBody([
                        "grant_type=refresh_token",
                        "client_id=\(clientID)",
                        "client_secret=\(clientSecret)",
                        "refresh_token=\(refreshToken)",
                    ])
                    .build()
                
                let (httpResponse, data) = try await HTTPClient().fetchRaw(request) { httpResponse, responseData in
                    // 401: 回傳 data 讓外層處理，跳過預設驗證
                    if httpResponse.statusCode == 401 {
                        return responseData
                    }
                    // 其他非 2xx: 拋出 refreshFailed
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw AntigravityAPIError.refreshFailed(
                            statusCode: httpResponse.statusCode,
                            message: extractErrorMessage(from: responseData)
                        )
                    }
                    return nil
                }
                
                // 401 表示 refresh token 已被使用或過期，
                // 但 access token 可能仍然有效，回傳當前憑證讓後續 API 呼叫驗證。
                if httpResponse.statusCode == 401 {
                    return current
                }
                
                let refreshResponse = try JSONDecoder().decode(
                    AntigravityTokenRefreshResponse.self,
                    from: data
                )
                
                let now = Int64(Date().timeIntervalSince1970)
                let newExpiry: Int64
                if let expiresIn = refreshResponse.expiresIn {
                    newExpiry = now + Int64(expiresIn)
                } else {
                    newExpiry = current.expirySeconds ?? (now + 3600)
                }
                
                let updated = AntigravityCredential(
                    accessToken: refreshResponse.accessToken,
                    refreshToken: refreshToken,
                    expirySeconds: newExpiry,
                    source: .refreshedToken
                )
                
                // 將更新後的權杖寫入快取
                Self.saveCachedToken(updated)
                
                return updated
            },
            fetchUsage: { accessToken in
                // 嘗試主要 URL，失敗時使用備用 URL
                do {
                    return try await Self.fetchModels(accessToken: accessToken, urlString: AntigravityConstants.usageURL)
                } catch {
                    return try await Self.fetchModels(accessToken: accessToken, urlString: AntigravityConstants.usageFallbackURL)
                }
            }
        )
    }
}

// MARK: - 私有輔助

private extension AntigravityAPIClient {

    /// 本機快取用的 Antigravity 權杖結構。
    struct CachedAntigravityToken: Codable {

        /// 存取權杖。
        let accessToken: String

        /// 重新整理權杖，可能為 `nil`。
        let refreshToken: String?

        /// 權杖到期時間（Unix 秒）。
        let expirySeconds: Int64?
    }

    /// 從指定 URL 取得模型用量資料。
    ///
    /// - Parameters:
    ///   - accessToken: Antigravity 存取權杖。
    ///   - urlString: 用量查詢 API 的完整 URL 字串。
    /// - Returns: 解碼後的 ``AntigravityUsageResponse``。
    static func fetchModels(accessToken: String, urlString: String) async throws -> AntigravityUsageResponse {
        let request = RequestBuilder(urlString: urlString)
            .method(.post)
            .bearerToken(accessToken)
            .header("User-Agent", "antigravity")
            .jsonBody("{}")
            .build()

        do {
            return try await HTTPClient().fetch(request, responseType: AntigravityUsageResponse.self) { httpResponse, data in
                // 401 直接拋出錯誤
                guard httpResponse.statusCode != 401 else {
                    throw AntigravityAPIError.httpError(
                        statusCode: 401,
                        message: "Unauthorized — token may have expired"
                    )
                }
                return nil
            }
        } catch let error as AntigravityAPIError {
            throw error
        } catch let error as HTTPClientError {
            throw error.toAntigravityAPIError()
        }
    }

    /// 從本機快取檔案載入權杖。
    ///
    /// - Returns: 解碼後的 ``CachedAntigravityToken``，檔案不存在或解碼失敗時回傳 `nil`。
    static func loadCachedToken() -> CachedAntigravityToken? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cacheURL = cacheDir?.appendingPathComponent(AntigravityConstants.cachedTokenFileName),
              let data = FileManager.default.contents(atPath: cacheURL.path) else {
            return nil
        }
        return try? JSONDecoder().decode(CachedAntigravityToken.self, from: data)
    }

    /// 將權杖寫入本機快取檔案。
    ///
    /// - Parameter credential: 要寫入快取的 Antigravity 憑證。
    static func saveCachedToken(_ credential: AntigravityCredential) {
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
}

extension HTTPClientError {
    
    /// 將 `HTTPClientError` 轉換為對應的 ``AntigravityAPIError``。
    ///
    /// - Returns: 對應的 ``AntigravityAPIError``。
    func toAntigravityAPIError() -> AntigravityAPIError {
        switch self {
        case .invalidResponse:
                .invalidResponse
        case let .httpError(statusCode, message, _):
                .httpError(statusCode: statusCode, message: message)
        case let .decodingFailed(underlyingError, rawResponse):
                .decodingFailed(underlyingError: underlyingError, rawResponse: rawResponse)
        }
    }
}
