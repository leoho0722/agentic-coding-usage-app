import Foundation
import Testing

@testable import AgenticCore

@Suite("CodableModels")
struct CodableModelTests {

    // MARK: - CopilotStatusResponse round-trip

    /// 驗證 CopilotStatusResponse 的 JSON 編碼與解碼往返一致性
    @Test
    func copilotStatusResponse_roundTrip() throws {
        let original = CopilotStatusResponse(
            copilotPlan: "copilot_for_individual_user",
            quotaSnapshots: QuotaSnapshots(
                premiumInteractions: QuotaSnapshot(percentRemaining: 80.0),
                chat: QuotaSnapshot(percentRemaining: 90.0)
            ),
            limitedUserQuotas: LimitedQuotas(chat: 30, completions: 1500),
            monthlyQuotas: MonthlyQuotas(chat: 50, completions: 2000)
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(CopilotStatusResponse.self, from: data)
        #expect(decoded == original)
    }

    /// 驗證 CopilotStatusResponse 能正確解碼 snake_case 格式的 JSON
    @Test
    func copilotStatusResponse_snakeCaseDecoding() throws {
        let json = """
            {
                "copilot_plan": "copilot_free",
                "quota_snapshots": {
                    "premium_interactions": {"percent_remaining": 50.0}
                },
                "limited_user_quotas": {"chat": 10},
                "monthly_quotas": {"chat": 50}
            }
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CopilotStatusResponse.self, from: data)
        #expect(decoded.copilotPlan == "copilot_free")
        #expect(decoded.quotaSnapshots?.premiumInteractions?.percentRemaining == 50.0)
        #expect(decoded.limitedUserQuotas?.chat == 10)
        #expect(decoded.monthlyQuotas?.chat == 50)
    }

    // MARK: - ClaudeUsageResponse round-trip

    /// 驗證 ClaudeUsageResponse 的 JSON 編碼與解碼往返一致性
    @Test
    func claudeUsageResponse_roundTrip() throws {
        let original = ClaudeUsageResponse(
            fiveHour: ClaudeUsagePeriod(utilization: 25.0, resetsAt: "2025-03-08T12:00:00Z"),
            sevenDay: ClaudeUsagePeriod(utilization: 40.0, resetsAt: nil),
            sevenDayOpus: nil,
            extraUsage: ClaudeExtraUsage(isEnabled: true, usedCredits: 100, monthlyLimit: 5000, currency: "USD")
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        #expect(decoded == original)
    }

    /// 驗證 ClaudeUsageResponse 能正確解碼 snake_case 格式的 JSON
    @Test
    func claudeUsageResponse_snakeCaseDecoding() throws {
        let json = """
            {
                "five_hour": {"utilization": 30.0, "resets_at": "2025-03-08T12:00:00Z"},
                "seven_day": {"utilization": 50.0},
                "extra_usage": {"is_enabled": true, "used_credits": 200, "monthly_limit": 10000, "currency": "USD"}
            }
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        #expect(decoded.fiveHour?.utilization == 30.0)
        #expect(decoded.sevenDay?.utilization == 50.0)
        #expect(decoded.extraUsage?.isEnabled == true)
    }

    // MARK: - CodexUsageResponse round-trip

    /// 驗證 CodexUsageResponse 的 JSON 編碼與解碼往返一致性
    @Test
    func codexUsageResponse_roundTrip() throws {
        let original = CodexUsageResponse(
            rateLimit: CodexRateLimit(
                primaryWindow: CodexUsageWindow(usedPercent: 30.0, resetAt: 1700000000),
                secondaryWindow: CodexUsageWindow(usedPercent: 10.0)
            ),
            additionalRateLimits: [
                CodexAdditionalRateLimit(limitName: "o1-pro rate limit")
            ],
            credits: CodexCredits(balance: 42.5),
            planType: "plus"
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - GitHubUser round-trip

    /// 驗證 GitHubUser 的 JSON 編碼與解碼往返一致性
    @Test
    func githubUser_roundTrip() throws {
        let original = GitHubUser(login: "testuser", name: "Test User")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GitHubUser.self, from: data)
        #expect(decoded == original)
    }

    /// 驗證 GitHubUser 在 name 為 null 時能正確解碼
    @Test
    func githubUser_nullName() throws {
        let json = """
            {"login": "testuser"}
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GitHubUser.self, from: data)
        #expect(decoded.login == "testuser")
        #expect(decoded.name == nil)
    }

    // MARK: - AntigravityUsageResponse

    /// 驗證 AntigravityUsageResponse 能正確解碼包含模型配額資訊的 JSON
    @Test
    func antigravityUsageResponse_decoding() throws {
        let json = """
            {
                "models": {
                    "model_1": {
                        "model": "gemini-3-pro",
                        "displayName": "Gemini 3 Pro",
                        "isInternal": false,
                        "quotaInfo": {"remainingFraction": 0.75, "resetTime": "2025-03-08T12:00:00Z"}
                    }
                }
            }
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AntigravityUsageResponse.self, from: data)
        #expect(decoded.models?.count == 1)
        #expect(decoded.models?["model_1"]?.displayName == "Gemini 3 Pro")
        #expect(decoded.models?["model_1"]?.quotaInfo?.remainingFraction == 0.75)
    }
}
