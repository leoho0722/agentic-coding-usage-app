import Foundation

// MARK: - Codex 方案

/// OpenAI Codex 訂閱方案，定義用量窗口與顯示標籤。
///
/// 支援以下五種方案：
/// - ``free``：免費方案
/// - ``plus``：Plus 方案
/// - ``pro``：Pro 方案
/// - ``team``：Team 方案
/// - ``enterprise``：Enterprise 方案
public enum CodexPlan: String, Sendable, Equatable {

    /// 免費方案。
    case free = "Free"

    /// Plus 方案。
    case plus = "Plus"

    /// Pro 方案。
    case pro = "Pro"

    /// Team 方案。
    case team = "Team"

    /// Enterprise 方案。
    case enterprise = "Enterprise"

    /// 從 API 回傳的方案類型字串解析為 ``CodexPlan``。
    ///
    /// 已知的 API 值對應：
    /// - `"free"` 對應 `.free`
    /// - `"plus"` 對應 `.plus`
    /// - `"pro"` 對應 `.pro`
    /// - `"team"` 對應 `.team`
    /// - `"enterprise"` 對應 `.enterprise`
    ///
    /// 無法辨識或為 `nil` 時回傳 `nil`。
    ///
    /// - Parameter raw: API 回傳的方案類型字串，可為 `nil`。
    /// - Returns: 對應的 ``CodexPlan`` 列舉值，或 `nil`。
    public static func fromAPIString(_ raw: String?) -> CodexPlan? {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "free": return .free
        case "plus": return .plus
        case "pro": return .pro
        case "team": return .team
        case "enterprise": return .enterprise
        default: return nil
        }
    }

    /// 適合作為標章顯示的簡短標籤文字。
    public var badgeLabel: String { rawValue }
}
