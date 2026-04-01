import Foundation

// MARK: - Claude 方案

/// Claude Code 訂閱方案，定義用量窗口與顯示標籤。
///
/// 支援以下方案：
/// - ``free``：免費方案
/// - ``pro``：Pro 方案
/// - ``max``：Max 方案（無法判斷倍率時的備援）
/// - ``max5x``：Max 5x 方案（$100/月）
/// - ``max20x``：Max 20x 方案（$200/月）
public enum ClaudePlan: String, Sendable, Equatable {

    /// 免費方案。
    case free = "Free"

    /// Pro 方案。
    case pro = "Pro"

    /// Max 方案（無法判斷倍率時的備援）。
    case max = "Max"

    /// Max 5x 方案。
    case max5x = "Max 5x"

    /// Max 20x 方案。
    case max20x = "Max 20x"

    /// 從 API 回傳的訂閱類型與速率限制層級解析為 ``ClaudePlan``。
    ///
    /// 已知的 API 值對應：
    /// - `"free"` 對應 `.free`
    /// - `"pro"` 對應 `.pro`
    /// - `"max"` 對應 `.max`，再依 `rateLimitTier` 細分：
    ///   - 包含 `"max_5x"` → `.max5x`
    ///   - 包含 `"max_20x"` → `.max20x`
    ///   - 其他或 `nil` → `.max`
    ///
    /// 無法辨識或為 `nil` 時回傳 `nil`。
    ///
    /// - Parameters:
    ///   - subscriptionType: API 回傳的訂閱類型字串，可為 `nil`。
    ///   - rateLimitTier: 速率限制層級字串，可為 `nil`。
    public init?(from subscriptionType: String?, rateLimitTier: String? = nil) {
        guard let subscriptionType, !subscriptionType.isEmpty else { return nil }
        switch subscriptionType.lowercased() {
        case "free": self = .free
        case "pro": self = .pro
        case "max":
            if let tier = rateLimitTier?.lowercased() {
                if tier.contains("max_20x") { self = .max20x }
                else if tier.contains("max_5x") { self = .max5x }
                else { self = .max }
            } else {
                self = .max
            }
        default: return nil
        }
    }

    /// 是否為 Max 系列方案（含 `.max`、`.max5x`、`.max20x`）。
    public var isMax: Bool {
        switch self {
        case .max, .max5x, .max20x: true
        default: false
        }
    }

    /// 適合作為標章顯示的簡短標籤文字。
    public var badgeLabel: String { rawValue }
}
