import Foundation

// MARK: - Codex 用量 API 回應（Body）

/// Codex 用量 API 的原始回應 Body 結構。
///
/// 端點：`GET https://chatgpt.com/backend-api/wham/usage`
public struct CodexUsageResponse: Codable, Sendable, Equatable {
    
    /// 主要速率限制（包含工作階段與每週視窗）。
    public let rateLimit: CodexRateLimit?
    
    /// 各模型的額外速率限制。
    public let additionalRateLimits: [CodexAdditionalRateLimit]?
    
    /// 程式碼審查的速率限制。
    public let codeReviewRateLimit: CodexCodeReviewRateLimit?
    
    /// 額度餘額資訊。
    public let credits: CodexCredits?
    
    /// 方案類型字串（例如 `"free"`、`"plus"`、`"pro"`）。
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

/// 主要速率限制，包含工作階段（5 小時）與每週（7 天）視窗。
public struct CodexRateLimit: Codable, Sendable, Equatable {
    
    /// 主要視窗（工作階段，5 小時）。
    public let primaryWindow: CodexUsageWindow?
    
    /// 次要視窗（每週，7 天）。
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

/// 單一用量視窗（工作階段或每週）。
public struct CodexUsageWindow: Codable, Sendable, Equatable {
    
    
    /// 使用率百分比（0 至 100）。
    public let usedPercent: Double?
    
    
    /// 此視窗重置的 Unix 時間戳記（秒）。
    public let resetAt: Double?
    
    
    /// 距離此視窗重置的秒數。
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

/// 各模型的額外速率限制。
public struct CodexAdditionalRateLimit: Codable, Sendable, Equatable {
    
    /// 限制名稱（例如 `"o1-pro rate limit"`）。
    public let limitName: String?
    
    /// 該模型的速率限制。
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

/// 程式碼審查的速率限制（僅每週視窗）。
public struct CodexCodeReviewRateLimit: Codable, Sendable, Equatable {
    
    /// 主要視窗（每週）。
    public let primaryWindow: CodexUsageWindow?
    
    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
    }
    
    public init(primaryWindow: CodexUsageWindow? = nil) {
        self.primaryWindow = primaryWindow
    }
}

/// 額度餘額資訊。
public struct CodexCredits: Codable, Sendable, Equatable {
    
    /// 目前的額度餘額。
    public let balance: Double?
    
    public init(balance: Double? = nil) {
        self.balance = balance
    }
}

// MARK: - 回應標頭

/// 從 HTTP 回應標頭擷取的用量資料。
///
/// 依據 OpenUsage 外掛模式，標頭資料優先於 Body 資料。
public struct CodexUsageHeaders: Sendable, Equatable {
    
    /// 工作階段（5 小時）使用百分比，來自 `x-codex-primary-used-percent`。
    public let primaryUsedPercent: Double?
    
    /// 每週（7 天）使用百分比，來自 `x-codex-secondary-used-percent`。
    public let secondaryUsedPercent: Double?
    
    /// 額度餘額，來自 `x-codex-credits-balance`。
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
    
    /// 從 HTTP 回應中擷取用量標頭。
    ///
    /// - Parameter httpResponse: HTTP 回應物件。
    /// - Returns: 解析後的用量標頭資料。
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

// MARK: - 顯示模型

/// 經處理的 Codex 用量資料，可直接用於 UI 或 CLI 顯示。
///
/// 當標頭與 Body 同時存在時，標頭資料優先使用。
public struct CodexUsageSummary: Equatable, Sendable {
    
    /// 工作階段（5 小時）使用百分比（0 至 100）。
    public let sessionUsedPercent: Int?
    
    /// 工作階段的重置日期。
    public let sessionResetAt: Date?
    
    /// 每週（7 天）使用百分比（0 至 100）。
    public let weeklyUsedPercent: Int?
    
    /// 每週的重置日期。
    public let weeklyResetAt: Date?
    
