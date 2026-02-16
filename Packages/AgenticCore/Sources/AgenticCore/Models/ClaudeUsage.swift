import Foundation

// MARK: - Claude Usage API Response

/// Raw response from `GET https://api.anthropic.com/api/oauth/usage`.
public struct ClaudeUsageResponse: Codable, Sendable, Equatable {
    /// Session window (5 hours).
    public let fiveHour: ClaudeUsagePeriod?
    /// Weekly window (7 days).
    public let sevenDay: ClaudeUsagePeriod?
    /// Weekly Opus window (7 days, plan-dependent).
    public let sevenDayOpus: ClaudeUsagePeriod?
    /// Extra usage (overages beyond included quota).
    public let extraUsage: ClaudeExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }

    public init(
        fiveHour: ClaudeUsagePeriod? = nil,
        sevenDay: ClaudeUsagePeriod? = nil,
        sevenDayOpus: ClaudeUsagePeriod? = nil,
        extraUsage: ClaudeExtraUsage? = nil
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDayOpus = sevenDayOpus
        self.extraUsage = extraUsage
    }
}

/// A single utilization window (e.g. session 5h, weekly 7d).
public struct ClaudeUsagePeriod: Codable, Sendable, Equatable {
    /// Utilization percentage as integer 0–100.
    public let utilization: Int
    /// ISO 8601 timestamp when this window resets.
    public let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    public init(utilization: Int, resetsAt: String) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

/// Extra usage information (overages billed beyond included quota).
public struct ClaudeExtraUsage: Codable, Sendable, Equatable {
    /// Whether extra usage is enabled for this account.
    public let isEnabled: Bool
    /// Credits used in cents (divide by 100 for dollars).
    public let usedCredits: Int?
    /// Monthly credit limit in cents.
    public let monthlyLimit: Int?
    /// Currency code (e.g. "USD").
    public let currency: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
        case currency
    }
}

// MARK: - Display Model

/// Processed Claude Code usage data ready for display in UI / CLI.
public struct ClaudeUsageSummary: Equatable, Sendable {
    /// Subscription type string from credentials (e.g. "pro", "max").
    public let subscriptionType: String?

    /// Session (5h) utilization percentage (0–100), or `nil` if absent.
    public let sessionUtilization: Int?
    /// Session reset ISO string.
    public let sessionResetsAt: String?

    /// Weekly (7d) utilization percentage (0–100), or `nil` if absent.
    public let weeklyUtilization: Int?
    /// Weekly reset ISO string.
    public let weeklyResetsAt: String?

    /// Opus (7d) utilization percentage (0–100), or `nil` if plan doesn't include it.
    public let opusUtilization: Int?
    /// Opus reset ISO string.
    public let opusResetsAt: String?

    /// Extra usage enabled flag.
    public let extraUsageEnabled: Bool
    /// Extra usage used credits in cents.
    public let extraUsageUsedCents: Int?
    /// Extra usage monthly limit in cents.
    public let extraUsageLimitCents: Int?
    /// Extra usage currency.
    public let extraUsageCurrency: String?

    public init(
        subscriptionType: String?,
        response: ClaudeUsageResponse
    ) {
        self.subscriptionType = subscriptionType

        self.sessionUtilization = response.fiveHour?.utilization
        self.sessionResetsAt = response.fiveHour?.resetsAt

        self.weeklyUtilization = response.sevenDay?.utilization
        self.weeklyResetsAt = response.sevenDay?.resetsAt

        self.opusUtilization = response.sevenDayOpus?.utilization
        self.opusResetsAt = response.sevenDayOpus?.resetsAt

        if let extra = response.extraUsage {
            self.extraUsageEnabled = extra.isEnabled
            self.extraUsageUsedCents = extra.usedCredits
            self.extraUsageLimitCents = extra.monthlyLimit
            self.extraUsageCurrency = extra.currency
        } else {
            self.extraUsageEnabled = false
            self.extraUsageUsedCents = nil
            self.extraUsageLimitCents = nil
            self.extraUsageCurrency = nil
        }
    }

    /// Whether Opus data is present (plan-dependent).
    public var hasOpus: Bool { opusUtilization != nil }

    /// Whether extra usage section should be shown.
    public var hasExtraUsage: Bool { extraUsageEnabled }

    /// Extra usage used in dollars (e.g. 5.00).
    public var extraUsageUsedDollars: Double? {
        guard let cents = extraUsageUsedCents else { return nil }
        return Double(cents) / 100.0
    }

    /// Extra usage limit in dollars.
    public var extraUsageLimitDollars: Double? {
        guard let cents = extraUsageLimitCents else { return nil }
        return Double(cents) / 100.0
    }

    /// Formatted subscription type for display (e.g. "Pro", "Max", "Free").
    public var planDisplayName: String {
        guard let sub = subscriptionType?.lowercased() else { return "Unknown" }
        switch sub {
        case "pro": return "Pro"
        case "max", "pro_plus": return "Max"
        case "free": return "Free"
        default: return sub.capitalized
        }
    }
}

// MARK: - Reset Time Utilities

extension ClaudeUsagePeriod {
    /// Parse `resetsAt` into a `Date`.
    public var resetsAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    /// Human-readable countdown string until reset (e.g. "2h 30m", "3d 5h").
    public var resetCountdown: String? {
        guard let resetDate = resetsAtDate else { return nil }
        let now = Date()
        guard resetDate > now else { return "now" }

        let interval = resetDate.timeIntervalSince(now)
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
