import Foundation

// MARK: - Codex Usage API Response (Body)

/// Raw response body from `GET https://chatgpt.com/backend-api/wham/usage`.
public struct CodexUsageResponse: Codable, Sendable, Equatable {
    public let rateLimit: CodexRateLimit?
    public let additionalRateLimits: [CodexAdditionalRateLimit]?
    public let codeReviewRateLimit: CodexCodeReviewRateLimit?
    public let credits: CodexCredits?
    public let planType: String?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case additionalRateLimits = "additional_rate_limits"
        case codeReviewRateLimit = "code_review_rate_limit"
        case credits
        case planType = "plan_type"
    }

    public init(
        rateLimit: CodexRateLimit? = nil,
        additionalRateLimits: [CodexAdditionalRateLimit]? = nil,
        codeReviewRateLimit: CodexCodeReviewRateLimit? = nil,
        credits: CodexCredits? = nil,
        planType: String? = nil
    ) {
        self.rateLimit = rateLimit
        self.additionalRateLimits = additionalRateLimits
        self.codeReviewRateLimit = codeReviewRateLimit
        self.credits = credits
        self.planType = planType
    }
}

/// Primary rate limit containing session (5h) and weekly (7d) windows.
public struct CodexRateLimit: Codable, Sendable, Equatable {
    public let primaryWindow: CodexUsageWindow?
    public let secondaryWindow: CodexUsageWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }

    public init(
        primaryWindow: CodexUsageWindow? = nil,
        secondaryWindow: CodexUsageWindow? = nil
    ) {
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
    }
}

/// A single usage window (session or weekly).
public struct CodexUsageWindow: Codable, Sendable, Equatable {
    /// Utilization percentage (0–100).
    public let usedPercent: Double?
    /// Unix timestamp (seconds) when this window resets.
    public let resetAt: Double?
    /// Seconds until this window resets.
    public let resetAfterSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAt = "reset_at"
        case resetAfterSeconds = "reset_after_seconds"
    }

    public init(
        usedPercent: Double? = nil,
        resetAt: Double? = nil,
        resetAfterSeconds: Double? = nil
    ) {
        self.usedPercent = usedPercent
        self.resetAt = resetAt
        self.resetAfterSeconds = resetAfterSeconds
    }
}

/// Per-model additional rate limit.
public struct CodexAdditionalRateLimit: Codable, Sendable, Equatable {
    public let limitName: String?
    public let rateLimit: CodexRateLimit?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case rateLimit = "rate_limit"
    }

    public init(limitName: String? = nil, rateLimit: CodexRateLimit? = nil) {
        self.limitName = limitName
        self.rateLimit = rateLimit
    }
}

/// Code review rate limit (weekly only).
public struct CodexCodeReviewRateLimit: Codable, Sendable, Equatable {
    public let primaryWindow: CodexUsageWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
    }

    public init(primaryWindow: CodexUsageWindow? = nil) {
        self.primaryWindow = primaryWindow
    }
}

/// Credits balance information.
public struct CodexCredits: Codable, Sendable, Equatable {
    public let balance: Double?

    public init(balance: Double? = nil) {
        self.balance = balance
    }
}

// MARK: - Response Headers

/// Usage data extracted from HTTP response headers.
/// Headers take priority over body data per the OpenUsage plugin pattern.
public struct CodexUsageHeaders: Sendable, Equatable {
    /// Session (5h) used percentage from `x-codex-primary-used-percent`.
    public let primaryUsedPercent: Double?
    /// Weekly (7d) used percentage from `x-codex-secondary-used-percent`.
    public let secondaryUsedPercent: Double?
    /// Credits balance from `x-codex-credits-balance`.
    public let creditsBalance: Double?

    public init(
        primaryUsedPercent: Double? = nil,
        secondaryUsedPercent: Double? = nil,
        creditsBalance: Double? = nil
    ) {
        self.primaryUsedPercent = primaryUsedPercent
        self.secondaryUsedPercent = secondaryUsedPercent
        self.creditsBalance = creditsBalance
    }

    /// Extract usage headers from an HTTP response.
    public static func from(httpResponse: HTTPURLResponse) -> CodexUsageHeaders {
        CodexUsageHeaders(
            primaryUsedPercent: httpResponse.value(forHTTPHeaderField: "x-codex-primary-used-percent")
                .flatMap(Double.init),
            secondaryUsedPercent: httpResponse.value(forHTTPHeaderField: "x-codex-secondary-used-percent")
                .flatMap(Double.init),
            creditsBalance: httpResponse.value(forHTTPHeaderField: "x-codex-credits-balance")
                .flatMap(Double.init)
        )
    }
}

