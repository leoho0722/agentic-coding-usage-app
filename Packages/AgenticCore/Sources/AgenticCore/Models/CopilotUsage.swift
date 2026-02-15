import Foundation

// MARK: - API Response Models

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

/// Aggregated Copilot premium request usage for display.
public struct CopilotUsageSummary: Equatable, Sendable {
    /// Total premium requests used this billing cycle.
    public let premiumRequestsUsed: Int
    /// The user's plan limit.
    public let planLimit: Int
    /// The plan type.
    public let plan: CopilotPlan
    /// Days remaining until the usage counter resets (1st of next month UTC).
    public let daysUntilReset: Int

    public init(
        premiumRequestsUsed: Int,
        planLimit: Int,
        plan: CopilotPlan,
        daysUntilReset: Int
    ) {
        self.premiumRequestsUsed = premiumRequestsUsed
        self.planLimit = planLimit
        self.plan = plan
        self.daysUntilReset = daysUntilReset
    }

    /// Usage as a fraction (0.0 – 1.0+). Can exceed 1.0 if over limit.
    public var usagePercentage: Double {
        guard planLimit > 0 else { return 0 }
        return Double(premiumRequestsUsed) / Double(planLimit)
    }

    /// Remaining premium requests.
    public var remaining: Int {
        max(0, planLimit - premiumRequestsUsed)
    }
}
