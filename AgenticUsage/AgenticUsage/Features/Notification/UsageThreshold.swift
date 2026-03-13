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
            String(localized: "\(toolName) Usage Reminder")
        case .ninetyFivePercent, .ninetyNinePercent:
            String(localized: "\(toolName) Usage Warning")
        case .hundredPercent:
            String(localized: "\(toolName) Usage Depleted")
        }
    }

    /// 產生通知內文，包含目前百分比與趣味提示語。
    /// - Parameter usagePercent: 目前使用百分比
    /// - Returns: 通知內文字串
    func body(usagePercent: Int) -> String {
        let pct = "\(usagePercent)%"
        switch self {
        case .eightyPercent:
            return String(localized: "\(pct) used — Take it easy, your quota isn't unlimited!")
        case .ninetyPercent:
            return String(localized: "\(pct) used — Running low, better save some!")
        case .ninetyFivePercent:
            return String(localized: "\(pct) used — Almost gone, think twice before prompting!")
        case .ninetyNinePercent:
            return String(localized: "\(pct) used — Last stand, use wisely!")
        case .hundredPercent:
            return String(localized: "\(pct) used — Congrats, you've squeezed every last drop!")
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
