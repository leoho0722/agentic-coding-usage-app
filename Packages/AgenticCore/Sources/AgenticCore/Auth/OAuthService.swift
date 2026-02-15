import Foundation

// MARK: - Response Models

/// Response from `POST /login/device/code`.
public struct DeviceCodeResponse: Codable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationUri: String
    public let expiresIn: Int
    public let interval: Int

    public init(deviceCode: String, userCode: String, verificationUri: String, expiresIn: Int, interval: Int) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationUri = verificationUri
        self.expiresIn = expiresIn
        self.interval = interval
    }

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

/// Successful token response from the OAuth access token endpoint.
public struct OAuthTokenResponse: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String

    public init(accessToken: String, tokenType: String, scope: String) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

/// Error response during device flow polling.
private struct OAuthErrorResponse: Codable, Sendable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Errors

public enum OAuthError: LocalizedError, Sendable {
    case requestFailed(String)
    case expired
    case accessDenied
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

// MARK: - OAuthService

/// A dependency-injectable OAuth device flow service.
public struct OAuthService: Sendable {
    /// Request a device code to begin the login flow.
    public var requestDeviceCode: @Sendable (_ clientID: String) async throws -> DeviceCodeResponse
    /// Poll for the access token. Blocks until authorized, expired, or denied.
    public var pollForAccessToken: @Sendable (
        _ clientID: String, _ deviceCode: String, _ interval: Int
    ) async throws -> OAuthTokenResponse

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

// MARK: - Live Implementation

extension OAuthService {
    public static let live = OAuthService(
        requestDeviceCode: { clientID in
            let request = GitHubEndpoint.deviceCode(clientID: clientID).makeRequest()
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                (200 ... 299).contains(httpResponse.statusCode)
            else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OAuthError.requestFailed(msg)
            }

            return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        },
        pollForAccessToken: { clientID, deviceCode, interval in
            var pollInterval = interval

            while true {
                try await Task.sleep(for: .seconds(pollInterval))

                let request = GitHubEndpoint
                    .pollAccessToken(clientID: clientID, deviceCode: deviceCode)
                    .makeRequest()
                let (data, _) = try await URLSession.shared.data(for: request)

                // Try to decode as a successful token response first
                if let token = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data) {
                    return token
                }

                // Otherwise check for error
                if let errorResponse = try? JSONDecoder().decode(
                    OAuthErrorResponse.self, from: data)
                {
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
