import Foundation
import Security

// MARK: - Claude API 用戶端

/// 可依賴注入的 Claude Code API 用戶端。
///
/// 提供憑證載入（檔案 + 鑰匙圈備援）、權杖重新整理與回寫、以及用量查詢功能。
/// 透過閉包注入，讓 TCA 與 CLI 可各自提供不同的實作（正式版、模擬版等）。
public struct ClaudeAPIClient: Sendable {
    
    /// 從 `~/.claude/.credentials.json` 或鑰匙圈載入 Claude Code OAuth 憑證。
    public var loadCredentials: @Sendable () throws -> ClaudeOAuth?
    
    /// 若權杖已過期或即將過期，重新整理存取權杖。回傳更新後的憑證，並將新權杖回寫至原始來源。
    public var refreshTokenIfNeeded: @Sendable (_ current: ClaudeOAuth) async throws -> ClaudeOAuth
    
    /// 從 Claude API 取得用量資料。
    public var fetchUsage: @Sendable (_ accessToken: String) async throws -> ClaudeUsageResponse
    
    /// 以指定的閉包建立實例。
    ///
    /// - Parameters:
    ///   - loadCredentials: 從 `~/.claude/.credentials.json` 或鑰匙圈載入 Claude Code OAuth 憑證。
    ///   - refreshTokenIfNeeded: 若權杖已過期或即將過期，重新整理存取權杖。回傳更新後的憑證，並將新權杖回寫至原始來源。
    ///   - fetchUsage: 從 Claude API 取得用量資料。
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

// MARK: - 錯誤

/// Claude API 錯誤。
public enum ClaudeAPIError: LocalizedError, Sendable {
    
    /// 找不到憑證。
    case credentialsNotFound
    
    /// 權杖重新整理失敗，附帶狀態碼與訊息。
    case refreshFailed(statusCode: Int, message: String)
    
    /// 無可用的重新整理權杖。
    case noRefreshToken
    
    /// OAuth token 缺少必要的 scope。
    case insufficientScope(String)
    
    /// HTTP 錯誤，附帶狀態碼與訊息。
    case httpError(statusCode: Int, message: String)
    
    /// 無效的回應。
    case invalidResponse
    
    /// 解碼失敗，附帶底層錯誤與原始回應。
    case decodingFailed(underlyingError: any Error, rawResponse: String)
    
    /// 是否為 refresh token 過期導致的 HTTP 400 錯誤。
    public var isRefreshTokenExpired: Bool {
        if case let .refreshFailed(statusCode, _) = self, statusCode == 400 {
            return true
        }
        return false
    }
    
    /// 是否為 scope 不足導致的 HTTP 403 錯誤。
    public var isInsufficientScope: Bool {
        if case .insufficientScope = self { return true }
        return false
    }
    
    public var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            "Claude Code credentials not found. Please log in via terminal: claude login"
        case let .insufficientScope(detail):
            "Claude 權限不足，請在終端機執行 `claude login` 重新登入。(\(detail))"
        case let .refreshFailed(statusCode, message):
            "Token refresh failed (\(statusCode)): \(message)"
        case .noRefreshToken:
            "No refresh token available. Please re-login via terminal: claude login"
        case let .httpError(statusCode, message):
            "Claude API error (\(statusCode)): \(message)"
        case .invalidResponse:
            "Invalid response from Claude API"
        case let .decodingFailed(underlyingError, rawResponse):
            """
            Failed to decode Claude API response: \
            \(underlyingError.localizedDescription)
            Raw response: \(rawResponse.prefix(500))
            """
        }
    }
}

// MARK: - 正式版實作

extension ClaudeAPIClient {
    
