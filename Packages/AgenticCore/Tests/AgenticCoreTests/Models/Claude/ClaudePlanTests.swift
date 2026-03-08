import Testing

@testable import AgenticCore

@Suite("ClaudePlan")
struct ClaudePlanTests {

    // MARK: - fromAPIString

    /// 驗證 "free" 字串正確解析為 .free
    @Test
    func fromAPIString_free() {
        #expect(ClaudePlan.fromAPIString("free") == .free)
    }

    /// 驗證 "pro" 字串正確解析為 .pro
    @Test
    func fromAPIString_pro() {
        #expect(ClaudePlan.fromAPIString("pro") == .pro)
    }

    /// 驗證 "max" 字串正確解析為 .max
    @Test
    func fromAPIString_max() {
        #expect(ClaudePlan.fromAPIString("max") == .max)
    }

    /// 驗證 "pro_plus" 字串映射為 .max
    @Test
    func fromAPIString_proPlus_mapsToMax() {
        #expect(ClaudePlan.fromAPIString("pro_plus") == .max)
    }

    /// 驗證傳入 nil 時回傳 nil
    @Test
    func fromAPIString_nil_returnsNil() {
        #expect(ClaudePlan.fromAPIString(nil) == nil)
    }

    /// 驗證傳入空字串時回傳 nil
    @Test
    func fromAPIString_empty_returnsNil() {
        #expect(ClaudePlan.fromAPIString("") == nil)
    }

    /// 驗證傳入無法辨識的字串時回傳 nil
    @Test
    func fromAPIString_unknown_returnsNil() {
        #expect(ClaudePlan.fromAPIString("enterprise") == nil)
        #expect(ClaudePlan.fromAPIString("unknown") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func fromAPIString_caseInsensitive() {
        #expect(ClaudePlan.fromAPIString("FREE") == .free)
        #expect(ClaudePlan.fromAPIString("Pro") == .pro)
        #expect(ClaudePlan.fromAPIString("MAX") == .max)
        #expect(ClaudePlan.fromAPIString("PRO_PLUS") == .max)
    }

    // MARK: - badgeLabel

    /// 驗證各方案的 badgeLabel 與預期的顯示文字一致
    @Test
    func badgeLabel_matchesRawValue() {
        #expect(ClaudePlan.free.badgeLabel == "Free")
        #expect(ClaudePlan.pro.badgeLabel == "Pro")
        #expect(ClaudePlan.max.badgeLabel == "Max")
    }
}