// MARK: - Display Model

/// Processed Codex usage data ready for display in UI / CLI.
/// Headers take priority over body values when both are available.
public struct CodexUsageSummary: Equatable, Sendable {
    /// Session (5h) used percentage (0–100).
    public let sessionUsedPercent: Int?
    /// Session reset date.
    public let sessionResetAt: Date?

    /// Weekly (7d) used percentage (0–100).
    public let weeklyUsedPercent: Int?
    /// Weekly reset date.
    public let weeklyResetAt: Date?

    /// Per-model additional rate limits.
    public let additionalLimits: [CodexAdditionalLimitSummary]

    /// Code review used percentage (weekly).
    public let codeReviewUsedPercent: Int?
    /// Code review reset date.
    public let codeReviewResetAt: Date?

    /// Credits balance.
    public let creditsBalance: Double?

    /// Plan type string (e.g. "free", "plus", "pro", "team", "enterprise").
    public let planType: String?

    public init(
        headers: CodexUsageHeaders,
        response: CodexUsageResponse
    ) {
        // Session: header takes priority
        if let headerPrimary = headers.primaryUsedPercent {
            self.sessionUsedPercent = Int(headerPrimary)
        } else {
            self.sessionUsedPercent = response.rateLimit?.primaryWindow?.usedPercent.map(Int.init)
        }
        self.sessionResetAt = response.rateLimit?.primaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }

        // Weekly: header takes priority
        if let headerSecondary = headers.secondaryUsedPercent {
            self.weeklyUsedPercent = Int(headerSecondary)
        } else {
            self.weeklyUsedPercent = response.rateLimit?.secondaryWindow?.usedPercent.map(Int.init)
        }
        self.weeklyResetAt = response.rateLimit?.secondaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }

        // Additional per-model limits
        self.additionalLimits = (response.additionalRateLimits ?? []).map {
            CodexAdditionalLimitSummary(from: $0)
        }

        // Code review
        self.codeReviewUsedPercent = response.codeReviewRateLimit?.primaryWindow?.usedPercent.map(Int.init)
        self.codeReviewResetAt = response.codeReviewRateLimit?.primaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }

        // Credits: header takes priority
        if let headerCredits = headers.creditsBalance {
            self.creditsBalance = headerCredits
        } else {
            self.creditsBalance = response.credits?.balance
        }

        self.planType = response.planType
    }

    /// Formatted plan name for display.
    public var planDisplayName: String {
        guard let plan = planType?.lowercased() else { return "Unknown" }
        switch plan {
        case "free": return "Free"
        case "plus": return "Plus"
        case "pro": return "Pro"
        case "team": return "Team"
        case "enterprise": return "Enterprise"
        default: return plan.capitalized
        }
    }

    /// Whether any additional per-model limits exist.
    public var hasAdditionalLimits: Bool { !additionalLimits.isEmpty }

    /// Whether code review data is present.
    public var hasCodeReview: Bool { codeReviewUsedPercent != nil }

    /// Whether credits data is present.
    public var hasCredits: Bool { creditsBalance != nil }
}

/// Processed per-model additional rate limit.
public struct CodexAdditionalLimitSummary: Equatable, Sendable {
    public let name: String
    /// Short name for display (e.g. "o1-pro" from "o1-pro rate limit").
    public let shortDisplayName: String
    public let sessionUsedPercent: Int?
    public let sessionResetAt: Date?
    public let weeklyUsedPercent: Int?
    public let weeklyResetAt: Date?

    public init(from limit: CodexAdditionalRateLimit) {
        self.name = limit.limitName ?? "Unknown"
        // Strip " rate limit" suffix for display
        let cleaned = self.name
            .replacingOccurrences(of: " rate limit", with: "")
            .replacingOccurrences(of: " Rate Limit", with: "")
        self.shortDisplayName = cleaned.isEmpty ? self.name : cleaned

        self.sessionUsedPercent = limit.rateLimit?.primaryWindow?.usedPercent.map(Int.init)
        self.sessionResetAt = limit.rateLimit?.primaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }
        self.weeklyUsedPercent = limit.rateLimit?.secondaryWindow?.usedPercent.map(Int.init)
        self.weeklyResetAt = limit.rateLimit?.secondaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }
    }
}

// MARK: - Reset Countdown Utility

extension Date {
    /// Human-readable countdown string from now to this date (e.g. "2h 30m", "3d 5h").
    public var countdownString: String? {
        let now = Date()
        guard self > now else { return "now" }

        let interval = self.timeIntervalSince(now)
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
