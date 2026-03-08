import Testing

@testable import AgenticCore

@Suite("CodexPlan")
struct CodexPlanTests {

    // MARK: - init(from:)

    /// 驗證所有已知方案字串皆能正確解析為對應的列舉值
    @Test
    func initFrom_allCases() {
        #expect(CodexPlan(from: "free") == .free)
        #expect(CodexPlan(from: "plus") == .plus)
        #expect(CodexPlan(from: "pro") == .pro)
        #expect(CodexPlan(from: "team") == .team)
        #expect(CodexPlan(from: "enterprise") == .enterprise)
    }

    /// 驗證傳入 nil 時回傳 nil
    @Test
    func initFrom_nil_returnsNil() {
        #expect(CodexPlan(from: nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func initFrom_empty_returnsNil() {
        #expect(CodexPlan(from: "") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func initFrom_unknown_returnsNil() {
        #expect(CodexPlan(from: "premium") == nil)
        #expect(CodexPlan(from: "basic") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func initFrom_caseInsensitive() {
        #expect(CodexPlan(from: "FREE") == .free)
        #expect(CodexPlan(from: "Plus") == .plus)
        #expect(CodexPlan(from: "PRO") == .pro)
        #expect(CodexPlan(from: "Team") == .team)
        #expect(CodexPlan(from: "ENTERPRISE") == .enterprise)
    }

    // MARK: - badgeLabel

    /// 驗證各方案的 badgeLabel 與預期的顯示文字一致
    @Test
    func badgeLabel_matchesRawValue() {
        #expect(CodexPlan.free.badgeLabel == "Free")
        #expect(CodexPlan.plus.badgeLabel == "Plus")
        #expect(CodexPlan.pro.badgeLabel == "Pro")
        #expect(CodexPlan.team.badgeLabel == "Team")
        #expect(CodexPlan.enterprise.badgeLabel == "Enterprise")
    }
}
