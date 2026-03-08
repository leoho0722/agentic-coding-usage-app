import Foundation
import Testing

@testable import AgenticCore

@Suite("CopilotUsageSummary")
struct CopilotUsageSummaryTests {

    // MARK: - isFreeTier

    /// 驗證 free 方案的 isFreeTier 回傳 true
    @Test
    func isFreeTier_free_returnsTrue() {
        let summary = CopilotUsageSummary(plan: .free, planLimit: 50, daysUntilReset: 10)
        #expect(summary.isFreeTier == true)
    }

    /// 驗證 pro 方案的 isFreeTier 回傳 false
    @Test
    func isFreeTier_pro_returnsFalse() {
        let summary = CopilotUsageSummary(plan: .pro, planLimit: 300, daysUntilReset: 10)
        #expect(summary.isFreeTier == false)
    }

    /// 驗證 proPlus 方案的 isFreeTier 回傳 false
    @Test
    func isFreeTier_proPlus_returnsFalse() {
        let summary = CopilotUsageSummary(plan: .proPlus, planLimit: 1500, daysUntilReset: 10)
        #expect(summary.isFreeTier == false)
    }

    // MARK: - usagePercentage (paid plan)

    /// 驗證付費方案在剩餘 100% 時使用百分比為 0.0
    @Test
    func usagePercentage_paid_fullRemaining() {
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: 100.0
        )
        #expect(summary.usagePercentage == 0.0)
    }

    /// 驗證付費方案在剩餘 50% 時使用百分比為 0.5
    @Test
    func usagePercentage_paid_halfUsed() {
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: 50.0
        )
        #expect(summary.usagePercentage == 0.5)
    }

    /// 驗證付費方案在剩餘 0% 時使用百分比為 1.0
    @Test
    func usagePercentage_paid_allUsed() {
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: 0.0
        )
        #expect(summary.usagePercentage == 1.0)
    }

    /// 驗證付費方案剩餘百分比超過 100 時會被箝位至 0.0
    @Test
    func usagePercentage_paid_clampedAbove100() {
        // 邊界值：premiumPercentRemaining > 100 應箝位至 0.0
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: 120.0
        )
        #expect(summary.usagePercentage == 0.0)
    }

    /// 驗證付費方案剩餘百分比低於 0 時會被箝位至 1.0
    @Test
    func usagePercentage_paid_clampedBelowZero() {
        // 邊界值：premiumPercentRemaining < 0 應箝位至 1.0
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: -10.0
        )
        #expect(summary.usagePercentage == 1.0)
    }

    // MARK: - usagePercentage (free plan)

    /// 驗證免費方案使用一半時使用百分比為 0.5
    @Test
    func usagePercentage_free_halfUsed() {
        let summary = CopilotUsageSummary(
            plan: .free, planLimit: 50, daysUntilReset: 10,
            freeChatRemaining: 25, freeChatTotal: 50
        )
        #expect(summary.usagePercentage == 0.5)
    }

    /// 驗證免費方案全部用完時使用百分比為 1.0
    @Test
    func usagePercentage_free_allUsed() {
        let summary = CopilotUsageSummary(
            plan: .free, planLimit: 50, daysUntilReset: 10,
            freeChatRemaining: 0, freeChatTotal: 50
        )
        #expect(summary.usagePercentage == 1.0)
    }

    /// 驗證免費方案完全未使用時使用百分比為 0.0
    @Test
    func usagePercentage_free_noneUsed() {
        let summary = CopilotUsageSummary(
            plan: .free, planLimit: 50, daysUntilReset: 10,
            freeChatRemaining: 50, freeChatTotal: 50
        )
        #expect(summary.usagePercentage == 0.0)
    }

    /// 驗證缺少使用資料時使用百分比預設為 0.0
    @Test
    func usagePercentage_noData_returnsZero() {
        let summary = CopilotUsageSummary(plan: .pro, planLimit: 300, daysUntilReset: 10)
        #expect(summary.usagePercentage == 0.0)
    }

    // MARK: - premiumRequestsUsed

    /// 驗證已使用一半時 premiumRequestsUsed 回傳正確的請求數
    @Test
    func premiumRequestsUsed_halfUsed() {
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: 50.0
        )
        #expect(summary.premiumRequestsUsed == 150)
    }

    /// 驗證缺少使用資料時 premiumRequestsUsed 回傳 0
    @Test
    func premiumRequestsUsed_noData_returnsZero() {
        let summary = CopilotUsageSummary(plan: .pro, planLimit: 300, daysUntilReset: 10)
        #expect(summary.premiumRequestsUsed == 0)
    }

    // MARK: - remaining

    /// 驗證付費方案剩餘一半時 remaining 回傳正確數值
    @Test
    func remaining_paid_halfLeft() {
        let summary = CopilotUsageSummary(
            plan: .pro, planLimit: 300, daysUntilReset: 10,
            premiumPercentRemaining: 50.0
        )
        #expect(summary.remaining == 150)
    }

    /// 驗證免費方案的 remaining 使用 freeChatRemaining 值
    @Test
    func remaining_free_usesChat() {
        let summary = CopilotUsageSummary(
            plan: .free, planLimit: 50, daysUntilReset: 10,
            freeChatRemaining: 30
        )
        #expect(summary.remaining == 30)
    }

    /// 驗證缺少使用資料時 remaining 回傳 planLimit
    @Test
    func remaining_noData_returnsPlanLimit() {
        let summary = CopilotUsageSummary(plan: .pro, planLimit: 300, daysUntilReset: 10)
        #expect(summary.remaining == 300)
    }
}