    /// 建立使用 `URLSession` 的正式版實作。
    ///
    /// - Parameter clientID: OAuth 用戶端識別碼。
    /// - Returns: 已設定好的 ``ClaudeAPIClient`` 實例。
    public static func live(clientID: String) -> ClaudeAPIClient {
        ClaudeAPIClient(
            loadCredentials: {
                var candidates: [ClaudeOAuth] = []
                
                // 1. 嘗試從檔案載入
                let credentialPath = FileManager.default.realHomeDirectory.appendingPathComponent(ClaudeConstants.credentialRelativePath)
                
                if let fileData = FileManager.default.contents(atPath: credentialPath.path),
                   let fileText = String(data: fileData, encoding: .utf8),
                   let file = ClaudeCredentialFile.parse(from: fileText),
                   let oauth = file.claudeAiOauth {
                    candidates.append(oauth)
                }
                
                // 2. macOS 鑰匙圈
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: ClaudeConstants.keychainService,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ]
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                
                if status == errSecSuccess,
                   let data = result as? Data,
                   let text = String(data: data, encoding: .utf8),
                   let file = ClaudeCredentialFile.parse(from: text),
                   let oauth = file.claudeAiOauth {
                    candidates.append(oauth)
                }
                
                // 從所有來源中選出最新的憑證（依 expiresAt 排序）
                return candidates.max {
                    ($0.expiresAt ?? 0) < ($1.expiresAt ?? 0)
                }
            },
            refreshTokenIfNeeded: { current in
                guard current.needsRefresh() else {
                    return current
                }
                
                guard let refreshToken = current.refreshToken else {
                    throw ClaudeAPIError.noRefreshToken
                }
                
                let refreshBody = ClaudeTokenRefreshRequest(
                    refreshToken: refreshToken,
                    clientID: clientID
                )
                let request = try RequestBuilder(urlString: ClaudeConstants.refreshURL)
                    .method(.post)
                    .jsonBody(refreshBody)
                    .build()
                
                let (httpResponse, data) = try await HTTPClient().fetchRaw(request) { httpResponse, responseData in
                    // 401: 回傳 data 讓外層處理，跳過預設驗證
                    if httpResponse.statusCode == 401 {
                        return responseData
                    }
                    // 其他非 2xx: 拋出 refreshFailed
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw ClaudeAPIError.refreshFailed(
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
                    ClaudeTokenRefreshResponse.self,
                    from: data
                )
                
                // 建構更新後的憑證
                let nowMs = Date().timeIntervalSince1970 * 1000
                let expiresAtMs: Double?
                if let expiresIn = refreshResponse.expiresIn {
                    expiresAtMs = nowMs + Double(expiresIn) * 1000
                } else {
                    expiresAtMs = current.expiresAt
                }
                
                let updated = ClaudeOAuth(
                    accessToken: refreshResponse.accessToken,
                    refreshToken: refreshResponse.refreshToken ?? current.refreshToken,
                    expiresAt: expiresAtMs,
                    subscriptionType: current.subscriptionType
                )
                
                // 將更新後的憑證回寫至檔案
                Self.writeBackCredentials(updated)
                
                return updated
            },
            fetchUsage: { accessToken in
                let request = RequestBuilder(urlString: ClaudeConstants.usageURL)
                    .method(.get)
                    .bearerToken(accessToken)
                    .header("anthropic-beta", "oauth-2025-04-20")
                    .build()
                
                do {
                    return try await HTTPClient().fetch(request, responseType: ClaudeUsageResponse.self) { httpResponse, responseData in
                        // 401 — 權杖可能在重新整理檢查與實際請求之間過期
                        guard httpResponse.statusCode != 401 else {
                            throw ClaudeAPIError.httpError(
                                statusCode: 401,
                                message: "Unauthorized — token may have expired"
                            )
                        }
                        // 403 — scope 不足，需要重新登入
                        guard httpResponse.statusCode != 403 else {
                            let message = extractErrorMessage(from: responseData)
                            if message.contains("scope") {
                                throw ClaudeAPIError.insufficientScope(message)
                            }
                            throw ClaudeAPIError.httpError(statusCode: 403, message: message)
                        }
                        return nil
                    }
                } catch let error as ClaudeAPIError {
                    throw error
                } catch let error as HTTPClientError {
                    throw error.toClaudeAPIError()
                }
            }
        )
    }
}

// MARK: - 私有輔助

private extension ClaudeAPIClient {

    /// 將更新後的憑證回寫至 `~/.claude/.credentials.json`。
    ///
    /// - Parameter oauth: 要回寫的 OAuth 憑證。
    static func writeBackCredentials(_ oauth: ClaudeOAuth) {
        let credentialPath = FileManager.default.realHomeDirectory.appendingPathComponent(ClaudeConstants.credentialRelativePath)

        // 讀取既有檔案以保留其他欄位
        var existingDict: [String: Any] = [:]
        if let fileData = FileManager.default.contents(atPath: credentialPath.path),
           let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
            existingDict = json
        }

        // 建構 claudeAiOauth 子字典
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

        // 回寫檔案
        if let data = try? JSONSerialization.data(
            withJSONObject: existingDict,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: credentialPath)
        }
    }
}

extension HTTPClientError {
    
    /// 將 `HTTPClientError` 轉換為對應的 ``ClaudeAPIError``。
    ///
    /// - Returns: 對應的 ``ClaudeAPIError``。
    func toClaudeAPIError() -> ClaudeAPIError {
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
