import Testing

@testable import AgenticCore

@Suite("AntigravityPlan")
struct AntigravityPlanTests {

    // MARK: - fromAPIString

    /// 驗證 "free" 字串正確解析為 .free
    @Test
    func fromAPIString_free() {
        #expect(AntigravityPlan.fromAPIString("free") == .free)
    }

    /// 驗證 "pro" 字串正確解析為 .pro
    @Test
    func fromAPIString_pro() {
        #expect(AntigravityPlan.fromAPIString("pro") == .pro)
    }

    /// 驗證傳入 nil 時回傳 nil
    @Test
    func fromAPIString_nil_returnsNil() {
        #expect(AntigravityPlan.fromAPIString(nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func fromAPIString_empty_returnsNil() {
        #expect(AntigravityPlan.fromAPIString("") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func fromAPIString_unknown_returnsNil() {
        #expect(AntigravityPlan.fromAPIString("enterprise") == nil)
        #expect(AntigravityPlan.fromAPIString("max") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func fromAPIString_caseInsensitive() {
        #expect(AntigravityPlan.fromAPIString("FREE") == .free)
        #expect(AntigravityPlan.fromAPIString("Pro") == .pro)
        #expect(AntigravityPlan.fromAPIString("PRO") == .pro)
    }

    // MARK: - badgeLabel

    /// 驗證各方案的 badgeLabel 與預期的顯示文字一致
    @Test
    func badgeLabel_matchesRawValue() {
        #expect(AntigravityPlan.free.badgeLabel == "Free")
        #expect(AntigravityPlan.pro.badgeLabel == "Pro")
    }
}
