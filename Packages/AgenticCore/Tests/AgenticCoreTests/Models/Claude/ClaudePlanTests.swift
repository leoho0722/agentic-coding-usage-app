import Testing

@testable import AgenticCore

@Suite("ClaudePlan")
struct ClaudePlanTests {

    // MARK: - init(from:)

    /// 驗證 "free" 字串正確解析為 .free
    @Test
    func initFrom_free() {
        #expect(ClaudePlan(from: "free") == .free)
    }

    /// 驗證 "pro" 字串正確解析為 .pro
    @Test
    func initFrom_pro() {
        #expect(ClaudePlan(from: "pro") == .pro)
    }

    /// 驗證 "max" 字串正確解析為 .max
    @Test
    func initFrom_max() {
        #expect(ClaudePlan(from: "max") == .max)
    }

/// 驗證傳入 nil 時回傳 nil
    @Test
    func initFrom_nil_returnsNil() {
        #expect(ClaudePlan(from: nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func initFrom_empty_returnsNil() {
        #expect(ClaudePlan(from: "") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func initFrom_unknown_returnsNil() {
        #expect(ClaudePlan(from: "enterprise") == nil)
        #expect(ClaudePlan(from: "pro_plus") == nil)
        #expect(ClaudePlan(from: "unknown") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func initFrom_caseInsensitive() {
        #expect(ClaudePlan(from: "FREE") == .free)
        #expect(ClaudePlan(from: "Pro") == .pro)
        #expect(ClaudePlan(from: "MAX") == .max)
    }

    // MARK: - rateLimitTier 細分 Max 方案

    /// 驗證 rateLimitTier 包含 "max_5x" 時解析為 .max5x
    @Test
    func initFrom_max_withTier5x() {
        #expect(ClaudePlan(from: "max", rateLimitTier: "default_claude_max_5x") == .max5x)
    }

    /// 驗證 rateLimitTier 包含 "max_20x" 時解析為 .max20x
    @Test
    func initFrom_max_withTier20x() {
        #expect(ClaudePlan(from: "max", rateLimitTier: "default_claude_max_20x") == .max20x)
    }

    /// 驗證無 rateLimitTier 時 max 仍為 .max
    @Test
    func initFrom_max_withoutTier() {
        #expect(ClaudePlan(from: "max", rateLimitTier: nil) == .max)
    }

    /// 驗證未知 rateLimitTier 時 max 仍為 .max
    @Test
    func initFrom_max_withUnknownTier() {
        #expect(ClaudePlan(from: "max", rateLimitTier: "some_other_tier") == .max)
    }

    // MARK: - isMax

    /// 驗證 isMax 屬性正確涵蓋所有 Max 系列方案
    @Test
    func isMax_coversAllMaxVariants() {
        #expect(ClaudePlan.max.isMax == true)
        #expect(ClaudePlan.max5x.isMax == true)
        #expect(ClaudePlan.max20x.isMax == true)
        #expect(ClaudePlan.pro.isMax == false)
        #expect(ClaudePlan.free.isMax == false)
    }

    // MARK: - badgeLabel

    /// 驗證各方案的 badgeLabel 與預期的顯示文字一致
    @Test
    func badgeLabel_matchesRawValue() {
        #expect(ClaudePlan.free.badgeLabel == "Free")
        #expect(ClaudePlan.pro.badgeLabel == "Pro")
        #expect(ClaudePlan.max.badgeLabel == "Max")
        #expect(ClaudePlan.max5x.badgeLabel == "Max 5x")
        #expect(ClaudePlan.max20x.badgeLabel == "Max 20x")
    }
}
