import AgenticCore
import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @Bindable var store: StoreOf<MenuBarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch store.authState {
            case .loggedOut:
                loggedOutView
            case .authenticating:
                authenticatingView
            case let .loggedIn(user, _):
                loggedInView(user: user)
            }
        }
        .frame(width: 300)
        .task {
            await store.send(.onAppear).finish()
        }
    }

    // MARK: - Logged Out

    @ViewBuilder
    private var loggedOutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AgenticUsage", systemImage: "chart.bar.fill")
                .font(.headline)

            Text("Sign in with GitHub to view your Copilot premium request usage.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Sign in with GitHub") {
                store.send(.loginButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
    }

    // MARK: - Authenticating (Device Flow)

    @ViewBuilder
    private var authenticatingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sign in to GitHub", systemImage: "person.badge.key")
                .font(.headline)

            if let flow = store.deviceFlowState {
                Text("Enter this code on GitHub:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(flow.userCode)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .textSelection(.enabled)

                    Button {
                        store.send(.copyUserCode)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy code")
                }

                Button("Open GitHub") {
                    store.send(.openVerificationURL)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text("Waiting for authorization...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Requesting device code...")
                    .controlSize(.small)
            }
        }
        .padding()
    }

    // MARK: - Logged In

    @ViewBuilder
    private func loggedInView(user: GitHubUser) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with plan badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user.name ?? user.login)
                            .font(.headline)
                        if let plan = store.detectedPlan {
                            planBadge(plan: plan)
                        }
                    }
                    Text("@\(user.login)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.send(.fetchUsage)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading)
                .help("Refresh usage")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Usage display
            if store.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding()
            } else if let summary = store.usageSummary {
                usageSummaryView(summary: summary)
            }

            // Error
            if let error = store.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        store.send(.dismissError)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Divider()

            // Footer actions
            HStack {
                Button("Sign Out") {
                    store.send(.logoutButtonTapped)
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button("Quit") {
                    store.send(.quitApp)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Plan Badge

    @ViewBuilder
    private func planBadge(plan: CopilotPlan) -> some View {
        Text(plan.badgeLabel)
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(planBadgeColor(for: plan), in: Capsule())
    }

    private func planBadgeColor(for plan: CopilotPlan) -> Color {
        switch plan {
        case .free: .gray
        case .pro: .blue
        case .proPlus: .purple
        }
    }

    // MARK: - Usage Summary

    @ViewBuilder
    private func usageSummaryView(summary: CopilotUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.isFreeTier {
                freeTierUsageView(summary: summary)
            } else {
                paidTierUsageView(summary: summary)
            }
        }
        .padding()
    }

    // MARK: - Paid Tier Usage

    @ViewBuilder
    private func paidTierUsageView(summary: CopilotUsageSummary) -> some View {
        // Premium requests progress bar
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

            progressBar(percentage: summary.usagePercentage)
        }

        // Stats row
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
                    .foregroundStyle(progressColor(for: summary.usagePercentage))
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

    // MARK: - Free Tier Usage

    @ViewBuilder
    private func freeTierUsageView(summary: CopilotUsageSummary) -> some View {
        // Chat quota
        if let chatRemaining = summary.freeChatRemaining,
           let chatTotal = summary.freeChatTotal, chatTotal > 0
        {
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
                progressBar(percentage: chatPercent)
            }
        }

        // Completions quota
        if let compRemaining = summary.freeCompletionsRemaining,
           let compTotal = summary.freeCompletionsTotal, compTotal > 0
        {
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
                progressBar(percentage: compPercent)
            }
        }

        // Days left
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

    // MARK: - Helpers

    @ViewBuilder
    private func progressBar(percentage: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(progressColor(for: percentage))
                    .frame(
                        width: min(
                            geometry.size.width,
                            geometry.size.width * percentage
                        ),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }

    private func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case ..<0.5: .green
        case 0.5 ..< 0.8: .yellow
        case 0.8 ..< 1.0: .orange
        default: .red
        }
    }
}
