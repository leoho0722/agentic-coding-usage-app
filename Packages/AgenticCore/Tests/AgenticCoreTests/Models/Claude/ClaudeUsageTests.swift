import Foundation
import Testing

@testable import AgenticCore

@Suite("ClaudeUsage")
struct ClaudeUsageTests {

    // MARK: - ClaudeUsageSummary init

    /// 驗證 ClaudeUsageSummary 能正確從 response 中擷取各項使用率與重置時間
    @Test
    func summary_extractsUtilization() {
        let response = ClaudeUsageResponse(
            fiveHour: ClaudeUsagePeriod(utilization: 25.7, resetsAt: "2025-03-08T12:00:00Z"),
            sevenDay: ClaudeUsagePeriod(utilization: 40.3, resetsAt: "2025-03-10T00:00:00Z"),
            sevenDayOpus: ClaudeUsagePeriod(utilization: 10.0, resetsAt: nil)
        )
        let summary = ClaudeUsageSummary(plan: .pro, response: response)

        #expect(summary.sessionUtilization == 25)
        #expect(summary.weeklyUtilization == 40)
        #expect(summary.opusUtilization == 10)
        #expect(summary.sessionResetsAt == "2025-03-08T12:00:00Z")
        #expect(summary.weeklyResetsAt == "2025-03-10T00:00:00Z")
    }

    /// 驗證所有 period 為 nil 時各使用率與方案皆為 nil
    @Test
    func summary_nilPeriods() {
        let response = ClaudeUsageResponse()
        let summary = ClaudeUsageSummary(plan: nil, response: response)

        #expect(summary.sessionUtilization == nil)
        #expect(summary.weeklyUtilization == nil)
        #expect(summary.opusUtilization == nil)
        #expect(summary.plan == nil)
    }

    /// 驗證 hasOpus 在有 Opus 使用率時回傳 true，無則回傳 false
    @Test
    func summary_hasOpus() {
        let withOpus = ClaudeUsageSummary(
            plan: .max,
            response: ClaudeUsageResponse(
                sevenDayOpus: ClaudeUsagePeriod(utilization: 5.0, resetsAt: nil)
            )
        )
        #expect(withOpus.hasOpus == true)

        let withoutOpus = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse()
        )
        #expect(withoutOpus.hasOpus == false)
    }

    // MARK: - Extra usage

    /// 驗證有額外用量時能正確計算美元金額與上限
    @Test
    func summary_extraUsage() {
        let response = ClaudeUsageResponse(
            extraUsage: ClaudeExtraUsage(
                isEnabled: true,
                usedCredits: 500,
                monthlyLimit: 10000,
                currency: "USD"
            )
        )
        let summary = ClaudeUsageSummary(plan: .max, response: response)

        #expect(summary.hasExtraUsage == true)
        #expect(summary.extraUsageUsedDollars == 5.0)
        #expect(summary.extraUsageLimitDollars == 100.0)
        #expect(summary.extraUsageCurrency == "USD")
    }

    /// 驗證無額外用量時 hasExtraUsage 為 false 且金額為 nil
    @Test
    func summary_noExtraUsage() {
        let response = ClaudeUsageResponse()
        let summary = ClaudeUsageSummary(plan: .pro, response: response)

        #expect(summary.hasExtraUsage == false)
        #expect(summary.extraUsageUsedDollars == nil)
        #expect(summary.extraUsageLimitDollars == nil)
    }

    /// 驗證額外用量的 usedCredits 與 monthlyLimit 為 nil 時美元金額回傳 nil
    @Test
    func extraUsageDollars_nilCents_returnsNil() {
        let response = ClaudeUsageResponse(
            extraUsage: ClaudeExtraUsage(isEnabled: true, usedCredits: nil, monthlyLimit: nil)
        )
        let summary = ClaudeUsageSummary(plan: .max, response: response)
        #expect(summary.extraUsageUsedDollars == nil)
        #expect(summary.extraUsageLimitDollars == nil)
    }

    // MARK: - ClaudeUsagePeriod.utilizationPercent

    /// 驗證 utilizationPercent 使用截斷（非四捨五入）將浮點數轉為整數
    @Test
    func utilizationPercent_truncates() {
        let period = ClaudeUsagePeriod(utilization: 78.9, resetsAt: nil)
        #expect(period.utilizationPercent == 78) // Int() 截斷而非四捨五入
    }

    /// 驗證使用率小於 1 時 utilizationPercent 截斷為 0
    @Test
    func utilizationPercent_zeroPoint() {
        let period = ClaudeUsagePeriod(utilization: 0.5, resetsAt: nil)
        #expect(period.utilizationPercent == 0)
    }

    // MARK: - ClaudeUsagePeriod.resetsAtDate

    /// 驗證標準 ISO 8601 格式字串能正確解析為 Date
    @Test
    func resetsAtDate_iso8601() {
        let period = ClaudeUsagePeriod(
            utilization: 50.0,
            resetsAt: "2025-03-08T12:00:00Z"
        )
        #expect(period.resetsAtDate != nil)
    }

    /// 驗證含有毫秒的 ISO 8601 格式字串能正確解析為 Date
    @Test
    func resetsAtDate_withFractionalSeconds() {
        let period = ClaudeUsagePeriod(
            utilization: 50.0,
            resetsAt: "2025-03-08T12:00:00.123Z"
        )
        #expect(period.resetsAtDate != nil)
    }

    /// 驗證 resetsAt 為 nil 時 resetsAtDate 回傳 nil
    @Test
    func resetsAtDate_nil_returnsNil() {
        let period = ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
        #expect(period.resetsAtDate == nil)
    }

    /// 驗證無效日期字串時 resetsAtDate 回傳 nil
    @Test
    func resetsAtDate_invalidString_returnsNil() {
        let period = ClaudeUsagePeriod(utilization: 50.0, resetsAt: "not a date")
        #expect(period.resetsAtDate == nil)
    }

    // MARK: - ClaudeExtraUsage custom Decodable

    /// 驗證 JSON 缺少 is_enabled 欄位時預設為 true
    @Test
    func extraUsage_missingIsEnabled_defaultsTrue() throws {
        let json = """
            {"used_credits": 100, "monthly_limit": 5000, "currency": "USD"}
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ClaudeExtraUsage.self, from: data)
        #expect(decoded.isEnabled == true)
        #expect(decoded.usedCredits == 100)
    }

    /// 驗證 JSON 明確提供 is_enabled 為 false 時能正確解碼
    @Test
    func extraUsage_explicitIsEnabled() throws {
        let json = """
            {"is_enabled": false}
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ClaudeExtraUsage.self, from: data)
        #expect(decoded.isEnabled == false)
    }
}
