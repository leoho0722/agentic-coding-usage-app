import Foundation
import AgenticCore

// MARK: - Copilot 用量

extension UsageCommand {

    /// 查詢並印出 GitHub Copilot 的用量資訊。
    ///
    /// 從鑰匙圈載入存取權杖，取得使用者資訊與 Copilot 狀態，
    /// 再依據方案類型（免費版 / 付費版）組裝用量摘要。
    ///
    /// - Throws: 當 API 請求失敗時拋出錯誤。
    func printCopilotUsage() async throws {
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
}
