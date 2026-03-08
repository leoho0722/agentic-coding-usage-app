import Testing

@testable import AgenticCore

@Suite("CodexPlan")
struct CodexPlanTests {

    // MARK: - fromAPIString

    /// 驗證所有已知方案字串皆能正確解析為對應的列舉值
    @Test
    func fromAPIString_allCases() {
        #expect(CodexPlan.fromAPIString("free") == .free)
        #expect(CodexPlan.fromAPIString("plus") == .plus)
        #expect(CodexPlan.fromAPIString("pro") == .pro)
        #expect(CodexPlan.fromAPIString("team") == .team)
        #expect(CodexPlan.fromAPIString("enterprise") == .enterprise)
    }

    /// 驗證傳入 nil 時回傳 nil
    @Test
    func fromAPIString_nil_returnsNil() {
        #expect(CodexPlan.fromAPIString(nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func fromAPIString_empty_returnsNil() {
        #expect(CodexPlan.fromAPIString("") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func fromAPIString_unknown_returnsNil() {
        #expect(CodexPlan.fromAPIString("premium") == nil)
        #expect(CodexPlan.fromAPIString("basic") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func fromAPIString_caseInsensitive() {
        #expect(CodexPlan.fromAPIString("FREE") == .free)
        #expect(CodexPlan.fromAPIString("Plus") == .plus)
        #expect(CodexPlan.fromAPIString("PRO") == .pro)
        #expect(CodexPlan.fromAPIString("Team") == .team)
        #expect(CodexPlan.fromAPIString("ENTERPRISE") == .enterprise)
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
