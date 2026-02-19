import Foundation

// MARK: - Claude 用量 API 回應

/// Claude 用量 API 的原始回應結構。
///
/// 端點：`GET https://api.anthropic.com/api/oauth/usage`
public struct ClaudeUsageResponse: Codable, Sendable, Equatable {
    
    /// 工作階段用量視窗（5 小時）。
    public let fiveHour: ClaudeUsagePeriod?
    
    /// 每週用量視窗（7 天）。
    public let sevenDay: ClaudeUsagePeriod?
    
    /// Opus 每週用量視窗（7 天，依方案而異）。
    public let sevenDayOpus: ClaudeUsagePeriod?
    
    /// 額外用量資訊（超出方案內含配額的部分）。
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

/// 單一使用率視窗（例如工作階段 5 小時、每週 7 天）。
public struct ClaudeUsagePeriod: Codable, Sendable, Equatable {
    
    /// 使用率百分比，整數 0 至 100。
    public let utilization: Int
    
    /// 此視窗重置的 ISO 8601 時間戳記。
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

/// 額外用量資訊（超出方案內含配額後計費的部分）。
public struct ClaudeExtraUsage: Codable, Sendable, Equatable {
    
    /// 此帳號是否啟用額外用量。
    public let isEnabled: Bool
    
    /// 已使用的額度（單位：美分，除以 100 為美元）。
    public let usedCredits: Int?
    
    /// 每月額度上限（單位：美分）。
    public let monthlyLimit: Int?
    
    /// 幣別代碼（例如 `"USD"`）。
    public let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
        case currency
    }
    
    public init(
        isEnabled: Bool,
        usedCredits: Int? = nil,
        monthlyLimit: Int? = nil,
        currency: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.usedCredits = usedCredits
        self.monthlyLimit = monthlyLimit
        self.currency = currency
    }
}

// MARK: - 顯示模型

/// 經處理的 Claude Code 用量資料，可直接用於 UI 或 CLI 顯示。
public struct ClaudeUsageSummary: Equatable, Sendable {
    
    /// 訂閱方案類型。
    public let plan: ClaudePlan?
    
    /// 工作階段（5 小時）使用率百分比（0 至 100），無資料時為 `nil`。
    public let sessionUtilization: Int?
    
    /// 工作階段重置的 ISO 時間戳記。
    public let sessionResetsAt: String?
    
    /// 每週（7 天）使用率百分比（0 至 100），無資料時為 `nil`。
    public let weeklyUtilization: Int?
    
    /// 每週重置的 ISO 時間戳記。
    public let weeklyResetsAt: String?
    
    /// Opus（7 天）使用率百分比（0 至 100），方案不包含時為 `nil`。
    public let opusUtilization: Int?
    
    /// Opus 重置的 ISO 時間戳記。
    public let opusResetsAt: String?
    
    /// 是否啟用額外用量。
    public let extraUsageEnabled: Bool
    
    /// 已使用的額外用量（單位：美分）。
    public let extraUsageUsedCents: Int?
    
    /// 每月額外用量上限（單位：美分）。
    public let extraUsageLimitCents: Int?
    
    /// 額外用量的幣別。
    public let extraUsageCurrency: String?
    
    /// 從 API 回應初始化用量摘要。
    ///
    /// - Parameters:
    ///   - plan: 訂閱方案類型。
    ///   - response: Claude 用量 API 的原始回應。
    public init(
        plan: ClaudePlan?,
        response: ClaudeUsageResponse
    ) {
        self.plan = plan
        
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
    
    /// 是否包含 Opus 資料（依方案而異）。
    public var hasOpus: Bool { opusUtilization != nil }
    
    /// 是否應顯示額外用量區塊。
    public var hasExtraUsage: Bool { extraUsageEnabled }
    
    /// 已使用的額外用量金額（單位：美元，例如 5.00）。
    public var extraUsageUsedDollars: Double? {
        guard let cents = extraUsageUsedCents else { return nil }
        return Double(cents) / 100.0
    }
    
    /// 每月額外用量上限（單位：美元）。
    public var extraUsageLimitDollars: Double? {
        guard let cents = extraUsageLimitCents else { return nil }
        return Double(cents) / 100.0
    }
}

// MARK: - 重置時間工具

extension ClaudeUsagePeriod {
    
    /// 將 `resetsAt` 解析為 `Date`。
    public var resetsAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }
    
    /// 距離重置時間的倒數計時字串（例如 `"2h 30m"`、`"3d 5h"`）。
    public var resetCountdown: String? {
        guard let resetDate = resetsAtDate else {
            return nil
        }
        let now = Date()
        guard resetDate > now else {
            return "now"
        }
        
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
