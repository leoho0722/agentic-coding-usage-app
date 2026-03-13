import Testing

@testable import AgenticCore

@Suite("CopilotPlan")
struct CopilotPlanTests {

    // MARK: - init(from:)

    /// 驗證 "copilot_for_individual_user" 字串正確解析為 .pro
    @Test
    func initFrom_individualUser_returnsPro() {
        #expect(CopilotPlan(from: "copilot_for_individual_user") == .pro)
    }

    /// 驗證 "individual" 字串正確解析為 .pro
    @Test
    func initFrom_individual_returnsPro() {
        #expect(CopilotPlan(from: "individual") == .pro)
    }

    /// 驗證 "copilot_for_individual_user_pro_plus" 字串正確解析為 .proPlus
    @Test
    func initFrom_individualUserProPlus_returnsProPlus() {
        #expect(CopilotPlan(from: "copilot_for_individual_user_pro_plus") == .proPlus)
    }

    /// 驗證 "copilot_free" 字串正確解析為 .free
    @Test
    func initFrom_copilotFree_returnsFree() {
        #expect(CopilotPlan(from: "copilot_free") == .free)
    }

    /// 驗證傳入 nil 時回傳 nil
    @Test
    func initFrom_nil_returnsNil() {
        #expect(CopilotPlan(from: nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func initFrom_empty_returnsNil() {
        #expect(CopilotPlan(from: "") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func initFrom_unknownString_returnsNil() {
        #expect(CopilotPlan(from: "some_unknown_plan") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func initFrom_caseInsensitive() {
        #expect(CopilotPlan(from: "COPILOT_FREE") == .free)
        #expect(CopilotPlan(from: "Copilot_Free") == .free)
        #expect(CopilotPlan(from: "COPILOT_FOR_INDIVIDUAL_USER") == .pro)
        #expect(CopilotPlan(from: "COPILOT_FOR_INDIVIDUAL_USER_PRO_PLUS") == .proPlus)
    }

    /// 驗證不再進行模糊比對
    @Test
    func initFrom_noFuzzyMatch() {
        #expect(CopilotPlan(from: "something_free_tier") == nil)
        #expect(CopilotPlan(from: "free_pro_plus") == nil)
        #expect(CopilotPlan(from: "PRO_PLUS") == nil)
        #expect(CopilotPlan(from: "PROPLUS") == nil)
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
