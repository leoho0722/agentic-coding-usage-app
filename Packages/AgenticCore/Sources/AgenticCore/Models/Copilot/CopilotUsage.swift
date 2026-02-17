import Foundation

// MARK: - Copilot 用量摘要

/// Copilot 彙總用量摘要，用於 UI 顯示。
///
/// 同時支援內部 API 的百分比格式（付費方案）與次數格式（免費方案）資料。
public struct CopilotUsageSummary: Equatable, Sendable {
    
    /// 從內部 API 自動偵測的訂閱方案。
    public let plan: CopilotPlan
    
    /// 此方案每月的進階請求配額上限。
    public let planLimit: Int
    
    /// 距離用量計數器重置的天數。
    public let daysUntilReset: Int

    // MARK: - 付費方案欄位（來自 quota_snapshots）

    /// 進階請求的剩餘百分比（0.0 至 1.0）。免費方案為 `nil`。
    public let premiumPercentRemaining: Double?

    // MARK: - 免費方案欄位（來自 limited_user_quotas）

    /// 聊天功能的剩餘次數（免費方案）。付費方案為 `nil`。
    public let freeChatRemaining: Int?
   
    /// 聊天功能的每月總配額（免費方案）。付費方案為 `nil`。
    public let freeChatTotal: Int?
  
    /// 程式碼補全的剩餘次數（免費方案）。付費方案為 `nil`。
    public let freeCompletionsRemaining: Int?
   
    /// 程式碼補全的每月總配額（免費方案）。付費方案為 `nil`。
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

    /// 是否為免費方案使用者。
    public var isFreeTier: Bool {
        plan == .free
    }

    /// 用於 UI 顯示的使用百分比（0.0 至 1.0），表示已使用的比例而非剩餘比例。
    ///
    /// - 付費方案：由 `premiumPercentRemaining` 推算。
    /// - 免費方案：由聊天功能的剩餘/總量推算。
    public var usagePercentage: Double {
        if let premiumPercentRemaining {
            return max(0, min(1.0, (100.0 - premiumPercentRemaining) / 100.0))
        }
        if let remaining = freeChatRemaining, let total = freeChatTotal, total > 0 {
            return max(0, min(1.0, Double(total - remaining) / Double(total)))
        }
        return 0
    }

    /// 預估已使用的進階請求次數（僅限付費方案）。
    public var premiumRequestsUsed: Int {
        if let premiumPercentRemaining {
            let usedPercent = max(0, min(100, 100.0 - premiumPercentRemaining))
            return Int(round(Double(planLimit) * usedPercent / 100.0))
        }
        return 0
    }

    /// 預估剩餘的進階請求次數（僅限付費方案）。
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
