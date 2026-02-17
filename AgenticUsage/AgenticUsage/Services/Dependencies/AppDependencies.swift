import Foundation

import AgenticCore
import Dependencies

// MARK: - GitHubAPIClient 相依性

/// 將 `GitHubAPIClient` 註冊為 TCA 測試相依性，提供模擬的使用者與 Copilot 狀態回應。
extension GitHubAPIClient: @retroactive TestDependencyKey {
    
    /// 測試用的模擬實作
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
    
    /// GitHub API 客戶端相依性
    public var gitHubAPIClient: GitHubAPIClient {
        get { self[GitHubAPIClient.self] }
        set { self[GitHubAPIClient.self] = newValue }
    }
}

// MARK: - OAuthService 相依性

/// 將 `OAuthService` 註冊為 TCA 測試相依性，提供模擬的 Device Flow 回應。
extension OAuthService: @retroactive TestDependencyKey {
    
    /// 測試用的模擬實作
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
    
    /// OAuth 認證服務相依性
    public var oAuthService: OAuthService {
        get { self[OAuthService.self] }
        set { self[OAuthService.self] = newValue }
    }
}

// MARK: - KeychainService 相依性

/// 將 `KeychainService` 註冊為 TCA 測試相依性，提供不做任何操作的模擬實作。
extension KeychainService: @retroactive TestDependencyKey {
    
    /// 測試用的模擬實作
    public static let testValue = KeychainService(
        save: { _, _ in },
        load: { _ in nil },
        delete: { _ in }
    )
}

extension DependencyValues {
    
    /// 鑰匙圈服務相依性
    public var keychainService: KeychainService {
        get { self[KeychainService.self] }
        set { self[KeychainService.self] = newValue }
    }
}

// MARK: - ClaudeAPIClient 相依性

/// 將 `ClaudeAPIClient` 註冊為 TCA 測試相依性，提供模擬的用量回應。
extension ClaudeAPIClient: @retroactive TestDependencyKey {
    
    /// 測試用的模擬實作
    public static let testValue = ClaudeAPIClient(
        loadCredentials: { nil },
        refreshTokenIfNeeded: { current in current },
        fetchUsage: { _ in
            ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 25, resetsAt: "2026-02-16T20:00:00Z"),
                sevenDay: ClaudeUsagePeriod(utilization: 40, resetsAt: "2026-02-20T00:00:00Z"),
                sevenDayOpus: nil,
                extraUsage: nil
            )
        }
    )
}

extension DependencyValues {
    
    /// Claude API 客戶端相依性
    public var claudeAPIClient: ClaudeAPIClient {
        get { self[ClaudeAPIClient.self] }
        set { self[ClaudeAPIClient.self] = newValue }
    }
}

// MARK: - CodexAPIClient 相依性

/// 將 `CodexAPIClient` 註冊為 TCA 測試相依性，提供模擬的用量回應。
extension CodexAPIClient: @retroactive TestDependencyKey {
    
    /// 測試用的模擬實作
    public static let testValue = CodexAPIClient(
        loadCredentials: { nil },
        refreshTokenIfNeeded: { current in current },
        fetchUsage: { _, _ in
            let headers = CodexUsageHeaders(
                primaryUsedPercent: 30,
                secondaryUsedPercent: 20,
                creditsBalance: 950
            )
            let response = CodexUsageResponse(
                rateLimit: CodexRateLimit(
                    primaryWindow: CodexUsageWindow(
                        usedPercent: 30,
                        resetAt: Date().timeIntervalSince1970 + 18000
                    ),
                    secondaryWindow: CodexUsageWindow(
                        usedPercent: 20,
                        resetAt: Date().timeIntervalSince1970 + 604800
                    )
                ),
                planType: "plus"
            )
            return (headers, response)
        }
    )
}

extension DependencyValues {
    
    /// Codex API 客戶端相依性
    public var codexAPIClient: CodexAPIClient {
        get { self[CodexAPIClient.self] }
        set { self[CodexAPIClient.self] = newValue }
    }
}
