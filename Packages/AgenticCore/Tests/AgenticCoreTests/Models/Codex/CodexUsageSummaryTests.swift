import Foundation
import Testing

@testable import AgenticCore

@Suite("CodexUsageSummary")
struct CodexUsageSummaryTests {

    // MARK: - Header priority over body

    /// 驗證 session 使用率以 header 值優先於 body 值
    @Test
    func headerPriority_session() {
        let headers = CodexUsageHeaders(primaryUsedPercent: 80.0)
        let response = CodexUsageResponse(
            rateLimit: CodexRateLimit(
                primaryWindow: CodexUsageWindow(usedPercent: 50.0)
            )
        )
        let summary = CodexUsageSummary(headers: headers, response: response)
        // Header 值（80）應覆蓋 body 值（50）
        #expect(summary.sessionUsedPercent == 80)
    }

    /// 驗證 weekly 使用率以 header 值優先於 body 值
    @Test
    func headerPriority_weekly() {
        let headers = CodexUsageHeaders(secondaryUsedPercent: 30.0)
        let response = CodexUsageResponse(
            rateLimit: CodexRateLimit(
                secondaryWindow: CodexUsageWindow(usedPercent: 10.0)
            )
        )
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.weeklyUsedPercent == 30)
    }

    /// 驗證 credits 餘額以 header 值優先於 body 值
    @Test
    func headerPriority_credits() {
        let headers = CodexUsageHeaders(creditsBalance: 42.5)
        let response = CodexUsageResponse(credits: CodexCredits(balance: 10.0))
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.creditsBalance == 42.5)
    }

    /// 驗證 header 值為 nil 時正確回退使用 body 值
    @Test
    func bodyFallback_whenHeadersNil() {
        let headers = CodexUsageHeaders()
        let response = CodexUsageResponse(
            rateLimit: CodexRateLimit(
                primaryWindow: CodexUsageWindow(usedPercent: 55.0, resetAt: 1700000000),
                secondaryWindow: CodexUsageWindow(usedPercent: 20.0, resetAt: 1700100000)
            ),
            credits: CodexCredits(balance: 99.9),
            planType: "plus"
        )
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.sessionUsedPercent == 55)
        #expect(summary.weeklyUsedPercent == 20)
        #expect(summary.creditsBalance == 99.9)
        #expect(summary.plan == .plus)
    }

    // MARK: - Reset dates

    /// 驗證從 Unix 時間戳正確轉換為重置日期
    @Test
    func resetDates_fromUnixTimestamp() {
        let headers = CodexUsageHeaders()
        let response = CodexUsageResponse(
            rateLimit: CodexRateLimit(
                primaryWindow: CodexUsageWindow(resetAt: 1700000000)
            )
        )
        let summary = CodexUsageSummary(headers: headers, response: response)
        let expected = Date(timeIntervalSince1970: 1700000000)
        #expect(summary.sessionResetAt == expected)
    }

    // MARK: - Additional limits

    /// 驗證額外速率限制的解析與顯示名稱擷取正確
    @Test
    func additionalLimits() {
        let headers = CodexUsageHeaders()
        let response = CodexUsageResponse(
            additionalRateLimits: [
                CodexAdditionalRateLimit(
                    limitName: "o1-pro rate limit",
                    rateLimit: CodexRateLimit(
                        primaryWindow: CodexUsageWindow(usedPercent: 70.0)
                    )
                )
            ]
        )
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.hasAdditionalLimits == true)
        #expect(summary.additionalLimits.count == 1)
        #expect(summary.additionalLimits.first?.name == "o1-pro rate limit")
        #expect(summary.additionalLimits.first?.shortDisplayName == "o1-pro")
        #expect(summary.additionalLimits.first?.sessionUsedPercent == 70)
    }

    // MARK: - Code review

    /// 驗證 code review 速率限制的解析正確
    @Test
    func codeReview() {
        let headers = CodexUsageHeaders()
        let response = CodexUsageResponse(
            codeReviewRateLimit: CodexCodeReviewRateLimit(
                primaryWindow: CodexUsageWindow(usedPercent: 45.0)
            )
        )
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.hasCodeReview == true)
        #expect(summary.codeReviewUsedPercent == 45)
    }

    // MARK: - Computed properties

    /// 驗證有 credits 餘額時 hasCredits 回傳 true
    @Test
    func hasCredits_true() {
        let headers = CodexUsageHeaders(creditsBalance: 1.0)
        let response = CodexUsageResponse()
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.hasCredits == true)
    }

    /// 驗證無 credits 餘額時 hasCredits 回傳 false
    @Test
    func hasCredits_false() {
        let headers = CodexUsageHeaders()
        let response = CodexUsageResponse()
        let summary = CodexUsageSummary(headers: headers, response: response)
        #expect(summary.hasCredits == false)
    }

    // MARK: - Date.countdownString

    /// 驗證過去時間的 countdownString 回傳 "now"
    @Test
    func countdownString_past_returnsNow() {
        let past = Date().addingTimeInterval(-60)
        #expect(past.countdownString == "now")
    }

    /// 驗證倒數時間含小時與分鐘時回傳非 nil 且包含數字
    @Test
    func countdownString_hours() {
        // 多加 30 秒緩衝，避免因毫秒誤差導致分鐘少 1
        let future = Date().addingTimeInterval(2 * 3600 + 30 * 60 + 30)
        let result = future.countdownString
        #expect(result != nil)
        // DateComponentsFormatter 依語系格式不同，驗證包含 "2" 與 "30"
        #expect(result!.contains("2"))
        #expect(result!.contains("30"))
    }

    /// 驗證倒數時間含天數與小時時回傳非 nil 且包含數字
    @Test
    func countdownString_days() {
        let future = Date().addingTimeInterval(3 * 24 * 3600 + 5 * 3600 + 30)
        let result = future.countdownString
        #expect(result != nil)
        #expect(result!.contains("3"))
        #expect(result!.contains("5"))
    }

    /// 驗證倒數時間僅有分鐘時回傳非 nil 且包含數字
    @Test
    func countdownString_minutesOnly() {
        // 多加 30 秒緩衝，避免因毫秒誤差導致分鐘少 1
        let future = Date().addingTimeInterval(45 * 60 + 30)
        let result = future.countdownString
        #expect(result != nil)
        #expect(result!.contains("45"))
    }
}
