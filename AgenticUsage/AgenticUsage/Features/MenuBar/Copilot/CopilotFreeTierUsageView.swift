import SwiftUI
import AgenticCore

// MARK: - CopilotFreeTierUsageView

/// Copilot 免費方案的用量顯示，分別顯示 Chat 和 Completions 的配額進度與重設天數。
struct CopilotFreeTierUsageView: View {

    /// Copilot 用量摘要資料
    let summary: CopilotUsageSummary

    var body: some View {
        // Chat 配額進度
        if let chatRemaining = summary.freeChatRemaining,
           let chatTotal = summary.freeChatTotal, chatTotal > 0 {
            let chatUsed = chatTotal - chatRemaining
            let chatPercent = Double(chatUsed) / Double(chatTotal)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Chat")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(chatUsed) / \(chatTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressBarView(percentage: chatPercent)
            }
        }

        // Completions 配額進度
        if let compRemaining = summary.freeCompletionsRemaining,
           let compTotal = summary.freeCompletionsTotal, compTotal > 0 {
            let compUsed = compTotal - compRemaining
            let compPercent = Double(compUsed) / Double(compTotal)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Completions")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(compUsed) / \(compTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressBarView(percentage: compPercent)
            }
        }

        // 重設剩餘天數
        HStack {
            Spacer()
            VStack(alignment: .center) {
                Text("\(summary.daysUntilReset)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text("days until reset")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
