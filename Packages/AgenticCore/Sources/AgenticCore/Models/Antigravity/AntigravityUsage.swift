import Foundation

// MARK: - Antigravity 用量 API 回應

/// Cloud Code API 的用量回應結構。
public struct AntigravityUsageResponse: Codable, Sendable, Equatable {

    /// 模型名稱對應的模型資訊字典。
    public let models: [String: AntigravityModelInfo]?

    public init(models: [String: AntigravityModelInfo]? = nil) {
        self.models = models
    }
}

/// 單一模型的資訊。
public struct AntigravityModelInfo: Codable, Sendable, Equatable {

    /// 模型識別碼。
    public let model: String?

    /// 模型的顯示名稱。
    public let displayName: String?

    /// 是否為內部模型。
    public let isInternal: Bool?

    /// 配額資訊。
    public let quotaInfo: AntigravityQuotaInfo?

    public init(
        model: String? = nil,
        displayName: String? = nil,
        isInternal: Bool? = nil,
        quotaInfo: AntigravityQuotaInfo? = nil
    ) {
        self.model = model
        self.displayName = displayName
        self.isInternal = isInternal
        self.quotaInfo = quotaInfo
    }
}

/// 模型的配額資訊。
public struct AntigravityQuotaInfo: Codable, Sendable, Equatable {

    /// 剩餘配額比例（0.0–1.0）。
    public let remainingFraction: Double?

    /// 配額重置時間（ISO 8601 格式）。
    public let resetTime: String?

    public init(remainingFraction: Double? = nil, resetTime: String? = nil) {
        self.remainingFraction = remainingFraction
        self.resetTime = resetTime
    }
}

// MARK: - 單一模型用量摘要

/// 經處理的單一模型用量資料，可直接用於 UI 或 CLI 顯示。
public struct AntigravityModelUsageSummary: Equatable, Sendable, Identifiable {

    /// 模型識別碼。
    public let modelID: String

    /// 模型的顯示名稱。
    public let displayName: String

    /// 已使用百分比（0–100）。
    public let usedPercent: Int

    /// 配額重置日期。
    public let resetAt: Date?

    public var id: String { modelID }

    public init(modelID: String, displayName: String, usedPercent: Int, resetAt: Date?) {
        self.modelID = modelID
        self.displayName = displayName
        self.usedPercent = usedPercent
        self.resetAt = resetAt
    }
}

// MARK: - 整體用量摘要

/// 經處理的 Antigravity 整體用量資料，包含方案與逐模型配額。
public struct AntigravityUsageSummary: Equatable, Sendable {

    /// 訂閱方案類型（v1.7.0 始終為 nil）。
    public let plan: AntigravityPlan?

    /// 各模型的用量摘要列表。
    public let modelUsages: [AntigravityModelUsageSummary]

    /// 從 API 回應初始化用量摘要。
    ///
    /// 過濾黑名單與內部模型，計算已使用百分比，按 displayName 排序。
    ///
    /// - Parameters:
    ///   - plan: 訂閱方案。
    ///   - response: Cloud Code API 回應。
    public init(plan: AntigravityPlan?, response: AntigravityUsageResponse) {
        self.plan = plan

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFraction = ISO8601DateFormatter()
        isoFormatterNoFraction.formatOptions = [.withInternetDateTime]

        self.modelUsages = (response.models ?? [:])
            .compactMap { key, info -> AntigravityModelUsageSummary? in
                // 排除黑名單模型（檢查字典 key、model 欄位與 displayName）
                let modelID = info.model ?? key
                if AntigravityConstants.modelBlacklist.contains(key)
                    || AntigravityConstants.modelBlacklist.contains(modelID) {
                    return nil
                }
                if let displayName = info.displayName,
                   AntigravityConstants.displayNameBlacklist.contains(displayName) {
                    return nil
                }

                // 排除內部模型
                guard info.isInternal != true else {
                    return nil
                }

                // 需要有配額資訊
                guard let quota = info.quotaInfo,
                      let remainingFraction = quota.remainingFraction else { 
                    return nil
                }

                let usedPercent = Int(round((1.0 - remainingFraction) * 100.0))
                let resetDate: Date? = quota.resetTime.flatMap {
                    isoFormatter.date(from: $0) ?? isoFormatterNoFraction.date(from: $0)
                }

                return AntigravityModelUsageSummary(
                    modelID: key,
                    displayName: info.displayName ?? key,
                    usedPercent: max(0, min(100, usedPercent)),
                    resetAt: resetDate
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// 是否存在任何模型用量資料。
    public var hasUsageData: Bool { !modelUsages.isEmpty }
}
