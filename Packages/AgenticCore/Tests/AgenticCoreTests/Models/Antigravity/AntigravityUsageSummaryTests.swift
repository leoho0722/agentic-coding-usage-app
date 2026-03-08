import Foundation
import Testing

@testable import AgenticCore

@Suite("AntigravityUsageSummary")
struct AntigravityUsageSummaryTests {

    // MARK: - Blacklist filtering

    /// 驗證以 key 匹配黑名單的模型會被過濾掉
    @Test
    func filtersBlacklistedModelByKey() {
        let response = AntigravityUsageResponse(models: [
            "MODEL_CHAT_20706": AntigravityModelInfo(
                displayName: "Chat Model",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
            "valid_model": AntigravityModelInfo(
                displayName: "Valid Model",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.8)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.count == 1)
        #expect(summary.modelUsages.first?.modelID == "valid_model")
    }

    /// 驗證以 model 欄位匹配黑名單的模型會被過濾掉
    @Test
    func filtersBlacklistedModelByModelField() {
        let response = AntigravityUsageResponse(models: [
            "some_key": AntigravityModelInfo(
                model: "MODEL_GOOGLE_GEMINI_2_5_PRO",
                displayName: "Some Name",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.isEmpty)
    }

    /// 驗證以 displayName 匹配黑名單的模型會被過濾掉
    @Test
    func filtersBlacklistedDisplayName() {
        let response = AntigravityUsageResponse(models: [
            "key1": AntigravityModelInfo(
                displayName: "Gemini 2.5 Flash",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.isEmpty)
    }

    /// 驗證標記為 internal 的模型會被過濾掉
    @Test
    func filtersInternalModels() {
        let response = AntigravityUsageResponse(models: [
            "internal_model": AntigravityModelInfo(
                displayName: "Internal",
                isInternal: true,
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.isEmpty)
    }

    /// 驗證缺少 quotaInfo 的模型會被過濾掉
    @Test
    func filtersModelsWithoutQuotaInfo() {
        let response = AntigravityUsageResponse(models: [
            "no_quota": AntigravityModelInfo(displayName: "No Quota"),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.isEmpty)
    }

    // MARK: - usedPercent calculation

    /// 驗證 usedPercent 從 remainingFraction 正確計算使用百分比
    @Test
    func usedPercent_calculation() {
        let response = AntigravityUsageResponse(models: [
            "model_a": AntigravityModelInfo(
                displayName: "Model A",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.75)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.first?.usedPercent == 25)
    }

    /// 驗證 remainingFraction 為 0 時 usedPercent 為 100
    @Test
    func usedPercent_fullyUsed() {
        let response = AntigravityUsageResponse(models: [
            "model_a": AntigravityModelInfo(
                displayName: "Model A",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.0)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.first?.usedPercent == 100)
    }

    /// 驗證 remainingFraction 超過 1.0 時 usedPercent 被箝位至 0
    @Test
    func usedPercent_clamped() {
        // remainingFraction > 1.0 should clamp to 0% used
        let response = AntigravityUsageResponse(models: [
            "model_a": AntigravityModelInfo(
                displayName: "Model A",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 1.5)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.first?.usedPercent == 0)
    }

    // MARK: - Sorting

    /// 驗證模型使用量依 displayName 字母順序排序
    @Test
    func sortedByDisplayName() {
        let response = AntigravityUsageResponse(models: [
            "z_model": AntigravityModelInfo(
                displayName: "Zebra Model",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
            "a_model": AntigravityModelInfo(
                displayName: "Alpha Model",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
            "m_model": AntigravityModelInfo(
                displayName: "Middle Model",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        let names = summary.modelUsages.map(\.displayName)
        #expect(names == ["Alpha Model", "Middle Model", "Zebra Model"])
    }

    // MARK: - hasUsageData

    /// 驗證有有效模型時 hasUsageData 回傳 true
    @Test
    func hasUsageData_withModels_true() {
        let response = AntigravityUsageResponse(models: [
            "m": AntigravityModelInfo(
                displayName: "M",
                quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.5)
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.hasUsageData == true)
    }

    /// 驗證模型字典為空時 hasUsageData 回傳 false
    @Test
    func hasUsageData_empty_false() {
        let response = AntigravityUsageResponse(models: [:])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.hasUsageData == false)
    }

    /// 驗證模型字典為 nil 時 hasUsageData 回傳 false
    @Test
    func hasUsageData_nilModels_false() {
        let response = AntigravityUsageResponse(models: nil)
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.hasUsageData == false)
    }

    // MARK: - Reset date parsing

    /// 驗證標準 ISO 8601 格式的重置時間能正確解析
    @Test
    func resetDate_iso8601() {
        let response = AntigravityUsageResponse(models: [
            "m": AntigravityModelInfo(
                displayName: "M",
                quotaInfo: AntigravityQuotaInfo(
                    remainingFraction: 0.5,
                    resetTime: "2025-03-08T12:00:00Z"
                )
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.first?.resetAt != nil)
    }

    /// 驗證含有毫秒的 ISO 8601 格式重置時間能正確解析
    @Test
    func resetDate_withFractionalSeconds() {
        let response = AntigravityUsageResponse(models: [
            "m": AntigravityModelInfo(
                displayName: "M",
                quotaInfo: AntigravityQuotaInfo(
                    remainingFraction: 0.5,
                    resetTime: "2025-03-08T12:00:00.500Z"
                )
            ),
        ])
        let summary = AntigravityUsageSummary(plan: nil, response: response)
        #expect(summary.modelUsages.first?.resetAt != nil)
    }
}
