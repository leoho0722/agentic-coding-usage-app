import Testing

@testable import AgenticCore

@Suite("CopilotPlan")
struct CopilotPlanTests {

    // MARK: - fromAPIString

    /// 驗證 "copilot_for_individual_user" 字串正確解析為 .pro
    @Test
    func fromAPIString_individualUser_returnsPro() {
        #expect(CopilotPlan.fromAPIString("copilot_for_individual_user") == .pro)
    }

    /// 驗證 "copilot_for_individual_user_pro_plus" 字串正確解析為 .proPlus
    @Test
    func fromAPIString_individualUserProPlus_returnsProPlus() {
        #expect(CopilotPlan.fromAPIString("copilot_for_individual_user_pro_plus") == .proPlus)
    }

    /// 驗證 "copilot_free" 字串正確解析為 .free
    @Test
    func fromAPIString_copilotFree_returnsFree() {
        #expect(CopilotPlan.fromAPIString("copilot_free") == .free)
    }

    /// 驗證傳入 nil 時預設回傳 .pro
    @Test
    func fromAPIString_nil_returnsPro() {
        #expect(CopilotPlan.fromAPIString(nil) == .pro)
    }

    /// 驗證傳入空字串時預設回傳 .pro
    @Test
    func fromAPIString_empty_returnsPro() {
        #expect(CopilotPlan.fromAPIString("") == .pro)
    }

    /// 驗證傳入無法辨識的字串時預設回傳 .pro
    @Test
    func fromAPIString_unknownString_returnsPro() {
        #expect(CopilotPlan.fromAPIString("some_unknown_plan") == .pro)
    }

    /// 驗證 free 方案的字串比對不區分大小寫
    @Test
    func fromAPIString_caseInsensitive_free() {
        #expect(CopilotPlan.fromAPIString("COPILOT_FREE") == .free)
        #expect(CopilotPlan.fromAPIString("Copilot_Free") == .free)
    }

    /// 驗證 proPlus 方案的字串比對不區分大小寫
    @Test
    func fromAPIString_caseInsensitive_proPlus() {
        #expect(CopilotPlan.fromAPIString("PRO_PLUS") == .proPlus)
        #expect(CopilotPlan.fromAPIString("Pro_Plus") == .proPlus)
        #expect(CopilotPlan.fromAPIString("PROPLUS") == .proPlus)
    }

    /// 驗證同時包含 "pro_plus" 與 "free" 時優先匹配 .proPlus
    @Test
    func fromAPIString_proPlusPriorityOverFree() {
        // A string containing both "pro_plus" and "free" should match pro_plus first
        #expect(CopilotPlan.fromAPIString("free_pro_plus") == .proPlus)
    }

    /// 驗證包含 "free" 子字串的未知字串回傳 .free
    @Test
    func fromAPIString_containsFree_returnsFree() {
        #expect(CopilotPlan.fromAPIString("something_free_tier") == .free)
    }

    // MARK: - limit

    /// 驗證 free 方案的使用量上限為 50
    @Test
    func limit_free() {
        #expect(CopilotPlan.free.limit == 50)
    }

    /// 驗證 pro 方案的使用量上限為 300
    @Test
    func limit_pro() {
        #expect(CopilotPlan.pro.limit == 300)
    }

    /// 驗證 proPlus 方案的使用量上限為 1500
    @Test
    func limit_proPlus() {
        #expect(CopilotPlan.proPlus.limit == 1500)
    }

    // MARK: - badgeLabel

    /// 驗證各方案的 badgeLabel 與預期的顯示文字一致
    @Test
    func badgeLabel_matchesRawValue() {
        #expect(CopilotPlan.free.badgeLabel == "Free")
        #expect(CopilotPlan.pro.badgeLabel == "Pro")
        #expect(CopilotPlan.proPlus.badgeLabel == "Pro+")
    }
}
