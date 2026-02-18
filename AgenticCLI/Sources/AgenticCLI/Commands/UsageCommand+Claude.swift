import Foundation
import AgenticCore

// MARK: - Claude Code 用量

extension UsageCommand {

    /// 查詢並印出 Claude Code 的用量資訊。
    ///
    /// 從環境變數取得 OAuth Client ID，載入本機憑證，
    /// 必要時重新整理權杖後查詢用量 API。
    ///
    /// - Throws: 當憑證重新整理或 API 請求失敗時拋出錯誤。
    func printClaudeUsage() async throws {
        guard let clientID = ProcessInfo.processInfo.environment["AGENTIC_CLAUDE_CLIENT_ID"],
              !clientID.isEmpty else {
            print("  [Claude Code] AGENTIC_CLAUDE_CLIENT_ID environment variable is required.")
            print("  Set it to Claude Code's OAuth client ID for token refresh.")
            return
        }

        let claudeClient = ClaudeAPIClient.live(clientID: clientID)

        guard let credentials = try claudeClient.loadCredentials() else {
            print("  [Claude Code] Credentials not found. Run 'claude login' in terminal first.")
            return
        }

        // 必要時重新整理存取權杖
        let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
        let response = try await claudeClient.fetchUsage(refreshed.accessToken)
        let summary = ClaudeUsageSummary(
            subscriptionType: refreshed.subscriptionType,
            response: response,
        )

        printClaudeDisplay(summary: summary)
    }

    /// 格式化並印出 Claude Code 的用量顯示內容。
    ///
    /// 依序顯示工作階段（5 小時）、每週（7 天）、Opus（7 天）的進度條，
    /// 以及額外用量（若有）。
    ///
    /// - Parameter summary: Claude Code 用量摘要。
    private func printClaudeDisplay(summary: ClaudeUsageSummary) {
        let barWidth = 30

        print()
        print("  Claude Code Usage")
        print("  Plan: \(summary.planDisplayName)")
        print()

        // 工作階段用量（5 小時週期）
        if let pct = summary.sessionUtilization {
            printProgressBar(label: "Session (5h)", percentage: pct, barWidth: barWidth)
            if let resetsAt = summary.sessionResetsAt {
                let countdown = ClaudeUsagePeriod(utilization: pct, resetsAt: resetsAt).resetCountdown ?? "?"
                print("               Resets in: \(countdown)")
            }
        }

        // 每週用量（7 天週期）
        if let pct = summary.weeklyUtilization {
            printProgressBar(label: "Weekly  (7d)", percentage: pct, barWidth: barWidth)
            if let resetsAt = summary.weeklyResetsAt {
                let countdown = ClaudeUsagePeriod(utilization: pct, resetsAt: resetsAt).resetCountdown ?? "?"
                print("               Resets in: \(countdown)")
            }
        }

        // Opus 模型用量（7 天週期），僅在有資料時顯示
        if let pct = summary.opusUtilization {
            printProgressBar(label: "Opus    (7d)", percentage: pct, barWidth: barWidth)
            if let resetsAt = summary.opusResetsAt {
                let countdown = ClaudeUsagePeriod(utilization: pct, resetsAt: resetsAt).resetCountdown ?? "?"
                print("               Resets in: \(countdown)")
            }
        }

        // 額外用量（超出基本配額的費用）
        if summary.hasExtraUsage,
           let used = summary.extraUsageUsedDollars,
           let limit = summary.extraUsageLimitDollars {
            print(String(format: "  Extra Usage: $%.2f / $%.2f", used, limit))
        }

        print()
    }
}
