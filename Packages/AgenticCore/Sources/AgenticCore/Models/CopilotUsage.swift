import Foundation

// MARK: - Computed Usage Model

/// Aggregated Copilot usage summary for display.
/// Supports both the internal API percentage-based (paid tier) and count-based (free tier) data.
public struct CopilotUsageSummary: Equatable, Sendable {
    /// The auto-detected plan from the internal API.
    public let plan: CopilotPlan
    /// The plan's monthly premium request limit.
    public let planLimit: Int
    /// Days remaining until the usage counter resets.
    public let daysUntilReset: Int

    // MARK: - Paid tier fields (from quota_snapshots)

    /// Percentage of premium requests remaining (0.0–1.0). Nil for free tier.
    public let premiumPercentRemaining: Double?

    // MARK: - Free tier fields (from limited_user_quotas)

    /// Chat requests remaining (free tier). Nil for paid tier.
    public let freeChatRemaining: Int?
    /// Chat requests total (free tier). Nil for paid tier.
    public let freeChatTotal: Int?
    /// Completions remaining (free tier). Nil for paid tier.
    public let freeCompletionsRemaining: Int?
    /// Completions total (free tier). Nil for paid tier.
    public let freeCompletionsTotal: Int?

    public init(
        plan: CopilotPlan,
        planLimit: Int,
        daysUntilReset: Int,
        premiumPercentRemaining: Double? = nil,
        freeChatRemaining: Int? = nil,
        freeChatTotal: Int? = nil,
        freeCompletionsRemaining: Int? = nil,
        freeCompletionsTotal: Int? = nil
    ) {
        self.plan = plan
        self.planLimit = planLimit
        self.daysUntilReset = daysUntilReset
        self.premiumPercentRemaining = premiumPercentRemaining
        self.freeChatRemaining = freeChatRemaining
        self.freeChatTotal = freeChatTotal
        self.freeCompletionsRemaining = freeCompletionsRemaining
        self.freeCompletionsTotal = freeCompletionsTotal
    }

    /// Whether this is a free tier user.
    public var isFreeTier: Bool {
        plan == .free
    }

    /// Usage percentage for display (0.0–1.0). Used portion, not remaining.
    /// For paid tier: derived from `premiumPercentRemaining`.
    /// For free tier: derived from chat remaining/total.
    public var usagePercentage: Double {
        if let premiumPercentRemaining {
            return max(0, min(1.0, (100.0 - premiumPercentRemaining) / 100.0))
        }
        if let remaining = freeChatRemaining, let total = freeChatTotal, total > 0 {
            return max(0, min(1.0, Double(total - remaining) / Double(total)))
        }
        return 0
    }

    /// Estimated premium requests used (for paid tiers).
    public var premiumRequestsUsed: Int {
        if let premiumPercentRemaining {
            let usedPercent = max(0, min(100, 100.0 - premiumPercentRemaining))
            return Int(round(Double(planLimit) * usedPercent / 100.0))
        }
        return 0
    }

    /// Estimated remaining premium requests (for paid tiers).
    public var remaining: Int {
        if let premiumPercentRemaining {
            return Int(round(Double(planLimit) * max(0, min(100, premiumPercentRemaining)) / 100.0))
        }
        if let remaining = freeChatRemaining {
            return remaining
        }
        return planLimit
    }
}
