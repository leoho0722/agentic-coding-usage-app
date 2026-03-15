import SwiftUI
import AgenticCore

// MARK: - AntigravityUsageSummaryView

/// Antigravity 用量摘要視圖，顯示各模型的配額進度。
///
/// 每個模型獨立顯示用量百分比與重設倒數；若無資料則顯示提示文字。
struct AntigravityUsageSummaryView: View {

    /// Antigravity 用量摘要資料
    let summary: AntigravityUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.hasUsageData {
                // 各模型配額進度列
                ForEach(summary.modelUsages) { modelUsage in
                    ProgressRowView(
                        label: "\(modelUsage.displayName)",
                        usedPercent: modelUsage.usedPercent,
                        countdown: modelUsage.resetAt?.countdownString
                    )
                }
            } else {
                Text("No model usage data available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}
