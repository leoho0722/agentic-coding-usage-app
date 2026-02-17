import Foundation

// MARK: - 日期工具

/// 帳單週期相關的日期計算工具。
public enum DateUtils {
    
    /// 計算距離進階請求計數器重置的天數。
    ///
    /// GitHub Copilot 的進階請求計數器於每月 **1 日 00:00:00 UTC** 重置。
    ///
    /// - Parameter date: 計算基準日期（預設為當前時間）。
    /// - Returns: 距離重置的天數。
    public static func daysUntilReset(from date: Date = .now) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // 取得下個月的 1 日
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date),
              let firstOfNextMonth = calendar.date(
                  from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
            return 0
        }

        let components = calendar.dateComponents([.day], from: date, to: firstOfNextMonth)
        return max(0, components.day ?? 0)
    }
}
