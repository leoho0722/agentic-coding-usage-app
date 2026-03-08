import Testing

@testable import AgenticCore

@Suite("AntigravityPlan")
struct AntigravityPlanTests {

    // MARK: - init(from:)

    /// 驗證 "free" 字串正確解析為 .free
    @Test
    func initFrom_free() {
        #expect(AntigravityPlan(from: "free") == .free)
    }

    /// 驗證 "pro" 字串正確解析為 .pro
    @Test
    func initFrom_pro() {
        #expect(AntigravityPlan(from: "pro") == .pro)
    }

    /// 驗證傳入 nil 時回傳 nil
    @Test
    func initFrom_nil_returnsNil() {
        #expect(AntigravityPlan(from: nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func initFrom_empty_returnsNil() {
        #expect(AntigravityPlan(from: "") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func initFrom_unknown_returnsNil() {
        #expect(AntigravityPlan(from: "enterprise") == nil)
        #expect(AntigravityPlan(from: "max") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func initFrom_caseInsensitive() {
        #expect(AntigravityPlan(from: "FREE") == .free)
        #expect(AntigravityPlan(from: "Pro") == .pro)
        #expect(AntigravityPlan(from: "PRO") == .pro)
    }

    // MARK: - badgeLabel

    /// 驗證各方案的 badgeLabel 與預期的顯示文字一致
    @Test
    func badgeLabel_matchesRawValue() {
        #expect(AntigravityPlan.free.badgeLabel == "Free")
        #expect(AntigravityPlan.pro.badgeLabel == "Pro")
    }
}
