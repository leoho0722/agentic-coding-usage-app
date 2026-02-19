import SwiftUI
import AgenticCore
import ComposableArchitecture

// MARK: - MenuBarView

/// MenuBar 視窗的主要視圖，以手風琴式卡片佈局呈現各工具的用量資訊。
struct MenuBarView: View {

    /// TCA Store 的綁定參考
    @Bindable var store: StoreOf<MenuBarFeature>

    /// 系統目前的外觀模式（Light/Dark），用於工具圖示切換
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 頂部標題列：App 名稱 + 版本號
            headerView

            Divider()

            // 工具卡片區域：各工具以手風琴式展開/收合
            ScrollView {
                VStack(spacing: 0) {
                    copilotToolCard

                    Divider()
                    claudeToolCard

                    Divider()
                    codexToolCard

                    // 尚未上線的工具顯示「Coming Soon」卡片
                    ForEach(ToolKind.allCases.filter(\.isComingSoon)) { tool in
                        Divider()
                        comingSoonCard(tool: tool)
                    }
                }
            }

            Divider()

            // 底部動作列：結束應用程式
            footerView
        }
        .frame(width: 320)
        .task {
            await store.send(.onAppear).finish()
        }
    }

    // MARK: - 標題列

    /// 頂部標題列，顯示 App 名稱與版本號。
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

    // MARK: - 即將推出卡片

    /// 尚未上線工具的靜態卡片，以低透明度與「Coming Soon」標示。
    /// - Parameter tool: 工具類型
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

    // MARK: - 底部列

    /// 底部動作列，提供結束應用程式的按鈕。
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
}

// MARK: - Copilot

extension MenuBarView {

    // MARK: 工具卡片

