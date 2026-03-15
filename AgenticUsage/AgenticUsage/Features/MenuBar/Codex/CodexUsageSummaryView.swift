import SwiftUI
import AgenticCore

// MARK: - CodexUsageSummaryView

/// Codex 用量摘要視圖，顯示各時間窗口、模型限制、Code Review 與 Credits。
///
/// 包含工作階段（5h）、每週（7d）兩種主要窗口，
/// 以及各模型額外限制、Code Review 配額與點數餘額。
struct CodexUsageSummaryView: View {

    /// Codex 用量摘要資料
    let summary: CodexUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 工作階段用量（5 小時窗口）
            if let pct = summary.sessionUsedPercent {
                ProgressRowView(
                    label: "Session (5h)",
                    usedPercent: pct,
                    countdown: summary.sessionResetAt?.countdownString
                )
            }

            // 每週用量（7 天窗口）
            if let pct = summary.weeklyUsedPercent {
                ProgressRowView(
                    label: "Weekly (7d)",
                    usedPercent: pct,
                    countdown: summary.weeklyResetAt?.countdownString
                )
            }

            // 各模型的額外限制（例如 o3-pro 獨立配額）
            if summary.hasAdditionalLimits {
                ForEach(Array(summary.additionalLimits.enumerated()), id: \.offset) { _, limit in
                    if let pct = limit.sessionUsedPercent {
                        ProgressRowView(
                            label: "\(limit.shortDisplayName) (5h)",
                            usedPercent: pct,
                            countdown: limit.sessionResetAt?.countdownString
                        )
                    }
                    if let pct = limit.weeklyUsedPercent {
                        ProgressRowView(
                            label: "\(limit.shortDisplayName) (7d)",
                            usedPercent: pct,
                            countdown: limit.weeklyResetAt?.countdownString
                        )
                    }
                }
            }

            // Code Review 用量（7 天窗口）
            if let pct = summary.codeReviewUsedPercent {
                ProgressRowView(
                    label: "Code Reviews (7d)",
                    usedPercent: pct,
                    countdown: summary.codeReviewResetAt?.countdownString
                )
            }

            // 點數餘額（使用 FormatStyle API 格式化數字）
            if let balance = summary.creditsBalance {
                HStack {
                    Text("Credits")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(
                        "\(balance.formatted(.number.precision(.fractionLength(0)))) / 1,000"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }
}
