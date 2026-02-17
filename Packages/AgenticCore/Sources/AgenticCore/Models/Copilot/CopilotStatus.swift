import Foundation

// MARK: - Copilot 內部使用者 API 回應

/// Copilot 內部 API 的回應結構。
///
/// 端點：`GET https://api.github.com/copilot_internal/user`
///
/// 此端點回傳使用者的 Copilot 方案、配額快照（付費方案）及有限配額（免費方案）。
public struct CopilotStatusResponse: Codable, Sendable, Equatable {
    
    /// 使用者的 Copilot 方案識別碼（例如 `"copilot_for_individual_user"`）。
    public let copilotPlan: String?
    
    /// 付費方案的配額快照。
    public let quotaSnapshots: QuotaSnapshots?
    
    /// 免費方案使用者的剩餘配額。
    public let limitedUserQuotas: LimitedQuotas?
    
    /// 免費方案使用者的每月配額總量。
    public let monthlyQuotas: MonthlyQuotas?
    
    enum CodingKeys: String, CodingKey {
        case copilotPlan = "copilot_plan"
        case quotaSnapshots = "quota_snapshots"
        case limitedUserQuotas = "limited_user_quotas"
        case monthlyQuotas = "monthly_quotas"
    }
    
    public init(
        copilotPlan: String? = nil,
        quotaSnapshots: QuotaSnapshots? = nil,
        limitedUserQuotas: LimitedQuotas? = nil,
        monthlyQuotas: MonthlyQuotas? = nil
    ) {
        self.copilotPlan = copilotPlan
        self.quotaSnapshots = quotaSnapshots
        self.limitedUserQuotas = limitedUserQuotas
        self.monthlyQuotas = monthlyQuotas
    }
}

// MARK: - 付費方案：配額快照

/// 付費 Copilot 方案的配額快照。
public struct QuotaSnapshots: Codable, Sendable, Equatable {
    
    /// 進階互動的配額快照。
    public let premiumInteractions: QuotaSnapshot?
    
    /// 聊天功能的配額快照。
    public let chat: QuotaSnapshot?
    
    enum CodingKeys: String, CodingKey {
        case premiumInteractions = "premium_interactions"
        case chat
    }
    
    public init(premiumInteractions: QuotaSnapshot? = nil, chat: QuotaSnapshot? = nil) {
        self.premiumInteractions = premiumInteractions
        self.chat = chat
    }
}

/// 單一配額快照，包含剩餘百分比。
public struct QuotaSnapshot: Codable, Sendable, Equatable {
    
    /// 配額剩餘百分比（0 至 100）。
    public let percentRemaining: Double
    
    enum CodingKeys: String, CodingKey {
        case percentRemaining = "percent_remaining"
    }
    
    public init(percentRemaining: Double) {
        self.percentRemaining = percentRemaining
    }
}

// MARK: - 免費方案：有限配額

/// 免費方案使用者的剩餘配額。
public struct LimitedQuotas: Codable, Sendable, Equatable {
    
    /// 聊天功能的剩餘次數。
    public let chat: Int?
    
    /// 程式碼補全的剩餘次數。
    public let completions: Int?
    
    public init(chat: Int? = nil, completions: Int? = nil) {
        self.chat = chat
        self.completions = completions
    }
}

/// 免費方案使用者的每月配額總量。
public struct MonthlyQuotas: Codable, Sendable, Equatable {
    
    /// 聊天功能的每月總配額。
    public let chat: Int?
    
    /// 程式碼補全的每月總配額。
    public let completions: Int?
    
    public init(chat: Int? = nil, completions: Int? = nil) {
        self.chat = chat
        self.completions = completions
    }
}
