import Foundation
import AgenticCore
import ArgumentParser

// MARK: - UsageCommand

/// 顯示 AI 程式碼輔助工具用量的 CLI 子指令。
///
/// 支援查詢 Copilot、Claude Code、Codex 的用量，
/// 可透過 `--tool` 參數篩選特定工具或顯示全部。
struct UsageCommand: AsyncParsableCommand {

    /// CLI 指令的組態設定。
    static let configuration = CommandConfiguration(
        commandName: "usage",
        abstract: "Show your AI coding assistant usage for the current period.",
    )

    /// 要顯示用量的工具名稱，支援 `copilot`、`claude`、`codex` 或 `all`。
    @Option(name: .long, help: "Tool to show usage for: copilot, claude, codex, or all (default: all).")
    var tool: String = "all"

    /// 依據篩選條件查詢並顯示各工具的用量資訊。
    ///
    /// 依序查詢 Copilot、Claude Code、Codex 的用量。
    /// 當篩選特定工具時，該工具的錯誤會直接拋出；
    /// 當顯示全部時，個別工具的錯誤僅印出訊息而不中斷流程。
    ///
    /// - Throws: 當工具名稱無效或所有工具均無可用資料時拋出錯誤。
    func run() async throws {
        let toolFilter = tool.lowercased()

        guard ["all", "copilot", "claude", "codex"].contains(toolFilter) else {
            print("Error: Unknown tool '\(tool)'. Use 'copilot', 'claude', 'codex', or 'all'.")
            throw ExitCode.failure
        }

        // 追蹤是否有任何工具成功印出用量資訊
        var printed = false

        // 查詢 Copilot 用量
        if toolFilter == "all" || toolFilter == "copilot" {
            do {
                try await printCopilotUsage()
                printed = true
            } catch {
                // 僅篩選特定工具時才將錯誤往上拋出
                if toolFilter == "copilot" {
                    throw error
                }
                print("  [Copilot] \(error.localizedDescription)")
                print()
            }
        }

        // 查詢 Claude Code 用量
        if toolFilter == "all" || toolFilter == "claude" {
            if printed { print(String(repeating: "─", count: 40)); print() }
            do {
                try await printClaudeUsage()
                printed = true
            } catch {
                if toolFilter == "claude" {
                    throw error
                }
                print("  [Claude Code] \(error.localizedDescription)")
                print()
            }
        }

        // 查詢 Codex 用量
        if toolFilter == "all" || toolFilter == "codex" {
            if printed { print(String(repeating: "─", count: 40)); print() }
            do {
                try await printCodexUsage()
                printed = true
            } catch {
                if toolFilter == "codex" {
                    throw error
                }
                print("  [Codex] \(error.localizedDescription)")
                print()
            }
        }

        if !printed {
            print("No usage data available. Make sure you're logged in.")
            throw ExitCode.failure
        }
    }

    // MARK: - Copilot

    /// 查詢並印出 GitHub Copilot 的用量資訊。
    ///
    /// 從鑰匙圈載入存取權杖，取得使用者資訊與 Copilot 狀態，
    /// 再依據方案類型（免費版 / 付費版）組裝用量摘要。
    ///
    /// - Throws: 當 API 請求失敗時拋出錯誤。
    private func printCopilotUsage() async throws {
        let keychain = KeychainService.live
        let apiClient = GitHubAPIClient.live

        guard let token = try keychain.loadAccessToken() else {
            print("  [Copilot] Not logged in. Run 'agentic login' first.")
            return
        }

        let user = try await apiClient.fetchUser(token)
        let status = try await apiClient.fetchCopilotStatus(token)
        let plan = CopilotPlan.fromAPIString(status.copilotPlan)
        let daysUntilReset = DateUtils.daysUntilReset()

        // 免費方案與付費方案的用量摘要結構不同
        let summary: CopilotUsageSummary
        if plan == .free {
            summary = CopilotUsageSummary(
                plan: plan,
                planLimit: plan.limit,
                daysUntilReset: daysUntilReset,
                freeChatRemaining: status.limitedUserQuotas?.chat,
                freeChatTotal: status.monthlyQuotas?.chat,
                freeCompletionsRemaining: status.limitedUserQuotas?.completions,
                freeCompletionsTotal: status.monthlyQuotas?.completions,
            )
        } else {
            summary = CopilotUsageSummary(
                plan: plan,
                planLimit: plan.limit,
                daysUntilReset: daysUntilReset,
                premiumPercentRemaining: status.quotaSnapshots?.premiumInteractions?.percentRemaining,
            )
        }

        printCopilotDisplay(user: user, summary: summary)
    }

