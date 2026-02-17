import Foundation

// MARK: - UsageThreshold

/// 觸發本地通知的使用量百分比門檻定義。
///
/// 當用量達到指定門檻時，會發送對應的本地通知提醒使用者。
enum UsageThreshold: Int, CaseIterable, Comparable, Sendable {
    
    /// 80% 門檻
    case eightyPercent = 80
    
    /// 90% 門檻
    case ninetyPercent = 90
    
    /// 95% 門檻
    case ninetyFivePercent = 95
    
    /// 99% 門檻
    case ninetyNinePercent = 99
    
    /// 100% 門檻（已用盡）
    case hundredPercent = 100

    /// 依據 rawValue 比較兩個門檻的大小關係，實作 `Comparable` 協定。
    /// - Parameters:
    ///   - lhs: 左側門檻
    ///   - rhs: 右側門檻
    /// - Returns: 若左側門檻的數值小於右側則回傳 `true`
    static func < (lhs: UsageThreshold, rhs: UsageThreshold) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 產生通知標題，依據門檻等級區分提醒、警告與用盡。
    /// - Parameter toolName: 工具顯示名稱
    /// - Returns: 通知標題字串
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

    /// 產生通知內文，包含目前百分比與趣味提示語。
    /// - Parameter usagePercent: 目前使用百分比
    /// - Returns: 通知內文字串
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

    /// 取得指定用量百分比已達到的所有門檻列表。
    ///
    /// 若低於 80% 則回傳空陣列。
    /// - Parameter usagePercent: 目前使用百分比
    /// - Returns: 已達到的門檻陣列
    static func reached(by usagePercent: Int) -> [UsageThreshold] {
        allCases.filter { usagePercent >= $0.rawValue }
    }
}
