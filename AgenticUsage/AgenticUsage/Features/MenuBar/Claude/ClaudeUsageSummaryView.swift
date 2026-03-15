import SwiftUI
import AgenticCore

// MARK: - ClaudeUsageSummaryView

/// Claude Code 用量摘要視圖，顯示各時間窗口的使用百分比與額外用量。
///
/// 包含工作階段（5h）、每週（7d）、Opus 模型（7d）三種窗口，
/// 以及選擇性顯示的額外用量金額（使用 `.currency(code:)` FormatStyle 格式化）。
struct ClaudeUsageSummaryView: View {

    /// Claude Code 用量摘要資料
    let summary: ClaudeUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 工作階段用量（5 小時窗口）
            if let pct = summary.sessionUtilization {
                ProgressRowView(
                    label: "Session (5h)",
                    usedPercent: pct,
                    countdown: summary.sessionResetsAt.flatMap {
                        ClaudeUsagePeriod(utilization: Double(pct), resetsAt: $0).resetCountdown
                    }
                )
            }

            // 每週用量（7 天窗口）
            if let pct = summary.weeklyUtilization {
                ProgressRowView(
                    label: "Weekly (7d)",
                    usedPercent: pct,
                    countdown: summary.weeklyResetsAt.flatMap {
                        ClaudeUsagePeriod(utilization: Double(pct), resetsAt: $0).resetCountdown
                    }
                )
            }

            // Opus 模型用量（7 天窗口），僅在有資料時顯示
            if let pct = summary.opusUtilization {
                ProgressRowView(
                    label: "Opus (7d)",
                    usedPercent: pct,
                    countdown: summary.opusResetsAt.flatMap {
                        ClaudeUsagePeriod(utilization: Double(pct), resetsAt: $0).resetCountdown
                    }
                )
            }

            // 額外用量，僅在啟用時顯示（使用 FormatStyle API 格式化貨幣）
            if summary.hasExtraUsage {
                HStack {
                    Text("Extra Usage")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    if let used = summary.extraUsageUsedDollars,
                       let limit = summary.extraUsageLimitDollars {
                        Text(
                            "\(used.formatted(.currency(code: "USD"))) / \(limit.formatted(.currency(code: "USD")))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }
}
