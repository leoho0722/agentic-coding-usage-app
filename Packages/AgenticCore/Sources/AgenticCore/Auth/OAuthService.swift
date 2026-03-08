import Foundation

// MARK: - 回應模型

/// `POST /login/device/code` 的回應。
public struct DeviceCodeResponse: Codable, Sendable {
    
    /// 裝置驗證碼。
    public let deviceCode: String
    
    /// 使用者驗證碼，需在瀏覽器中輸入。
    public let userCode: String
    
    /// 驗證頁面的 URL。
    public let verificationUri: String
    
    /// 驗證碼的有效秒數。
    public let expiresIn: Int
    
    /// 輪詢間隔秒數。
    public let interval: Int
    
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
    
    /// 以指定的屬性值初始化。
    ///
    /// - Parameters:
    ///   - deviceCode: 裝置驗證碼。
    ///   - userCode: 使用者驗證碼，需在瀏覽器中輸入。
    ///   - verificationUri: 驗證頁面的 URL。
    ///   - expiresIn: 驗證碼的有效秒數。
    ///   - interval: 輪詢間隔秒數。
    public init(
        deviceCode: String,
        userCode: String,
        verificationUri: String,
        expiresIn: Int,
        interval: Int
    ) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationUri = verificationUri
        self.expiresIn = expiresIn
        self.interval = interval
    }
}

/// OAuth 存取權杖端點的成功回應。
public struct OAuthTokenResponse: Codable, Sendable {
    
    /// 存取權杖。
    public let accessToken: String
    
    /// 權杖類型（例如 `"bearer"`）。
    public let tokenType: String
    
    /// 授權範圍。
    public let scope: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
    
    /// 以指定的屬性值初始化。
    ///
    /// - Parameters:
    ///   - accessToken: 存取權杖。
    ///   - tokenType: 權杖類型（例如 `"bearer"`）。
    ///   - scope: 授權範圍。
    public init(
        accessToken: String,
        tokenType: String,
        scope: String
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
    }
}

/// 裝置流程輪詢期間的錯誤回應。
private struct OAuthErrorResponse: Codable, Sendable {
    
    /// 錯誤代碼。
    let error: String
    
    /// 錯誤描述。
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - 請求模型

/// `POST /login/device/code` 的請求。
private struct DeviceCodeRequest: Encodable, Sendable {
    
    /// OAuth 用戶端識別碼。
    let clientId: String
    
    /// 授權範圍。
    let scope: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case scope
    }
}

/// `POST /login/oauth/access_token` 的輪詢請求。
private struct PollAccessTokenRequest: Encodable, Sendable {
    
    /// OAuth 用戶端識別碼。
    let clientId: String
    
    /// 裝置驗證碼。
    let deviceCode: String
    
    /// OAuth 授權類型。
    let grantType: String
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case deviceCode = "device_code"
        case grantType = "grant_type"
    }
}

// MARK: - 錯誤

/// OAuth 流程錯誤。
public enum OAuthError: LocalizedError, Sendable {
    
    /// 請求失敗，附帶錯誤訊息。
    case requestFailed(String)
    
    /// 裝置驗證碼已過期。
    case expired
    
    /// 使用者拒絕授權。
    case accessDenied
    
    /// 無效的回應。
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case let .requestFailed(msg): "OAuth request failed: \(msg)"
        case .expired: "Device code expired. Please try again."
        case .accessDenied: "Access denied by user."
        case .invalidResponse: "Invalid OAuth response."
        }
    }
}

// MARK: - OAuth 服務

/// 可依賴注入的 OAuth 裝置流程服務。
///
/// 透過閉包注入，讓 TCA 與 CLI 可各自提供不同的實作（正式版、模擬版等）。
public struct OAuthService: Sendable {
    
    /// 請求裝置驗證碼以啟動登入流程。
    public var requestDeviceCode: @Sendable (_ clientID: String) async throws -> DeviceCodeResponse
    
    /// 輪詢存取權杖。持續等待直到授權完成、過期或被拒絕。
    public var pollForAccessToken: @Sendable (
        _ clientID: String, _ deviceCode: String, _ interval: Int
    ) async throws -> OAuthTokenResponse
    
    /// 以指定的閉包建立實例。
    ///
    /// - Parameters:
    ///   - requestDeviceCode: 請求裝置驗證碼以啟動登入流程。
    ///   - pollForAccessToken: 輪詢存取權杖。持續等待直到授權完成、過期或被拒絕。
    public init(
        requestDeviceCode: @escaping @Sendable (_ clientID: String) async throws ->
        DeviceCodeResponse,
        pollForAccessToken: @escaping @Sendable (
            _ clientID: String, _ deviceCode: String, _ interval: Int
        ) async throws -> OAuthTokenResponse
    ) {
        self.requestDeviceCode = requestDeviceCode
        self.pollForAccessToken = pollForAccessToken
    }
}

// MARK: - 正式版實作

extension OAuthService {
    
    /// 使用 `URLSession` 的正式版實作。
    public static let live = OAuthService(
        requestDeviceCode: { clientID in
            let request = try RequestBuilder(url: GitHubEndpoint.deviceCode(clientID: clientID).url)
                .method(.post)
                .header("Accept", "application/json")
                .jsonBody(DeviceCodeRequest(clientId: clientID, scope: "user"))
                .build()
            
            do {
                return try await HTTPClient().fetch(
                    request,
                    responseType: DeviceCodeResponse.self
                )
            } catch let error as HTTPClientError {
                throw OAuthError.requestFailed(error.localizedDescription)
            }
        },
        pollForAccessToken: { clientID, deviceCode, interval in
            var pollInterval = interval
            
            while true {
                try await Task.sleep(for: .seconds(pollInterval))
                
                let request = try RequestBuilder(
                    url: GitHubEndpoint.pollAccessToken(clientID: clientID, deviceCode: deviceCode).url
                )
                    .method(.post)
                    .header("Accept", "application/json")
                    .jsonBody(PollAccessTokenRequest(
                        clientId: clientID,
                        deviceCode: deviceCode,
                        grantType: "urn:ietf:params:oauth:grant-type:device_code"
                    ))
                    .build()
                let (_, data) = try await HTTPClient().fetchRaw(request) { _, responseData in
                    // OAuth 輪詢：所有回應都需要自行解析，跳過預設 2xx 驗證
                    return responseData
                }
                
                // 先嘗試解碼為成功的權杖回應
                if let token = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data) {
                    return token
                }
                
                // 否則檢查錯誤回應
                if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                    switch errorResponse.error {
                    case "authorization_pending":
                        continue
                    case "slow_down":
                        pollInterval += 5
                        continue
                    case "expired_token":
                        throw OAuthError.expired
                    case "access_denied":
                        throw OAuthError.accessDenied
                    default:
                        throw OAuthError.requestFailed(
                            errorResponse.errorDescription ?? errorResponse.error)
                    }
                }
                
                throw OAuthError.invalidResponse
            }
        }
    )
}
