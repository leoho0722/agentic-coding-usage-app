import Foundation
import Security

// MARK: - Codex API 用戶端

/// 可依賴注入的 Codex API 用戶端。
///
/// 提供憑證載入（檔案 + 鑰匙圈備援）、權杖重新整理與回寫、以及用量查詢功能。
/// 透過閉包注入，讓 TCA 與 CLI 可各自提供不同的實作（正式版、模擬版等）。
public struct CodexAPIClient: Sendable {
    
    /// 從設定檔或鑰匙圈載入 Codex OAuth 憑證。
    public var loadCredentials: @Sendable () throws -> CodexOAuth?
    
    /// 若權杖已過期或即將過期，重新整理存取權杖。回傳更新後的憑證。
    public var refreshTokenIfNeeded: @Sendable (_ current: CodexOAuth) async throws -> CodexOAuth
    
    /// 從 Codex API 取得用量資料。回傳標頭與 Body 回應。
    public var fetchUsage: @Sendable (
        _ accessToken: String,
        _ accountId: String?
    ) async throws -> (CodexUsageHeaders, CodexUsageResponse)
    
    public init(
        loadCredentials: @escaping @Sendable () throws -> CodexOAuth?,
        refreshTokenIfNeeded: @escaping @Sendable (_ current: CodexOAuth) async throws -> CodexOAuth,
        fetchUsage: @escaping @Sendable (
            _ accessToken: String,
            _ accountId: String?
        ) async throws -> (CodexUsageHeaders, CodexUsageResponse)
    ) {
        self.loadCredentials = loadCredentials
        self.refreshTokenIfNeeded = refreshTokenIfNeeded
        self.fetchUsage = fetchUsage
    }
}

// MARK: - 錯誤

/// Codex API 錯誤。
public enum CodexAPIError: LocalizedError, Sendable {
    
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
            """
            Failed to decode Codex API response: \
            \(underlyingError.localizedDescription)
            Raw response: \(rawResponse.prefix(500))
            """
        }
    }
}

// MARK: - 正式版實作

extension CodexAPIClient {
    
    /// 建立使用 `URLSession` 的正式版實作。
    ///
    /// - Parameter clientID: OAuth 用戶端識別碼。
    /// - Returns: 已設定好的 ``CodexAPIClient`` 實例。
    public static func live(clientID: String) -> CodexAPIClient {
        CodexAPIClient(
            loadCredentials: {
                let fileManager = FileManager.default
                let homeDir = fileManager.homeDirectoryForCurrentUser
                
                // 1. 嘗試主要路徑：~/.config/codex/auth.json
                let primaryPath = homeDir.appendingPathComponent(CodexConstants.credentialRelativePath)
                if let oauth = loadCredentialFile(at: primaryPath) {
                    return oauth
                }
                
                // 2. 嘗試備用路徑：~/.codex/auth.json
                let fallbackPath = homeDir.appendingPathComponent(CodexConstants.credentialFallbackPath)
                if let oauth = loadCredentialFile(at: fallbackPath) {
                    return oauth
                }
                
                // 3. 嘗試 CODEX_HOME 環境變數
                if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] {
                    let envPath = URL(fileURLWithPath: codexHome).appendingPathComponent("auth.json")
                    if let oauth = loadCredentialFile(at: envPath) {
                        return oauth
                    }
                }
                
                // 4. 備援至 macOS 鑰匙圈
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: CodexConstants.keychainService,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ]
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                
                guard status == errSecSuccess,
                      let data = result as? Data else {
                    return nil
                }
                
                if let text = String(data: data, encoding: .utf8),
                   let file = CodexCredentialFile.parse(from: text),
                   let oauth = file.toOAuth() {
                    return oauth
                }
                
                return nil
            },
            refreshTokenIfNeeded: { current in
                guard current.needsRefresh() else {
                    return current
                }
                
                guard let refreshToken = current.refreshToken else {
                    throw CodexAPIError.noRefreshToken
                }
                
                // Codex 使用 form-urlencoded POST（非 JSON）
                var request = URLRequest(url: URL(string: CodexConstants.refreshURL)!)
                request.httpMethod = "POST"
                request.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "Content-Type"
                )
                
                let bodyParams = [
                    "grant_type=refresh_token",
                    "client_id=\(clientID)",
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
                
                let refreshResponse = try JSONDecoder().decode(
                    CodexTokenRefreshResponse.self,
                    from: data
                )
                
                let updated = CodexOAuth(
                    accessToken: refreshResponse.accessToken,
                    refreshToken: refreshResponse.refreshToken ?? current.refreshToken,
                    accountId: current.accountId,
                    lastRefresh: Date()
                )
                
                // 將憑證回寫至檔案（盡力而為；沙盒應用程式中可能靜默失敗）
                writeBackCodexCredentials(updated)
                
                return updated
            },
            fetchUsage: { accessToken, accountId in
                var request = URLRequest(url: URL(string: CodexConstants.usageURL)!)
                request.httpMethod = "GET"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                // 若有帳號 ID 則加入標頭
                if let accountId, !accountId.isEmpty {
                    request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CodexAPIError.invalidResponse
                }
                
                // 處理 401 -- 權杖可能在重新整理檢查與實際請求之間過期
                guard httpResponse.statusCode != 401 else {
                    throw CodexAPIError.httpError(
                        statusCode: 401,
                        message: "Unauthorized — token may have expired"
                    )
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw CodexAPIError.httpError(
                        statusCode: httpResponse.statusCode,
                        message: message
                    )
                }
                
                // 解析標頭
                let headers = CodexUsageHeaders.from(httpResponse: httpResponse)
                
                // 解析 Body
                do {
                    let body = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
                    return (headers, body)
                } catch {
                    let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
                    throw CodexAPIError.decodingFailed(
                        underlyingError: error,
                        rawResponse: rawJSON
                    )
                }
            }
        )
    }
}

// MARK: - 私有輔助工具

/// 從指定路徑載入並解析 Codex 憑證檔案。
///
/// - Parameter url: 憑證檔案的路徑。
/// - Returns: 解析成功的 ``CodexOAuth``，失敗時回傳 `nil`。
private func loadCredentialFile(at url: URL) -> CodexOAuth? {
    guard let fileData = FileManager.default.contents(atPath: url.path),
          let fileText = String(data: fileData, encoding: .utf8),
          let file = CodexCredentialFile.parse(from: fileText),
          let oauth = file.toOAuth() else {
        return nil
    }
    return oauth
}

/// 將更新後的憑證回寫至主要 Codex 憑證檔案。
///
/// 盡力而為：在具有唯讀權限的沙盒應用程式中可能靜默失敗。
///
/// - Parameter oauth: 要回寫的 OAuth 憑證。
private func writeBackCodexCredentials(_ oauth: CodexOAuth) {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let credentialPath = homeDir.appendingPathComponent(CodexConstants.credentialRelativePath)
    
    // 讀取既有檔案以保留其他欄位
    var existingDict: [String: Any] = [:]
    if let fileData = FileManager.default.contents(atPath: credentialPath.path),
       let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
        existingDict = json
    }
    
    // 建構 tokens 子字典
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
    
    // 更新 last_refresh
    if let lastRefresh = oauth.lastRefresh {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        existingDict["last_refresh"] = formatter.string(from: lastRefresh)
    }
    
    // 回寫檔案
    if let data = try? JSONSerialization.data(
        withJSONObject: existingDict,
        options: [.prettyPrinted, .sortedKeys]
    ) {
        try? data.write(to: credentialPath)
    }
}
