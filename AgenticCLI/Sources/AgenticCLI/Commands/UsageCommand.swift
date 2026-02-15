import AgenticCore
import ArgumentParser
import Foundation

struct UsageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "usage",
        abstract: "Show your GitHub Copilot premium request usage for this month."
    )

    @Option(name: .long, help: "Your Copilot plan: free, pro, or pro-plus.")
    var plan: String = "pro"

    func run() async throws {
        let keychain = KeychainService.live
        let apiClient = GitHubAPIClient.live

        // Load token
        guard let token = try keychain.loadAccessToken() else {
            print("Error: Not logged in. Run 'agentic login' first.")
            throw ExitCode.failure
        }

        // Resolve plan
        let copilotPlan: CopilotPlan
        switch plan.lowercased() {
        case "free": copilotPlan = .free
        case "pro": copilotPlan = .pro
        case "pro-plus", "proplus", "pro+": copilotPlan = .proPlus
        default:
            print("Error: Unknown plan '\(plan)'. Use: free, pro, or pro-plus.")
            throw ExitCode.failure
        }

        // Fetch user
        let user = try await apiClient.fetchUser(token)

        // Fetch usage
        let period = DateUtils.currentBillingPeriod()
        let response = try await apiClient.fetchPremiumRequestUsage(
            token, user.login, period.year, period.month
        )

        let totalUsed = response.usageItems
            .filter { $0.product == "Copilot" }
            .reduce(0) { $0 + $1.grossQuantity }

        let summary = CopilotUsageSummary(
            premiumRequestsUsed: totalUsed,
            planLimit: copilotPlan.limit,
            plan: copilotPlan,
            daysUntilReset: DateUtils.daysUntilReset()
        )

        // Display
        printUsage(user: user, summary: summary)
    }

    private func printUsage(user: GitHubUser, summary: CopilotUsageSummary) {
        let percentage = Int(summary.usagePercentage * 100)
        let barWidth = 30
        let filledCount = min(barWidth, Int(Double(barWidth) * summary.usagePercentage))
        let emptyCount = barWidth - filledCount
        let bar = String(repeating: "#", count: filledCount) + String(repeating: "-", count: emptyCount)

        print()
        print("  GitHub Copilot Premium Requests")
        print("  User: \(user.name ?? user.login) (@\(user.login))")
        print("  Plan: \(summary.plan.rawValue) (\(summary.planLimit) requests/month)")
        print()
        print("  [\(bar)] \(percentage)%")
        print()
        print("  Used:      \(summary.premiumRequestsUsed) / \(summary.planLimit)")
        print("  Remaining: \(summary.remaining)")
        print("  Resets in: \(summary.daysUntilReset) days")
        print()
    }
}
