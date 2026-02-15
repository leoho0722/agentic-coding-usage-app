import Foundation

/// Usage percentage thresholds that trigger local notifications.
enum UsageThreshold: Int, CaseIterable, Comparable, Sendable {
    case eightyPercent = 80
    case ninetyPercent = 90
    case ninetyFivePercent = 95
    case ninetyNinePercent = 99
    case hundredPercent = 100

    static func < (lhs: UsageThreshold, rhs: UsageThreshold) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Notification title, parameterised by tool name.
    func title(for toolName: String) -> String {
        switch self {
        case .eightyPercent, .ninetyPercent:
            "\(toolName) 使用量提醒"
        case .ninetyFivePercent, .ninetyNinePercent:
            "\(toolName) 使用量警告"
        case .hundredPercent:
            "\(toolName) 使用量已用盡"
        }
    }

    /// Notification body including the current percentage and a witty message.
    func body(usagePercent: Int) -> String {
        let pct = "已使用 \(usagePercent)%"
        switch self {
        case .eightyPercent:
            return "\(pct)，悠著點用，額度不是無限的！"
        case .ninetyPercent:
            return "\(pct)，快見底了，省著點吧！"
        case .ninetyFivePercent:
            return "\(pct)，只剩一點點了，三思而後 prompt！"
        case .ninetyNinePercent:
            return "\(pct)，最後的倔強，且用且珍惜！"
        case .hundredPercent:
            return "\(pct)，恭喜你把額度榨乾了，這個月的錢沒白花！"
        }
    }

    /// Returns the highest threshold that the given usage percentage has reached, or `nil` if below 80%.
    static func reached(by usagePercent: Int) -> [UsageThreshold] {
        allCases.filter { usagePercent >= $0.rawValue }
    }
}
