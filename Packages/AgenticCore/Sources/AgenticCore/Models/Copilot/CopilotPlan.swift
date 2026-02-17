import Foundation

// MARK: - Copilot 方案

/// GitHub Copilot 訂閱方案，定義每月進階請求的配額上限。
///
/// 支援以下三種方案：
/// - ``free``：免費方案，每月 50 次
/// - ``pro``：Pro 方案，每月 300 次
/// - ``proPlus``：Pro+ 方案，每月 1500 次
public enum CopilotPlan: String, Sendable, Equatable {
    
    /// 免費方案。
    case free = "Free"
    /// Pro 方案。
    case pro = "Pro"
    
    /// Pro+ 方案。
    case proPlus = "Pro+"
    
    /// 此方案每月的進階請求配額上限。
    public var limit: Int {
        switch self {
        case .free: 50
        case .pro: 300
        case .proPlus: 1500
        }
    }
    
    /// 從 API 回傳的方案字串解析為 ``CopilotPlan``。
    ///
    /// 透過 `GET /copilot_internal/user` 回傳的 `copilot_plan` 欄位進行比對。
    ///
    /// 已知的 API 值對應：
    /// - `"copilot_for_individual_user"` 對應 `.pro`
    /// - `"copilot_for_individual_user_pro_plus"` 或包含 `"pro_plus"` 對應 `.proPlus`
    /// - `"copilot_free"` 或包含 `"free"` 對應 `.free`
    ///
    /// 無法辨識的字串預設回傳 `.pro`。
    ///
    /// - Parameter apiPlan: API 回傳的方案字串，可為 `nil`。
    /// - Returns: 對應的 ``CopilotPlan`` 列舉值。
    public static func fromAPIString(_ apiPlan: String?) -> CopilotPlan {
        guard let apiPlan, !apiPlan.isEmpty else {
            return .pro
        }
        let lowered = apiPlan.lowercased()
        
        if lowered.contains("pro_plus") || lowered.contains("proplus") {
            return .proPlus
        }
        if lowered.contains("free") {
            return .free
        }
        // "copilot_for_individual_user" 及其他付費方案預設為 Pro
        return .pro
    }
    
    /// 適合作為標章顯示的簡短標籤文字。
    public var badgeLabel: String {
        rawValue
    }
}
