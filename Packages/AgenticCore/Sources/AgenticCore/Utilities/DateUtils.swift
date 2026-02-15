import Foundation

/// Utilities for date calculations related to billing cycles.
public enum DateUtils {
    /// Calculate the number of days until the premium request counter resets.
    ///
    /// GitHub Copilot premium request counters reset on the **1st of each month at 00:00:00 UTC**.
    public static func daysUntilReset(from date: Date = .now) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Get the 1st of the next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date),
            let firstOfNextMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: nextMonth))
        else {
            return 0
        }

        let components = calendar.dateComponents([.day], from: date, to: firstOfNextMonth)
        return max(0, components.day ?? 0)
    }
}
