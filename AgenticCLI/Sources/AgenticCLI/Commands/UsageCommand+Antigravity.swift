import Foundation
import AgenticCore

// MARK: - Antigravity 用量

extension UsageCommand {

    /// 查詢並印出 Google Antigravity 的用量資訊。
    ///
    /// 從環境變數取得 Google OAuth Client ID 與 Client Secret，載入本機憑證，
    /// 必要時重新整理權杖後查詢 Cloud Code API。
    ///
    /// - Throws: 當憑證重新整理或 API 請求失敗時拋出錯誤。
    func printAntigravityUsage() async throws {
        guard let clientID = ProcessInfo.processInfo.environment["AGENTIC_ANTIGRAVITY_CLIENT_ID"],
              !clientID.isEmpty else {
            print("  [Antigravity] AGENTIC_ANTIGRAVITY_CLIENT_ID environment variable is required.")
            print("  Set it to Google's OAuth client ID for token refresh.")
            return
        }

        guard let clientSecret = ProcessInfo.processInfo.environment["AGENTIC_ANTIGRAVITY_CLIENT_SECRET"],
              !clientSecret.isEmpty else {
            print("  [Antigravity] AGENTIC_ANTIGRAVITY_CLIENT_SECRET environment variable is required.")
            print("  Set it to Google's OAuth client secret for token refresh.")
            return
        }

        let antigravityClient = AntigravityAPIClient.live(
            clientID: clientID,
            clientSecret: clientSecret
        )

        guard let credentials = try antigravityClient.loadCredentials() else {
            print("  [Antigravity] Credentials not found. Log in via Antigravity IDE first.")
            return
        }

        // 必要時重新整理存取權杖
        let refreshed = try await antigravityClient.refreshTokenIfNeeded(credentials)
        let response = try await antigravityClient.fetchUsage(refreshed.accessToken)
        let summary = AntigravityUsageSummary(plan: nil, response: response)

        printAntigravityDisplay(summary: summary)
    }

    /// 格式化並印出 Antigravity 的用量顯示內容。
    ///
    /// 逐模型顯示進度條與重設倒數。
    ///
    /// - Parameter summary: Antigravity 用量摘要。
    private func printAntigravityDisplay(summary: AntigravityUsageSummary) {
        let barWidth = 30

        print()
        print("  Google Antigravity Usage")
        if let plan = summary.plan {
            print("  Plan: \(plan.badgeLabel)")
        }
        print()

        if summary.hasUsageData {
            for modelUsage in summary.modelUsages {
                printProgressBar(
                    label: modelUsage.displayName,
                    percentage: modelUsage.usedPercent,
                    barWidth: barWidth
                )
                if let countdown = modelUsage.resetAt?.countdownString {
                    let padding = String(repeating: " ", count: modelUsage.displayName.count + 2)
                    print("  \(padding) Resets in: \(countdown)")
                }
            }
        } else {
            print("  No model usage data available.")
        }

        print()
    }
}
