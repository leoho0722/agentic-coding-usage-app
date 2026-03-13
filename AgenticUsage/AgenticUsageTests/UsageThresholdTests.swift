import Testing

@testable import AgenticUsage

@Suite("UsageThreshold")
struct UsageThresholdTests {

    // MARK: - reached(by:)

    /// 驗證使用量低於 80% 時不觸發任何門檻
    @Test
    func reached_below80_empty() {
        #expect(UsageThreshold.reached(by: 79).isEmpty)
        #expect(UsageThreshold.reached(by: 0).isEmpty)
        #expect(UsageThreshold.reached(by: 50).isEmpty)
    }

    /// 驗證使用量達到 80% 時觸發一個門檻
    @Test
    func reached_at80_returnsOne() {
        let thresholds = UsageThreshold.reached(by: 80)
        #expect(thresholds == [.eightyPercent])
    }

    /// 驗證使用量達到 90% 時觸發兩個門檻
    @Test
    func reached_at90_returnsTwo() {
        let thresholds = UsageThreshold.reached(by: 90)
        #expect(thresholds.count == 2)
        #expect(thresholds.contains(.eightyPercent))
        #expect(thresholds.contains(.ninetyPercent))
    }

    /// 驗證使用量達到 95% 時觸發三個門檻
    @Test
    func reached_at95_returnsThree() {
        let thresholds = UsageThreshold.reached(by: 95)
        #expect(thresholds.count == 3)
    }

    /// 驗證使用量達到 99% 時觸發四個門檻
    @Test
    func reached_at99_returnsFour() {
        let thresholds = UsageThreshold.reached(by: 99)
        #expect(thresholds.count == 4)
    }

    /// 驗證使用量達到 100% 時觸發全部五個門檻
    @Test
    func reached_at100_returnsFive() {
        let thresholds = UsageThreshold.reached(by: 100)
        #expect(thresholds.count == 5)
        #expect(thresholds.contains(.hundredPercent))
    }

    /// 驗證使用量超過 100% 時仍回傳五個門檻
    @Test
    func reached_above100_returnsFive() {
        let thresholds = UsageThreshold.reached(by: 150)
        #expect(thresholds.count == 5)
    }

    // MARK: - title

    /// 驗證 80% 與 90% 門檻的標題包含「Reminder」
    @Test
    func title_reminder() {
        #expect(UsageThreshold.eightyPercent.title(for: "Copilot").contains("Copilot"))
        #expect(UsageThreshold.ninetyPercent.title(for: "Copilot").contains("Copilot"))
    }

    /// 驗證 95% 與 99% 門檻的標題包含「Warning」
    @Test
    func title_warning() {
        #expect(UsageThreshold.ninetyFivePercent.title(for: "Copilot").contains("Copilot"))
        #expect(UsageThreshold.ninetyNinePercent.title(for: "Copilot").contains("Copilot"))
    }

    /// 驗證 100% 門檻的標題包含「Depleted」
    @Test
    func title_exhausted() {
        #expect(UsageThreshold.hundredPercent.title(for: "Copilot").contains("Copilot"))
    }

    // MARK: - body

    /// 驗證通知內文包含實際使用百分比數值
    @Test
    func body_containsPercentage() {
        let body = UsageThreshold.eightyPercent.body(usagePercent: 82)
        #expect(body.contains("82%"))
    }

    // MARK: - Comparable

    /// 驗證各門檻的 Comparable 排序從 80% 到 100% 遞增
    @Test
    func comparable_ordering() {
        #expect(UsageThreshold.eightyPercent < UsageThreshold.ninetyPercent)
        #expect(UsageThreshold.ninetyPercent < UsageThreshold.ninetyFivePercent)
        #expect(UsageThreshold.ninetyFivePercent < UsageThreshold.ninetyNinePercent)
        #expect(UsageThreshold.ninetyNinePercent < UsageThreshold.hundredPercent)
    }
}
