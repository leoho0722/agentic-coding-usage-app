import SwiftUI
import AgenticCore

// MARK: - CopilotPaidTierUsageView

/// Copilot 付費方案的用量顯示，包含 Premium Requests 進度條與統計數據列。
struct CopilotPaidTierUsageView: View {

    /// Copilot 用量摘要資料
    let summary: CopilotUsageSummary

    var body: some View {
        // Premium Requests 進度條
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Premium Requests")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(summary.premiumRequestsUsed) / \(summary.planLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressBarView(percentage: summary.usagePercentage)
        }

        // 統計數據列：剩餘次數、已使用百分比、重設剩餘天數
        HStack {
            VStack(alignment: .leading) {
                Text("\(summary.remaining)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text("remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .center) {
                Text("\(Int(summary.usagePercentage * 100))%")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(ProgressBarView.color(for: summary.usagePercentage))
                Text("used")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(summary.daysUntilReset)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text("days left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