    /// 各模型的額外速率限制摘要。
    public let additionalLimits: [CodexAdditionalLimitSummary]
    
    /// 程式碼審查使用百分比（每週）。
    public let codeReviewUsedPercent: Int?
    
    /// 程式碼審查的重置日期。
    public let codeReviewResetAt: Date?
    
    /// 額度餘額。
    public let creditsBalance: Double?
    
    /// 方案類型字串（例如 `"free"`、`"plus"`、`"pro"`、`"team"`、`"enterprise"`）。
    public let planType: String?
    
    /// 從回應標頭與 Body 初始化用量摘要。
    ///
    /// - Parameters:
    ///   - headers: HTTP 回應標頭中的用量資料。
    ///   - response: API 回應 Body 中的用量資料。
    public init(
        headers: CodexUsageHeaders,
        response: CodexUsageResponse
    ) {
        // 工作階段：標頭優先
        if let headerPrimary = headers.primaryUsedPercent {
            self.sessionUsedPercent = Int(headerPrimary)
        } else {
            self.sessionUsedPercent = response.rateLimit?.primaryWindow?.usedPercent.map(Int.init)
        }
        self.sessionResetAt = response.rateLimit?.primaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }
        
        // 每週：標頭優先
        if let headerSecondary = headers.secondaryUsedPercent {
            self.weeklyUsedPercent = Int(headerSecondary)
        } else {
            self.weeklyUsedPercent = response.rateLimit?.secondaryWindow?.usedPercent.map(Int.init)
        }
        self.weeklyResetAt = response.rateLimit?.secondaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }
        
        // 各模型的額外限制
        self.additionalLimits = (response.additionalRateLimits ?? []).map {
            CodexAdditionalLimitSummary(from: $0)
        }
        
        // 程式碼審查
        self.codeReviewUsedPercent = response.codeReviewRateLimit?.primaryWindow?.usedPercent.map(Int.init)
        self.codeReviewResetAt = response.codeReviewRateLimit?.primaryWindow?.resetAt.map {
            Date(timeIntervalSince1970: $0)
        }
        
        // 額度：標頭優先
        if let headerCredits = headers.creditsBalance {
            self.creditsBalance = headerCredits
        } else {
            self.creditsBalance = response.credits?.balance
        }
        
        self.planType = response.planType
    }
    
    /// 格式化的方案名稱，用於 UI 顯示。
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
    
    /// 是否存在各模型的額外限制資料。
    public var hasAdditionalLimits: Bool { !additionalLimits.isEmpty }
    
    /// 是否存在程式碼審查資料。
    public var hasCodeReview: Bool { codeReviewUsedPercent != nil }
    
    /// 是否存在額度資料。
    public var hasCredits: Bool { creditsBalance != nil }
}

/// 經處理的各模型額外速率限制摘要。
public struct CodexAdditionalLimitSummary: Equatable, Sendable {
    
    /// 限制名稱。
    public let name: String
    
    /// 用於 UI 顯示的簡短名稱（例如從 `"o1-pro rate limit"` 取得 `"o1-pro"`）。
    public let shortDisplayName: String
    
    /// 工作階段使用百分比。
    public let sessionUsedPercent: Int?
    
    /// 工作階段的重置日期。
    public let sessionResetAt: Date?
    
    /// 每週使用百分比。
    public let weeklyUsedPercent: Int?
    
    /// 每週的重置日期。
    public let weeklyResetAt: Date?
    
    /// 從額外速率限制資料初始化摘要。
    ///
    /// - Parameter limit: 額外速率限制的原始資料。
    public init(from limit: CodexAdditionalRateLimit) {
        self.name = limit.limitName ?? "Unknown"
        // 移除 " rate limit" 後綴以供顯示使用
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

// MARK: - 重置倒數工具

extension Date {
    
    /// 從現在到此日期的倒數計時字串（例如 `"2h 30m"`、`"3d 5h"`）。
    public var countdownString: String? {
        let now = Date()
        guard self > now else {
            return "now"
        }
        
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
