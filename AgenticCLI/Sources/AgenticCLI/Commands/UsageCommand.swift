import AgenticCore
import ArgumentParser
import Foundation

struct UsageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "usage",
        abstract: "Show your AI coding assistant usage for the current period."
    )

    @Option(name: .long, help: "Tool to show usage for: copilot, claude, codex, or all (default: all).")
    var tool: String = "all"

    func run() async throws {
        let toolFilter = tool.lowercased()

        guard ["all", "copilot", "claude", "codex"].contains(toolFilter) else {
            print("Error: Unknown tool '\(tool)'. Use 'copilot', 'claude', 'codex', or 'all'.")
            throw ExitCode.failure
        }

        var printed = false

        // Copilot
        if toolFilter == "all" || toolFilter == "copilot" {
            do {
                try await printCopilotUsage()
                printed = true
            } catch {
                if toolFilter == "copilot" {
                    throw error
                }
                print("  [Copilot] \(error.localizedDescription)")
                print()
            }
        }

        // Claude Code
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

        // Codex
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

        let summary: CopilotUsageSummary
        if plan == .free {
            summary = CopilotUsageSummary(
                plan: plan,
                planLimit: plan.limit,
                daysUntilReset: daysUntilReset,
                freeChatRemaining: status.limitedUserQuotas?.chat,
                freeChatTotal: status.monthlyQuotas?.chat,
                freeCompletionsRemaining: status.limitedUserQuotas?.completions,
                freeCompletionsTotal: status.monthlyQuotas?.completions
            )
        } else {
            summary = CopilotUsageSummary(
                plan: plan,
                planLimit: plan.limit,
                daysUntilReset: daysUntilReset,
                premiumPercentRemaining: status.quotaSnapshots?.premiumInteractions?.percentRemaining
            )
        }

        printCopilotDisplay(user: user, summary: summary)
    }

    private func printCopilotDisplay(user: GitHubUser, summary: CopilotUsageSummary) {
        let barWidth = 30

        print()
        print("  GitHub Copilot Usage")
        print("  User: \(user.name ?? user.login) (@\(user.login))")
        print("  Plan: \(summary.plan.rawValue) (\(summary.planLimit) requests/month)")
        print()

        if summary.isFreeTier {
            if let chatRemaining = summary.freeChatRemaining,
               let chatTotal = summary.freeChatTotal, chatTotal > 0
            {
                let chatUsed = chatTotal - chatRemaining
                let chatPercent = Double(chatUsed) / Double(chatTotal)
                let filled = min(barWidth, Int(Double(barWidth) * chatPercent))
                let empty = barWidth - filled
                let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
                print("  Chat:        [\(bar)] \(Int(chatPercent * 100))%")
                print("               \(chatUsed) / \(chatTotal)  (\(chatRemaining) remaining)")
            }
            if let compRemaining = summary.freeCompletionsRemaining,
               let compTotal = summary.freeCompletionsTotal, compTotal > 0
            {
                let compUsed = compTotal - compRemaining
                let compPercent = Double(compUsed) / Double(compTotal)
                let filled = min(barWidth, Int(Double(barWidth) * compPercent))
                let empty = barWidth - filled
                let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
                print("  Completions: [\(bar)] \(Int(compPercent * 100))%")
                print("               \(compUsed) / \(compTotal)  (\(compRemaining) remaining)")
            }
        } else {
            let percentage = Int(summary.usagePercentage * 100)
            let filledCount = min(barWidth, Int(Double(barWidth) * summary.usagePercentage))
            let emptyCount = barWidth - filledCount
            let bar = String(repeating: "#", count: filledCount) + String(repeating: "-", count: emptyCount)
            print("  Premium:     [\(bar)] \(percentage)%")
            print("               \(summary.premiumRequestsUsed) / \(summary.planLimit)  (\(summary.remaining) remaining)")
        }

        print()
        print("  Resets in: \(summary.daysUntilReset) days")
        print()
    }

    // MARK: - Claude Code

    private func printClaudeUsage() async throws {
        let claudeClient = ClaudeAPIClient.live

        guard let credentials = try claudeClient.loadCredentials() else {
            print("  [Claude Code] Credentials not found. Run 'claude login' in terminal first.")
            return
        }

        let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
        let response = try await claudeClient.fetchUsage(refreshed.accessToken)
        let summary = ClaudeUsageSummary(
            subscriptionType: refreshed.subscriptionType,
            response: response
        )

        printClaudeDisplay(summary: summary)
    }

    private func printClaudeDisplay(summary: ClaudeUsageSummary) {
        let barWidth = 30

        print()
        print("  Claude Code Usage")
        print("  Plan: \(summary.planDisplayName)")
        print()

        // Session (5h)
        if let pct = summary.sessionUtilization {
            printClaudeBar(label: "Session (5h)", percentage: pct, barWidth: barWidth)
            if let resetsAt = summary.sessionResetsAt {
                let countdown = ClaudeUsagePeriod(utilization: pct, resetsAt: resetsAt).resetCountdown ?? "?"
                print("               Resets in: \(countdown)")
            }
        }

        // Weekly (7d)
        if let pct = summary.weeklyUtilization {
            printClaudeBar(label: "Weekly  (7d)", percentage: pct, barWidth: barWidth)
            if let resetsAt = summary.weeklyResetsAt {
                let countdown = ClaudeUsagePeriod(utilization: pct, resetsAt: resetsAt).resetCountdown ?? "?"
                print("               Resets in: \(countdown)")
            }
        }

        // Opus (7d) — only if present
        if let pct = summary.opusUtilization {
            printClaudeBar(label: "Opus    (7d)", percentage: pct, barWidth: barWidth)
            if let resetsAt = summary.opusResetsAt {
                let countdown = ClaudeUsagePeriod(utilization: pct, resetsAt: resetsAt).resetCountdown ?? "?"
                print("               Resets in: \(countdown)")
            }
        }

        // Extra Usage
        if summary.hasExtraUsage,
           let used = summary.extraUsageUsedDollars,
           let limit = summary.extraUsageLimitDollars
        {
            print(String(format: "  Extra Usage: $%.2f / $%.2f", used, limit))
        }

        print()
    }

    private func printProgressBar(label: String, percentage: Int, barWidth: Int) {
        let fraction = Double(percentage) / 100.0
        let filled = min(barWidth, Int(Double(barWidth) * fraction))
        let empty = barWidth - filled
        let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
        print("  \(label): [\(bar)] \(percentage)%")
    }

    private func printClaudeBar(label: String, percentage: Int, barWidth: Int) {
        printProgressBar(label: label, percentage: percentage, barWidth: barWidth)
    }

    // MARK: - Codex

    private func printCodexUsage() async throws {
        let codexClient = CodexAPIClient.live

        guard let credentials = try codexClient.loadCredentials() else {
            print("  [Codex] Credentials not found. Run 'codex auth login' in terminal first.")
            return
        }

        let refreshed = try await codexClient.refreshTokenIfNeeded(credentials)
        let (headers, response) = try await codexClient.fetchUsage(
            refreshed.accessToken, refreshed.accountId
        )
        let summary = CodexUsageSummary(headers: headers, response: response)

        printCodexDisplay(summary: summary)
    }

    private func printCodexDisplay(summary: CodexUsageSummary) {
        let barWidth = 30

        print()
        print("  OpenAI Codex Usage")
        print("  Plan: \(summary.planDisplayName)")
        print()

        // Session (5h)
        if let pct = summary.sessionUsedPercent {
            printProgressBar(label: "Session (5h)", percentage: pct, barWidth: barWidth)
            if let countdown = summary.sessionResetAt?.countdownString {
                print("               Resets in: \(countdown)")
            }
        }

        // Weekly (7d)
        if let pct = summary.weeklyUsedPercent {
            printProgressBar(label: "Weekly  (7d)", percentage: pct, barWidth: barWidth)
            if let countdown = summary.weeklyResetAt?.countdownString {
                print("               Resets in: \(countdown)")
            }
        }

        // Per-model additional limits
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

        // Code Reviews
        if let pct = summary.codeReviewUsedPercent {
            printProgressBar(label: "Reviews (7d)", percentage: pct, barWidth: barWidth)
            if let countdown = summary.codeReviewResetAt?.countdownString {
                print("               Resets in: \(countdown)")
            }
        }

        // Credits
        if let balance = summary.creditsBalance {
            print(String(format: "  Credits:     %.0f / 1,000", balance))
        }

        print()
    }
}
