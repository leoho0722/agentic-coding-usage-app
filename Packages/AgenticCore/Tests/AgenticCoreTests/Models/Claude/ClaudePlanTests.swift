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

    /// 驗證 "pro_plus" 字串映射為 .max
    @Test
    func initFrom_proPlus_mapsToMax() {
        #expect(ClaudePlan(from: "pro_plus") == .max)
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
        #expect(ClaudePlan(from: "unknown") == nil)
    }

    /// 驗證字串比對不區分大小寫
    @Test
    func initFrom_caseInsensitive() {
        #expect(ClaudePlan(from: "FREE") == .free)
        #expect(ClaudePlan(from: "Pro") == .pro)
        #expect(ClaudePlan(from: "MAX") == .max)
        #expect(ClaudePlan(from: "PRO_PLUS") == .max)
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