    /// 格式化並印出 Copilot 的用量顯示內容。
    ///
    /// 免費方案分別顯示 Chat 與 Completions 的進度條；
    /// 付費方案顯示 Premium 請求的進度條。
    ///
    /// - Parameters:
    ///   - user: GitHub 使用者資訊。
    ///   - summary: Copilot 用量摘要。
    private func printCopilotDisplay(user: GitHubUser, summary: CopilotUsageSummary) {
        let barWidth = 30

        print()
        print("  GitHub Copilot Usage")
        print("  User: \(user.name ?? user.login) (@\(user.login))")
        print("  Plan: \(summary.plan.rawValue) (\(summary.planLimit) requests/month)")
        print()

        if summary.isFreeTier {
            // 免費方案：分別顯示 Chat 與 Completions 配額
            if let chatRemaining = summary.freeChatRemaining,
               let chatTotal = summary.freeChatTotal, chatTotal > 0 {
                let chatUsed = chatTotal - chatRemaining
                let chatPercent = Double(chatUsed) / Double(chatTotal)
                let filled = min(barWidth, Int(Double(barWidth) * chatPercent))
                let empty = barWidth - filled
                let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
                print("  Chat:        [\(bar)] \(Int(chatPercent * 100))%")
                print("               \(chatUsed) / \(chatTotal)  (\(chatRemaining) remaining)")
            }

            if let compRemaining = summary.freeCompletionsRemaining,
               let compTotal = summary.freeCompletionsTotal, compTotal > 0 {
                let compUsed = compTotal - compRemaining
                let compPercent = Double(compUsed) / Double(compTotal)
                let filled = min(barWidth, Int(Double(barWidth) * compPercent))
                let empty = barWidth - filled
                let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
                print("  Completions: [\(bar)] \(Int(compPercent * 100))%")
                print("               \(compUsed) / \(compTotal)  (\(compRemaining) remaining)")
            }
        } else {
            // 付費方案：顯示 Premium 請求用量
            let percentage = Int(summary.usagePercentage * 100)
            let filledCount = min(barWidth, Int(Double(barWidth) * summary.usagePercentage))
            let emptyCount = barWidth - filledCount
            let bar = String(repeating: "#", count: filledCount) + String(repeating: "-", count: emptyCount)
            print("  Premium:     [\(bar)] \(percentage)%")
            let used = summary.premiumRequestsUsed
            let limit = summary.planLimit
            let remaining = summary.remaining
            print("               \(used) / \(limit)  (\(remaining) remaining)")
        }

        print()
        print("  Resets in: \(summary.daysUntilReset) days")
        print()
    }

    // MARK: - Claude Code

    /// 查詢並印出 Claude Code 的用量資訊。
    ///
    /// 從環境變數取得 OAuth Client ID，載入本機憑證，
    /// 必要時重新整理權杖後查詢用量 API。
    ///
    /// - Throws: 當憑證重新整理或 API 請求失敗時拋出錯誤。
    private func printClaudeUsage() async throws {
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

    /// 印出文字進度條。
    ///
    /// - Parameters:
    ///   - label: 進度條左側的標籤文字。
    ///   - percentage: 使用百分比（0-100）。
    ///   - barWidth: 進度條的字元寬度。
    private func printProgressBar(label: String, percentage: Int, barWidth: Int) {
        let fraction = Double(percentage) / 100.0
        let filled = min(barWidth, Int(Double(barWidth) * fraction))
        let empty = barWidth - filled
        let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
        print("  \(label): [\(bar)] \(percentage)%")
    }

    // MARK: - Codex

    /// 查詢並印出 OpenAI Codex 的用量資訊。
    ///
    /// 從環境變數取得 OAuth Client ID，載入本機憑證，
    /// 必要時重新整理權杖後查詢用量 API。
    ///
    /// - Throws: 當憑證重新整理或 API 請求失敗時拋出錯誤。
    private func printCodexUsage() async throws {
        guard let clientID = ProcessInfo.processInfo.environment["AGENTIC_CODEX_CLIENT_ID"],
              !clientID.isEmpty else {
            print("  [Codex] AGENTIC_CODEX_CLIENT_ID environment variable is required.")
            print("  Set it to Codex's OAuth client ID for token refresh.")
            return
        }

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
        print("  Plan: \(summary.planDisplayName)")
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
