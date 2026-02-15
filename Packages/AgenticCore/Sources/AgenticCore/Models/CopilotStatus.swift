import Foundation

// MARK: - Copilot Internal User API Response

/// Response from the internal Copilot API.
/// Endpoint: `GET https://api.github.com/copilot_internal/user`
///
/// This endpoint returns the user's Copilot plan, quota snapshots (for paid tiers),
/// and limited user quotas (for free tier).
public struct CopilotStatusResponse: Codable, Sendable, Equatable {
    /// The user's Copilot plan identifier (e.g. "copilot_for_individual_user").
    public let copilotPlan: String?
    /// Quota snapshots for paid tiers.
    public let quotaSnapshots: QuotaSnapshots?
    /// Date when paid tier quotas reset.
    public let quotaResetDate: String?
    /// Remaining quotas for free tier users.
    public let limitedUserQuotas: LimitedQuotas?
    /// Total monthly quotas for free tier users.
    public let monthlyQuotas: MonthlyQuotas?
    /// Date when free tier quotas reset.
    public let limitedUserResetDate: String?

    enum CodingKeys: String, CodingKey {
        case copilotPlan = "copilot_plan"
        case quotaSnapshots = "quota_snapshots"
        case quotaResetDate = "quota_reset_date"
        case limitedUserQuotas = "limited_user_quotas"
        case monthlyQuotas = "monthly_quotas"
        case limitedUserResetDate = "limited_user_reset_date"
    }

    public init(
        copilotPlan: String? = nil,
        quotaSnapshots: QuotaSnapshots? = nil,
        quotaResetDate: String? = nil,
        limitedUserQuotas: LimitedQuotas? = nil,
        monthlyQuotas: MonthlyQuotas? = nil,
        limitedUserResetDate: String? = nil
    ) {
        self.copilotPlan = copilotPlan
        self.quotaSnapshots = quotaSnapshots
        self.quotaResetDate = quotaResetDate
        self.limitedUserQuotas = limitedUserQuotas
        self.monthlyQuotas = monthlyQuotas
        self.limitedUserResetDate = limitedUserResetDate
    }
}

// MARK: - Paid Tier: Quota Snapshots

/// Quota snapshots for paid Copilot plans.
public struct QuotaSnapshots: Codable, Sendable, Equatable {
    public let premiumInteractions: QuotaSnapshot?
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

/// A single quota snapshot with percentage remaining.
public struct QuotaSnapshot: Codable, Sendable, Equatable {
    /// Percentage of quota remaining (0–100).
    public let percentRemaining: Double

    enum CodingKeys: String, CodingKey {
        case percentRemaining = "percent_remaining"
    }

    public init(percentRemaining: Double) {
        self.percentRemaining = percentRemaining
    }
}

// MARK: - Free Tier: Limited Quotas

/// Remaining quotas for free tier users.
public struct LimitedQuotas: Codable, Sendable, Equatable {
    public let chat: Int?
    public let completions: Int?

    public init(chat: Int? = nil, completions: Int? = nil) {
        self.chat = chat
        self.completions = completions
    }
}

/// Total monthly quotas for free tier users.
public struct MonthlyQuotas: Codable, Sendable, Equatable {
    public let chat: Int?
    public let completions: Int?

    public init(chat: Int? = nil, completions: Int? = nil) {
        self.chat = chat
        self.completions = completions
    }
}
