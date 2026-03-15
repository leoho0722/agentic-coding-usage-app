import SwiftUI
import AgenticCore

// MARK: - CopilotUsageSummaryView

/// Copilot 用量摘要視圖，依方案類型切換免費/付費的顯示佈局。
///
/// 免費方案顯示 Chat 與 Completions 配額；付費方案顯示 Premium Requests 進度條與統計。
struct CopilotUsageSummaryView: View {

    /// Copilot 用量摘要資料
    let summary: CopilotUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.isFreeTier {
                CopilotFreeTierUsageView(summary: summary)
            } else {
                CopilotPaidTierUsageView(summary: summary)
            }
        }
        .padding(12)
    }
}