    /// Copilot 工具卡片，包含可點擊的標題列與可展開的內容區域。
    @ViewBuilder
    var copilotToolCard: some View {
        let tool = ToolKind.copilot
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            // 收合的標題列，始終可見
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                copilotCardHeader(tool: tool, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            // 展開的內容區域
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                copilotExpandedContent
            }
        }
    }

    /// Copilot 卡片的標題列佈局，包含圖示、名稱、狀態標籤與展開箭頭。
    /// - Parameters:
    ///   - tool: 工具類型
    ///   - isExpanded: 是否處於展開狀態
    @ViewBuilder
    private func copilotCardHeader(tool: ToolKind, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            toolIcon(tool)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            // 分隔線與狀態標籤
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

    /// Copilot 卡片收合時的狀態標籤，顯示使用者名稱 + 方案徽章，或連線狀態。
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
                    copilotPlanBadge(plan: plan)
                }
            }
            .font(.caption)
        }
    }

    // MARK: 展開內容

    /// 依據認證狀態切換不同的 Copilot 展開內容。
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

    /// 未登入時顯示的提示與連接 GitHub 按鈕。
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

    /// Device Flow 認證進行中的畫面，顯示驗證碼與開啟 GitHub 按鈕。
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

    /// 已登入時的完整內容，包含用量摘要、錯誤提示與操作按鈕。
    @ViewBuilder
    private var copilotLoggedInContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 用量顯示區域
            if store.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(12)
            } else if let summary = store.usageSummary {
                copilotUsageSummaryView(summary: summary)
            }

            // 錯誤訊息提示
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

            // 卡片底部操作列：重新整理 + 登出
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

    // MARK: 方案徽章

    /// Copilot 方案的膠囊徽章。
    /// - Parameter plan: Copilot 方案類型
    @ViewBuilder
    private func copilotPlanBadge(plan: CopilotPlan) -> some View {
        Text(plan.badgeLabel)
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(copilotPlanBadgeColor(for: plan), in: Capsule())
    }

    /// 取得 Copilot 方案對應的徽章顏色。
    /// - Parameter plan: Copilot 方案類型
    /// - Returns: 對應的顏色
    private func copilotPlanBadgeColor(for plan: CopilotPlan) -> Color {
        switch plan {
        case .free: .gray
        case .pro: .blue
        case .proPlus: .purple
        }
    }

    // MARK: 用量摘要

    /// Copilot 用量摘要視圖，依方案類型切換免費/付費的顯示佈局。
    /// - Parameter summary: Copilot 用量摘要資料
    @ViewBuilder
    private func copilotUsageSummaryView(summary: CopilotUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if summary.isFreeTier {
                copilotFreeTierUsageView(summary: summary)
            } else {
                copilotPaidTierUsageView(summary: summary)
            }
        }
        .padding(12)
    }

    /// 付費方案的用量顯示，包含 Premium Requests 進度條與統計數據列。
    /// - Parameter summary: Copilot 用量摘要資料
    @ViewBuilder
    private func copilotPaidTierUsageView(summary: CopilotUsageSummary) -> some View {
        // Premium Requests 進度條
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

        // 統計數據列：剩餘次數、已使用百分比、重設剩餘天數
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

    /// 免費方案的用量顯示，分別顯示 Chat 和 Completions 的配額進度。
    /// - Parameter summary: Copilot 用量摘要資料
    @ViewBuilder
    private func copilotFreeTierUsageView(summary: CopilotUsageSummary) -> some View {
        // Chat 配額
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

        // Completions 配額
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

// MARK: - Claude Code

extension MenuBarView {

    // MARK: 工具卡片

    /// Claude Code 工具卡片，包含可點擊的標題列與可展開的內容區域。
    @ViewBuilder
    var claudeToolCard: some View {
        let tool = ToolKind.claudeCode
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                claudeCardHeader(tool: tool, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                claudeExpandedContent
            }
        }
    }

    /// Claude Code 卡片的標題列佈局。
    /// - Parameters:
    ///   - tool: 工具類型
    ///   - isExpanded: 是否處於展開狀態
    @ViewBuilder
    private func claudeCardHeader(tool: ToolKind, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            toolIcon(tool)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            claudeStatusLabel

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

    /// Claude Code 卡片收合時的狀態標籤，顯示偵測狀態與訂閱方案徽章。
    @ViewBuilder
    private var claudeStatusLabel: some View {
        switch store.claudeConnectionState {
        case .notDetected:
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Not Detected")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

        case let .connected(subscriptionType):
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Connected")
                    .foregroundStyle(.secondary)
                if let sub = subscriptionType {
                    claudePlanBadge(subscriptionType: sub)
                }
            }
            .font(.caption)
        }
    }

    // MARK: 展開內容

    /// 依據連線狀態切換不同的 Claude Code 展開內容。
    @ViewBuilder
    private var claudeExpandedContent: some View {
        switch store.claudeConnectionState {
        case .notDetected:
            claudeNotDetectedContent

        case .connected:
            claudeConnectedContent
        }
    }

    /// Claude Code 未偵測到憑證時的提示與重新偵測按鈕。
    @ViewBuilder
    private var claudeNotDetectedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("請先透過終端機登入 Claude Code")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("重新偵測") {
                store.send(.detectClaudeCredentials)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.isClaudeLoading)
        }
        .padding(12)
    }

    /// Claude Code 已連線時的完整內容，包含用量摘要、錯誤提示與重新整理按鈕。
    @ViewBuilder
    private var claudeConnectedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.isClaudeLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(12)
            } else if let summary = store.claudeUsageSummary {
                claudeUsageSummaryView(summary: summary)
            }

            // 錯誤訊息提示
            if let error = store.claudeErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        store.send(.dismissClaudeError)
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

            // 重新整理按鈕
            HStack {
                Button {
                    store.send(.fetchClaudeUsage)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(store.isClaudeLoading)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: 方案徽章

    /// Claude Code 訂閱方案的膠囊徽章。
    /// - Parameter subscriptionType: 訂閱類型字串（例如 "pro"、"max"）
    @ViewBuilder
    private func claudePlanBadge(subscriptionType: String) -> some View {
        Text(claudePlanBadgeLabel(for: subscriptionType))
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(claudePlanBadgeColor(for: subscriptionType), in: Capsule())
    }

    /// 取得 Claude Code 訂閱類型對應的徽章標籤。
    /// - Parameter subscriptionType: 訂閱類型字串
    /// - Returns: 對應的顯示標籤
    private func claudePlanBadgeLabel(for subscriptionType: String) -> String {
        switch subscriptionType.lowercased() {
        case "pro": "Pro"
        case "max", "pro_plus": "Max"
        case "free": "Free"
        default: subscriptionType.lowercased().capitalized
        }
    }

    /// 取得 Claude Code 訂閱類型對應的徽章顏色。
    /// - Parameter subscriptionType: 訂閱類型字串
    /// - Returns: 對應的顏色
    private func claudePlanBadgeColor(for subscriptionType: String) -> Color {
        switch subscriptionType.lowercased() {
        case "free": .gray
        case "pro": .orange
        case "max", "pro_plus": .purple
        default: .blue
        }
    }

    // MARK: 用量摘要

    /// Claude Code 用量摘要視圖，顯示各時間窗口的使用百分比與額外用量。
    /// - Parameter summary: Claude Code 用量摘要資料
    @ViewBuilder
    private func claudeUsageSummaryView(summary: ClaudeUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 工作階段用量（5 小時窗口）
            if let pct = summary.sessionUtilization {
                claudeProgressRow(
                    label: "Session (5h)",
                    utilization: pct,
                    countdown: summary.sessionResetsAt.flatMap {
                        ClaudeUsagePeriod(utilization: pct, resetsAt: $0).resetCountdown
                    }
                )
            }

            // 每週用量（7 天窗口）
            if let pct = summary.weeklyUtilization {
                claudeProgressRow(
                    label: "Weekly (7d)",
                    utilization: pct,
                    countdown: summary.weeklyResetsAt.flatMap {
                        ClaudeUsagePeriod(utilization: pct, resetsAt: $0).resetCountdown
                    }
                )
            }

            // Opus 模型用量（7 天窗口），僅在有資料時顯示
            if let pct = summary.opusUtilization {
                claudeProgressRow(
                    label: "Opus (7d)",
                    utilization: pct,
                    countdown: summary.opusResetsAt.flatMap {
                        ClaudeUsagePeriod(utilization: pct, resetsAt: $0).resetCountdown
                    }
                )
            }

            // 額外用量，僅在啟用時顯示
            if summary.hasExtraUsage {
                HStack {
                    Text("Extra Usage")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    if let used = summary.extraUsageUsedDollars,
                       let limit = summary.extraUsageLimitDollars {
                        Text(String(format: "$%.2f / $%.2f", used, limit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }

    /// Claude Code 用量進度列，顯示標籤、百分比與重設倒數。
    /// - Parameters:
    ///   - label: 用量窗口的標籤文字
    ///   - utilization: 使用百分比（0–100）
    ///   - countdown: 重設倒數文字，若無則隱藏
    @ViewBuilder
    private func claudeProgressRow(label: String, utilization: Int, countdown: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(utilization)%")
                    .font(.caption)
                    .foregroundStyle(progressColor(for: Double(utilization) / 100.0))
                if let countdown {
                    Text("· resets in \(countdown)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            progressBar(percentage: Double(utilization) / 100.0)
        }
    }
}

// MARK: - Codex

extension MenuBarView {

    // MARK: 工具卡片

    /// Codex 工具卡片，包含可點擊的標題列與可展開的內容區域。
    @ViewBuilder
    var codexToolCard: some View {
        let tool = ToolKind.codex
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                codexCardHeader(tool: tool, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                codexExpandedContent
            }
        }
    }

    /// Codex 卡片的標題列佈局。
    /// - Parameters:
    ///   - tool: 工具類型
    ///   - isExpanded: 是否處於展開狀態
    @ViewBuilder
    private func codexCardHeader(tool: ToolKind, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            toolIcon(tool)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            codexStatusLabel

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

    /// Codex 卡片收合時的狀態標籤，顯示偵測狀態與方案徽章。
    @ViewBuilder
    private var codexStatusLabel: some View {
        switch store.codexConnectionState {
        case .notDetected:
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Not Detected")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

        case let .connected(planType):
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Connected")
                    .foregroundStyle(.secondary)
                if let plan = planType {
                    codexPlanBadge(planType: plan)
                }
            }
            .font(.caption)
        }
    }

    // MARK: 展開內容

    /// 依據連線狀態切換不同的 Codex 展開內容。
    @ViewBuilder
    private var codexExpandedContent: some View {
        switch store.codexConnectionState {
        case .notDetected:
            codexNotDetectedContent

        case .connected:
            codexConnectedContent
        }
    }

    /// Codex 未偵測到憑證時的提示與重新偵測按鈕。
    @ViewBuilder
    private var codexNotDetectedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("請先透過終端機登入 Codex")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("重新偵測") {
                store.send(.detectCodexCredentials)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.isCodexLoading)
        }
        .padding(12)
    }

    /// Codex 已連線時的完整內容，包含用量摘要、錯誤提示與重新整理按鈕。
    @ViewBuilder
    private var codexConnectedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.isCodexLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(12)
            } else if let summary = store.codexUsageSummary {
                codexUsageSummaryView(summary: summary)
            }

            // 錯誤訊息提示
            if let error = store.codexErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        store.send(.dismissCodexError)
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

            // 重新整理按鈕
            HStack {
                Button {
                    store.send(.fetchCodexUsage)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(store.isCodexLoading)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: 方案徽章

    /// Codex 方案的膠囊徽章。
    /// - Parameter planType: 方案類型字串（例如 "plus"、"pro"）
    @ViewBuilder
    private func codexPlanBadge(planType: String) -> some View {
        Text(codexPlanBadgeLabel(for: planType))
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(codexPlanBadgeColor(for: planType), in: Capsule())
    }

    /// 取得 Codex 方案類型對應的徽章標籤。
    /// - Parameter planType: 方案類型字串
    /// - Returns: 對應的顯示標籤
    private func codexPlanBadgeLabel(for planType: String) -> String {
        switch planType.lowercased() {
        case "free": "Free"
        case "plus": "Plus"
        case "pro": "Pro"
        case "team": "Team"
        case "enterprise": "Enterprise"
        default: planType.lowercased().capitalized
        }
    }

    /// 取得 Codex 方案類型對應的徽章顏色。
    /// - Parameter planType: 方案類型字串
    /// - Returns: 對應的顏色
    private func codexPlanBadgeColor(for planType: String) -> Color {
        switch planType.lowercased() {
        case "free": .gray
        case "plus": .blue
        case "pro": .green
        case "team": .orange
        case "enterprise": .purple
        default: .blue
        }
    }

    // MARK: 用量摘要

    /// Codex 用量摘要視圖，顯示各時間窗口、模型限制、Code Review 與 Credits。
    /// - Parameter summary: Codex 用量摘要資料
    @ViewBuilder
    private func codexUsageSummaryView(summary: CodexUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 工作階段用量（5 小時窗口）
            if let pct = summary.sessionUsedPercent {
                codexProgressRow(
                    label: "Session (5h)",
                    usedPercent: pct,
                    countdown: summary.sessionResetAt?.countdownString
                )
            }

            // 每週用量（7 天窗口）
            if let pct = summary.weeklyUsedPercent {
                codexProgressRow(
                    label: "Weekly (7d)",
                    usedPercent: pct,
                    countdown: summary.weeklyResetAt?.countdownString
                )
            }

            // 各模型的額外限制
            if summary.hasAdditionalLimits {
                ForEach(Array(summary.additionalLimits.enumerated()), id: \.offset) { _, limit in
                    if let pct = limit.sessionUsedPercent {
                        codexProgressRow(
                            label: "\(limit.shortDisplayName) (5h)",
                            usedPercent: pct,
                            countdown: limit.sessionResetAt?.countdownString
                        )
                    }
                    if let pct = limit.weeklyUsedPercent {
                        codexProgressRow(
                            label: "\(limit.shortDisplayName) (7d)",
                            usedPercent: pct,
                            countdown: limit.weeklyResetAt?.countdownString
                        )
                    }
                }
            }

            // Code Review 用量（7 天窗口）
            if let pct = summary.codeReviewUsedPercent {
                codexProgressRow(
                    label: "Code Reviews (7d)",
                    usedPercent: pct,
                    countdown: summary.codeReviewResetAt?.countdownString
                )
            }

            // 點數餘額
            if let balance = summary.creditsBalance {
                HStack {
                    Text("Credits")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.0f / 1,000", balance))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }

    /// Codex 用量進度列，顯示標籤、百分比與重設倒數。
    /// - Parameters:
    ///   - label: 用量窗口的標籤文字
    ///   - usedPercent: 使用百分比（0–100）
    ///   - countdown: 重設倒數文字，若無則隱藏
    @ViewBuilder
    private func codexProgressRow(label: String, usedPercent: Int, countdown: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(usedPercent)%")
                    .font(.caption)
                    .foregroundStyle(progressColor(for: Double(usedPercent) / 100.0))
                if let countdown {
                    Text("· resets in \(countdown)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            progressBar(percentage: Double(usedPercent) / 100.0)
        }
    }
}

// MARK: - 共用輔助工具

extension MenuBarView {

    /// 繪製工具的 Asset Catalog 圖片，若有品牌色調則套用 template 著色。
    /// - Parameter tool: 工具類型
    @ViewBuilder
    func toolIcon(_ tool: ToolKind) -> some View {
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

    /// 繪製水平進度條，依據百分比著色。
    /// - Parameter percentage: 使用百分比（0.0–1.0）
    @ViewBuilder
    func progressBar(percentage: Double) -> some View {
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

    /// 依據使用百分比回傳對應的顏色（綠 → 黃 → 橘 → 紅）。
    /// - Parameter percentage: 使用百分比（0.0–1.0）
    /// - Returns: 對應的顏色
    func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case ..<0.5: .green
        case 0.5..<0.8: .yellow
        case 0.8..<1.0: .orange
        default: .red
        }
    }
}
