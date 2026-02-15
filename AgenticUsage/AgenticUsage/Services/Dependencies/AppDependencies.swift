import AgenticCore
import Dependencies

// MARK: - GitHubAPIClient Dependency

extension GitHubAPIClient: @retroactive TestDependencyKey {
    public static let testValue = GitHubAPIClient(
        fetchUser: { _ in
            GitHubUser(login: "testuser", name: "Test User")
        },
        fetchCopilotStatus: { _ in
            CopilotStatusResponse(
                copilotPlan: "copilot_for_individual_user",
                quotaSnapshots: QuotaSnapshots(
                    premiumInteractions: QuotaSnapshot(percentRemaining: 80.0),
                    chat: QuotaSnapshot(percentRemaining: 90.0)
                )
            )
        }
    )
}

extension DependencyValues {
    public var gitHubAPIClient: GitHubAPIClient {
        get { self[GitHubAPIClient.self] }
        set { self[GitHubAPIClient.self] = newValue }
    }
}

// MARK: - OAuthService Dependency

extension OAuthService: @retroactive TestDependencyKey {
    public static let testValue = OAuthService(
        requestDeviceCode: { _ in
            DeviceCodeResponse(
                deviceCode: "test-device-code",
                userCode: "TEST-1234",
                verificationUri: "https://github.com/login/device",
                expiresIn: 900,
                interval: 5
            )
        },
        pollForAccessToken: { _, _, _ in
            OAuthTokenResponse(accessToken: "test-token", tokenType: "bearer", scope: "user")
        }
    )
}

extension DependencyValues {
    public var oAuthService: OAuthService {
        get { self[OAuthService.self] }
        set { self[OAuthService.self] = newValue }
    }
}

// MARK: - KeychainService Dependency

extension KeychainService: @retroactive TestDependencyKey {
    public static let testValue = KeychainService(
        save: { _, _ in },
        load: { _ in nil },
        delete: { _ in }
    )
}

extension DependencyValues {
    public var keychainService: KeychainService {
        get { self[KeychainService.self] }
        set { self[KeychainService.self] = newValue }
    }
}
