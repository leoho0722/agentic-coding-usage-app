import Foundation

// MARK: - Billing API Response Models (kept for backwards compatibility)

/// Top-level response from the GitHub premium request usage API.
/// Endpoint: `GET /users/{username}/settings/billing/premium_request/usage`
public struct PremiumRequestUsageResponse: Codable, Sendable {
    public let timePeriod: TimePeriod?
    public let user: String?
    public let usageItems: [UsageItem]

    public init(
        timePeriod: TimePeriod? = nil,
        user: String? = nil,
        usageItems: [UsageItem]
    ) {
        self.timePeriod = timePeriod
        self.user = user
        self.usageItems = usageItems
    }
}

/// The time period filter applied to the usage response.
public struct TimePeriod: Codable, Sendable {
    public let year: Int?
    public let month: Int?
    public let day: Int?

    public init(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
    }
}

/// A single usage item from the billing premium request API.
/// The API returns camelCase JSON keys (e.g. `grossQuantity`, not `gross_quantity`).
public struct UsageItem: Codable, Sendable {
    public let product: String
    public let sku: String?
    public let model: String?
    public let unitType: String?
    public let pricePerUnit: Double?
    public let grossQuantity: Int
    public let grossAmount: Double?
    public let discountQuantity: Int?
    public let discountAmount: Double?
    public let netQuantity: Int?
    public let netAmount: Double?

    public init(
        product: String,
        sku: String? = nil,
        model: String? = nil,
        unitType: String? = nil,
        pricePerUnit: Double? = nil,
        grossQuantity: Int,
        grossAmount: Double? = nil,
        discountQuantity: Int? = nil,
        discountAmount: Double? = nil,
        netQuantity: Int? = nil,
        netAmount: Double? = nil
    ) {
        self.product = product
        self.sku = sku
        self.model = model
        self.unitType = unitType
        self.pricePerUnit = pricePerUnit
        self.grossQuantity = grossQuantity
        self.grossAmount = grossAmount
        self.discountQuantity = discountQuantity
        self.discountAmount = discountAmount
        self.netQuantity = netQuantity
        self.netAmount = netAmount
    }
}

// MARK: - Computed Usage Model

/// Aggregated Copilot usage summary for display.
/// Now supports both the billing API (absolute numbers) and the internal API (percentage-based).
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
    /// Percentage of chat quota remaining (0.0–1.0). Nil if not available.
    public let chatPercentRemaining: Double?

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
        chatPercentRemaining: Double? = nil,
        freeChatRemaining: Int? = nil,
        freeChatTotal: Int? = nil,
        freeCompletionsRemaining: Int? = nil,
        freeCompletionsTotal: Int? = nil
    ) {
        self.plan = plan
        self.planLimit = planLimit
        self.daysUntilReset = daysUntilReset
        self.premiumPercentRemaining = premiumPercentRemaining
        self.chatPercentRemaining = chatPercentRemaining
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
