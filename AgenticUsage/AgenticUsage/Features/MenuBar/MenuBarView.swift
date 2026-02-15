import AgenticCore
import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @Bindable var store: StoreOf<MenuBarFeature>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            headerView

            Divider()

            // MARK: - Tool Cards
            ScrollView {
                VStack(spacing: 0) {
                    copilotToolCard
                    
                    ForEach(ToolKind.allCases.filter(\.isComingSoon)) { tool in
                        Divider()
                        comingSoonCard(tool: tool)
                    }
                }
            }

            Divider()

            // MARK: - Footer
            footerView
        }
        .frame(width: 320)
        .task {
            await store.send(.onAppear).finish()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Label("AgenticUsage", systemImage: "chart.bar.fill")
                .font(.headline)
            Spacer()
            Text("Version：\(Bundle.main.shortVersionString)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Copilot Tool Card

    @ViewBuilder
    private var copilotToolCard: some View {
        let tool = ToolKind.copilot
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header — always visible
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                copilotCardHeader(tool: tool, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                copilotExpandedContent
            }
        }
    }

    @ViewBuilder
    private func copilotCardHeader(tool: ToolKind, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            toolIcon(tool)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            // Separator + status
            copilotStatusLabel

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// Status portion of the collapsed Copilot card: username + plan badge, or connection status.
    @ViewBuilder
    private var copilotStatusLabel: some View {
        switch store.authState {
        case .loggedOut:
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Not Connected")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

        case .authenticating:
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Connecting...")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

        case let .loggedIn(user, _):
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("@\(user.login)")
                    .foregroundStyle(.secondary)
                if let plan = store.detectedPlan {
                    planBadge(plan: plan)
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Copilot Expanded Content

    @ViewBuilder
    private var copilotExpandedContent: some View {
        switch store.authState {
        case .loggedOut:
            copilotLoggedOutContent

        case .authenticating:
            copilotAuthenticatingContent

        case .loggedIn:
            copilotLoggedInContent
        }
    }

    @ViewBuilder
    private var copilotLoggedOutContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign in with GitHub to view your Copilot premium request usage.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Connect with GitHub") {
                store.send(.loginButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
    }

    @ViewBuilder
    private var copilotAuthenticatingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let flow = store.deviceFlowState {
                Text("Enter this code on GitHub:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(flow.userCode)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
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
        .padding(12)
    }

    @ViewBuilder
    private var copilotLoggedInContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Usage display
            if store.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(12)
            } else if let summary = store.usageSummary {
                usageSummaryView(summary: summary)
            }

            // Error
            if let error = store.errorMessage {
                HStack(spacing: 6) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()
                .padding(.horizontal, 12)

            // Card-level actions: Refresh + Sign Out
            HStack {
                Button {
                    store.send(.fetchUsage)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading)

                Spacer()

                Button("Sign Out") {
                    store.send(.logoutButtonTapped)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Coming Soon Card

    @ViewBuilder
    private func comingSoonCard(tool: ToolKind) -> some View {
        HStack(spacing: 8) {
            toolIcon(tool)
                .opacity(0.4)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)

            Text("|")
                .font(.caption)
                .foregroundStyle(.quaternary)

            Text("Coming Soon")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerView: some View {
        HStack {
            Spacer()
            Button("Quit") {
                store.send(.quitApp)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tool Icon

    /// Renders the tool's asset catalog image, applying its brand tint color when defined.
    @ViewBuilder
    private func toolIcon(_ tool: ToolKind) -> some View {
        if let tint = tool.tintColor {
            Image(tool.imageName(for: colorScheme))
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(tint)
        } else {
            Image(tool.imageName(for: colorScheme))
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        }
    }

    // MARK: - Plan Badge

    @ViewBuilder
    private func planBadge(plan: CopilotPlan) -> some View {
        Text(plan.badgeLabel)
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
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
        .padding(12)
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

// MARK: - Bundle + Version

extension Bundle {
    /// `CFBundleShortVersionString` (e.g. "1.2.0"), falling back to "–" if missing.
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
}
