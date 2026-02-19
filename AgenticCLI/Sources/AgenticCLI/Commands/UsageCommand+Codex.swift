import Foundation
import AgenticCore

// MARK: - Codex 用量

extension UsageCommand {

    /// 查詢並印出 OpenAI Codex 的用量資訊。
    ///
    /// 從環境變數取得 OAuth Client ID，載入本機憑證，
    /// 必要時重新整理權杖後查詢用量 API。
    ///
    /// - Throws: 當憑證重新整理或 API 請求失敗時拋出錯誤。
    func printCodexUsage() async throws {
        let clientID = ProcessInfo.processInfo.environment["AGENTIC_CODEX_CLIENT_ID"]
            ?? CodexConstants.defaultClientID

        let codexClient = CodexAPIClient.live(clientID: clientID)

        guard let credentials = try codexClient.loadCredentials() else {
            print("  [Codex] Credentials not found. Run 'codex auth login' in terminal first.")
            return
        }

        // 必要時重新整理存取權杖
        let refreshed = try await codexClient.refreshTokenIfNeeded(credentials)
        let (headers, response) = try await codexClient.fetchUsage(
            refreshed.accessToken, refreshed.accountId,
        )
        let summary = CodexUsageSummary(headers: headers, response: response)

        printCodexDisplay(summary: summary)
    }

    /// 格式化並印出 Codex 的用量顯示內容。
    ///
    /// 依序顯示工作階段、每週、各模型額外限制、Code Review 的進度條，
    /// 以及剩餘點數。
    ///
    /// - Parameter summary: Codex 用量摘要。
    private func printCodexDisplay(summary: CodexUsageSummary) {
        let barWidth = 30

        print()
        print("  OpenAI Codex Usage")
        print("  Plan: \(summary.plan?.badgeLabel ?? "Unknown")")
        print()

        // 工作階段用量（5 小時週期）
        if let pct = summary.sessionUsedPercent {
            printProgressBar(label: "Session (5h)", percentage: pct, barWidth: barWidth)
            if let countdown = summary.sessionResetAt?.countdownString {
                print("               Resets in: \(countdown)")
            }
        }

        // 每週用量（7 天週期）
        if let pct = summary.weeklyUsedPercent {
            printProgressBar(label: "Weekly  (7d)", percentage: pct, barWidth: barWidth)
            if let countdown = summary.weeklyResetAt?.countdownString {
                print("               Resets in: \(countdown)")
            }
        }

        // 各模型的額外速率限制
        for limit in summary.additionalLimits {
            if let pct = limit.sessionUsedPercent {
                let label = String(format: "%-12s", ("\(limit.shortDisplayName) (5h)" as NSString).utf8String!)
                printProgressBar(label: label, percentage: pct, barWidth: barWidth)
                if let countdown = limit.sessionResetAt?.countdownString {
                    print("               Resets in: \(countdown)")
                }
            }
            if let pct = limit.weeklyUsedPercent {
                let label = String(format: "%-12s", ("\(limit.shortDisplayName) (7d)" as NSString).utf8String!)
                printProgressBar(label: label, percentage: pct, barWidth: barWidth)
                if let countdown = limit.weeklyResetAt?.countdownString {
                    print("               Resets in: \(countdown)")
                }
            }
        }

        // Code Review 用量
        if let pct = summary.codeReviewUsedPercent {
            printProgressBar(label: "Reviews (7d)", percentage: pct, barWidth: barWidth)
            if let countdown = summary.codeReviewResetAt?.countdownString {
                print("               Resets in: \(countdown)")
            }
        }

        // 剩餘點數餘額
        if let balance = summary.creditsBalance {
            print(String(format: "  Credits:     %.0f / 1,000", balance))
        }

        print()
    }
}
