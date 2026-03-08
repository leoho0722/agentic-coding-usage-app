import Foundation
import Testing

@testable import AgenticCore

@Suite("DateUtils")
struct DateUtilsTests {

    /// 驗證月中日期正確計算距離下月一日的天數
    @Test
    func daysUntilReset_midMonth() {
        let date = makeUTCDate(year: 2025, month: 3, day: 15)
        let days = DateUtils.daysUntilReset(from: date)
        #expect(days == 17) // 3/15 → 4/1 = 17 天
    }

    /// 驗證月底最後一天距離下月一日僅剩一天
    @Test
    func daysUntilReset_lastDayOfMonth() {
        let date = makeUTCDate(year: 2025, month: 3, day: 31)
        let days = DateUtils.daysUntilReset(from: date)
        #expect(days == 1) // 3/31 → 4/1 = 1 天
    }

    /// 驗證月初第一天距離下月一日為整個月的天數
    @Test
    func daysUntilReset_firstDayOfMonth() {
        let date = makeUTCDate(year: 2025, month: 3, day: 1)
        let days = DateUtils.daysUntilReset(from: date)
        #expect(days == 31) // 3/1 → 4/1 = 31 天
    }

    /// 驗證十二月日期能正確跨年計算距離隔年一月一日的天數
    @Test
    func daysUntilReset_december_crossYear() {
        let date = makeUTCDate(year: 2025, month: 12, day: 15)
        let days = DateUtils.daysUntilReset(from: date)
        #expect(days == 17) // 12/15 → 1/1 = 17 天
    }

    /// 驗證閏年二月能正確計算距離三月一日的天數
    @Test
    func daysUntilReset_leapYear_february() {
        let date = makeUTCDate(year: 2024, month: 2, day: 15)
        let days = DateUtils.daysUntilReset(from: date)
        #expect(days == 15) // 2/15 → 3/1 = 15 天（閏年：29 - 15 + 1 = 15）
    }
}

// MARK: - Helper Methods

private extension DateUtilsTests {

    /// 建立指定年月日的 UTC 日期，用於測試固定時間點
    /// - Parameters:
    ///   - year: 西元年
    ///   - month: 月份（1–12）
    ///   - day: 日（1–31）
    /// - Returns: 對應的 UTC `Date`
    func makeUTCDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
