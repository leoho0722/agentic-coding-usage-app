import Foundation

// MARK: - Claude 方案

/// Claude Code 訂閱方案，定義用量窗口與顯示標籤。
///
/// 支援以下三種方案：
/// - ``free``：免費方案
/// - ``pro``：Pro 方案
/// - ``max``：Max 方案（API 可能回傳 `"max"` 或 `"pro_plus"`）
public enum ClaudePlan: String, Sendable, Equatable {

    /// 免費方案。
    case free = "Free"

    /// Pro 方案。
    case pro = "Pro"

    /// Max 方案。
    case max = "Max"

    /// 從 API 回傳的訂閱類型字串解析為 ``ClaudePlan``。
    ///
    /// 已知的 API 值對應：
    /// - `"pro"` 對應 `.pro`
    /// - `"max"` 或 `"pro_plus"` 對應 `.max`
    /// - `"free"` 對應 `.free`
    ///
    /// 無法辨識或為 `nil` 時回傳 `nil`。
    ///
    /// - Parameter raw: API 回傳的訂閱類型字串，可為 `nil`。
    /// - Returns: 對應的 ``ClaudePlan`` 列舉值，或 `nil`。
    public static func fromAPIString(_ raw: String?) -> ClaudePlan? {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "free": return .free
        case "pro": return .pro
        case "max", "pro_plus": return .max
        default: return nil
        }
    }

    /// 適合作為標章顯示的簡短標籤文字。
    public var badgeLabel: String { rawValue }
}
