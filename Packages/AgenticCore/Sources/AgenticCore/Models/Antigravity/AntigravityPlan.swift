import Foundation

// MARK: - Antigravity 方案

/// Google Antigravity 訂閱方案列舉。
///
/// Cloud Code API 目前不回傳方案資訊，v1.7.0 中 plan 始終為 nil。
/// 保留此列舉以供未來擴充使用。
public enum AntigravityPlan: String, Sendable, Equatable {
    
    /// 免費方案。
    case free = "Free"
    
    /// Pro 方案。
    case pro = "Pro"
    
    /// 從 API 回傳的方案類型字串解析為 ``AntigravityPlan``。
    ///
    /// - Parameter raw: API 回傳的方案類型字串，可為 `nil`。
    public init?(from raw: String?) {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "free": self = .free
        case "pro": self = .pro
        default: return nil
        }
    }
    
    /// 適合作為標章顯示的簡短標籤文字。
    public var badgeLabel: String { rawValue }
}
