import AgenticCore
import AppKit
import ComposableArchitecture

@Reducer
struct MenuBarFeature {
    
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        // Copilot
        var authState: AuthState = .loggedOut
        var usageSummary: CopilotUsageSummary?
        var detectedPlan: CopilotPlan?
        var isLoading: Bool = false
        var errorMessage: String?
        var deviceFlowState: DeviceFlowState?

        // Claude Code
        var claudeConnectionState: ClaudeConnectionState = .notDetected
        var claudeUsageSummary: ClaudeUsageSummary?
        var isClaudeLoading: Bool = false
        var claudeErrorMessage: String?

        // Codex
        var codexConnectionState: CodexConnectionState = .notDetected
        var codexUsageSummary: CodexUsageSummary?
        var isCodexLoading: Bool = false
        var codexErrorMessage: String?

        /// Which tool card is currently expanded (accordion). Defaults to Copilot on launch.
        var expandedTool: ToolKind? = .copilot
    }
    
    enum AuthState: Equatable, Sendable {
        case loggedOut
        case authenticating
        case loggedIn(user: GitHubUser, accessToken: String)
        
        var accessToken: String? {
            if case let .loggedIn(_, token) = self { return token }
            return nil
        }
    }
    
    struct DeviceFlowState: Equatable, Sendable {
        let userCode: String
        let verificationUri: String
    }

    enum ClaudeConnectionState: Equatable, Sendable {
        /// No credentials found on disk / Keychain.
        case notDetected
        /// Credentials found and usage loaded.
        case connected(subscriptionType: String?)
    }

    enum CodexConnectionState: Equatable, Sendable {
        /// No credentials found on disk / Keychain.
        case notDetected
        /// Credentials found and usage loaded.
        case connected(planType: String?)
    }
    
    // MARK: - Action
    
    enum Action: Equatable, Sendable {
        case onAppear
        case checkExistingAuth
        case requestNotificationAuthorization
        
        // Copilot
        case loginButtonTapped
        case deviceCodeReceived(DeviceFlowState)
        case loginCompleted(GitHubUser, String)
        case loginFailed(String)
        case logoutButtonTapped
        case logoutCompleted
        
        case fetchUsage
        case usageResponse(CopilotUsageSummary)
        case usageFailed(String)
        case checkUsageThresholds

        // Claude Code
        case detectClaudeCredentials
        case fetchClaudeUsage
        case claudeUsageResponse(ClaudeUsageSummary)
        case claudeUsageFailed(String)
        case checkClaudeUsageThresholds

        // Codex
        case detectCodexCredentials
        case fetchCodexUsage
        case codexUsageResponse(CodexUsageSummary)
        case codexUsageFailed(String)
        case checkCodexUsageThresholds

        // UI
        case toggleToolExpansion(ToolKind)

        case openVerificationURL
        case copyUserCode
        case dismissError
        case dismissClaudeError
        case dismissCodexError
        case quitApp
    }
    
    // MARK: - Client ID
    
    static let gitHubClientID: String = {
        guard let clientID = Bundle.main.infoDictionary?["GitHubClientID"] as? String,
              !clientID.isEmpty,
              clientID != "YOUR_CLIENT_ID_HERE" else {
            fatalError(
                "GitHubClientID not configured. Copy Secrets.xcconfig.template to Secrets.xcconfig and set your GitHub OAuth App client ID."
            )
        }
        return clientID
    }()

    // MARK: - Reset Cycle Helpers

    /// Returns "YYYY-MM" UTC string for Copilot monthly reset cycle.
    private static func copilotResetCycle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
    
    // MARK: - Body
    
    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
                
            case .onAppear:
                return .merge(
                    .send(.checkExistingAuth),
                    .send(.detectClaudeCredentials),
                    .send(.detectCodexCredentials),
                    .send(.requestNotificationAuthorization)
                )
                
            case .requestNotificationAuthorization:
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient
                    _ = try await notificationClient.requestAuthorization()
                } catch: { _, _ in }
                
            case .checkExistingAuth:
                return .run { send in
                    @Dependency(\.keychainService) var keychainService
                    @Dependency(\.gitHubAPIClient) var apiClient
                    if let token = try keychainService.loadAccessToken() {
                        let user = try await apiClient.fetchUser(token)
                        await send(.loginCompleted(user, token))
                    }
                } catch: { _, _ in }
                
            case .loginButtonTapped:
                state.authState = .authenticating
                state.errorMessage = nil
                return .run { send in
                    @Dependency(\.oAuthService) var oAuthService
                    @Dependency(\.gitHubAPIClient) var apiClient
                    @Dependency(\.keychainService) var keychainService
                    
                    let deviceCode = try await oAuthService.requestDeviceCode(Self.gitHubClientID)
                    await send(
                        .deviceCodeReceived(
                            DeviceFlowState(
                                userCode: deviceCode.userCode,
                                verificationUri: deviceCode.verificationUri
                            )
                        )
                    )
                    let tokenResponse = try await oAuthService.pollForAccessToken(
                        Self.gitHubClientID,
                        deviceCode.deviceCode,
                        deviceCode.interval
                    )
                    let user = try await apiClient.fetchUser(tokenResponse.accessToken)
                    try keychainService.saveAccessToken(tokenResponse.accessToken)
                    await send(.loginCompleted(user, tokenResponse.accessToken))
                } catch: { error, send in
                    await send(.loginFailed(error.localizedDescription))
                }
                
            case let .deviceCodeReceived(flowState):
                state.deviceFlowState = flowState
                return .none
                
            case let .loginCompleted(user, token):
                state.authState = .loggedIn(user: user, accessToken: token)
                state.deviceFlowState = nil
                return .send(.fetchUsage)
                
            case let .loginFailed(message):
                state.authState = .loggedOut
                state.deviceFlowState = nil
                state.errorMessage = message
                return .none
                
            case .logoutButtonTapped:
                return .run { send in
                    @Dependency(\.keychainService) var keychainService
                    try keychainService.deleteAccessToken()
                    await send(.logoutCompleted)
                } catch: { _, send in
                    await send(.logoutCompleted)
                }
                
            case .logoutCompleted:
                state.authState = .loggedOut
                state.usageSummary = nil
                state.detectedPlan = nil
                state.deviceFlowState = nil
                return .none
                
            case .fetchUsage:
                guard let token = state.authState.accessToken
                else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    @Dependency(\.gitHubAPIClient) var apiClient
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
                    await send(.usageResponse(summary))
                } catch: { error, send in
                    await send(.usageFailed(error.localizedDescription))
                }
                
            case let .usageResponse(summary):
                state.isLoading = false
                state.usageSummary = summary
                state.detectedPlan = summary.plan
                return .send(.checkUsageThresholds)
                
            case .checkUsageThresholds:
                guard let summary = state.usageSummary else { return .none }
                let tool = ToolKind.copilot
                let resetCycle = Self.copilotResetCycle()
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient
                    
                    if summary.isFreeTier {
                        // Free tier: check Chat and Completions separately
                        if let chatRemaining = summary.freeChatRemaining,
                           let chatTotal = summary.freeChatTotal, chatTotal > 0 {
                            let chatUsedPct = Int(round(Double(chatTotal - chatRemaining) / Double(chatTotal) * 100))
                            let chatThresholds = UsageThreshold.reached(by: chatUsedPct)
                            for threshold in chatThresholds {
                                let notifTool = "\(tool.id)-chat"
                                if !notificationClient.hasNotified(notifTool, threshold.rawValue, resetCycle) {
                                    let title = threshold.title(for: "\(tool.displayName) Chat")
                                    let body = threshold.body(usagePercent: chatUsedPct)
                                    try await notificationClient.send(
                                        "\(notifTool)-\(threshold.rawValue)", title, body
                                    )
                                    notificationClient.markNotified(notifTool, threshold.rawValue, resetCycle)
                                }
                            }
                        }
                        if let compRemaining = summary.freeCompletionsRemaining,
                           let compTotal = summary.freeCompletionsTotal, compTotal > 0 {
                            let compUsedPct = Int(round(Double(compTotal - compRemaining) / Double(compTotal) * 100))
                            let compThresholds = UsageThreshold.reached(by: compUsedPct)
                            for threshold in compThresholds {
                                let notifTool = "\(tool.id)-completions"
                                if !notificationClient.hasNotified(notifTool, threshold.rawValue, resetCycle) {
                                    let title = threshold.title(for: "\(tool.displayName) Completions")
                                    let body = threshold.body(usagePercent: compUsedPct)
                                    try await notificationClient.send(
                                        "\(notifTool)-\(threshold.rawValue)", title, body
                                    )
                                    notificationClient.markNotified(notifTool, threshold.rawValue, resetCycle)
                                }
                            }
                        }
                    } else {
                        // Paid tier: single usage percentage
                        let usedPct = Int(round(summary.usagePercentage * 100))
                        let thresholds = UsageThreshold.reached(by: usedPct)
                        for threshold in thresholds {
                            if !notificationClient.hasNotified(tool.id, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: tool.displayName)
                                let body = threshold.body(usagePercent: usedPct)
                                try await notificationClient.send(
                                    "\(tool.id)-\(threshold.rawValue)", title, body
                                )
                                notificationClient.markNotified(tool.id, threshold.rawValue, resetCycle)
                            }
                        }
                    }
                } catch: { _, _ in }

            // MARK: - Claude Code

            case .detectClaudeCredentials:
                state.isClaudeLoading = true
                state.claudeErrorMessage = nil
                return .run { send in
                    @Dependency(\.claudeAPIClient) var claudeClient
                    guard let credentials = try claudeClient.loadCredentials() else {
                        await send(.claudeUsageFailed("notDetected"))
                        return
                    }
                    // Refresh token if needed
                    let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
                    // Fetch usage
                    let response = try await claudeClient.fetchUsage(refreshed.accessToken)
                    let summary = ClaudeUsageSummary(
                        subscriptionType: refreshed.subscriptionType,
                        response: response
                    )
                    await send(.claudeUsageResponse(summary))
                } catch: { error, send in
                    await send(.claudeUsageFailed(error.localizedDescription))
                }

            case .fetchClaudeUsage:
                state.isClaudeLoading = true
                state.claudeErrorMessage = nil
                return .run { send in
                    @Dependency(\.claudeAPIClient) var claudeClient
                    guard let credentials = try claudeClient.loadCredentials() else {
                        await send(.claudeUsageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
                    let response = try await claudeClient.fetchUsage(refreshed.accessToken)
                    let summary = ClaudeUsageSummary(
                        subscriptionType: refreshed.subscriptionType,
                        response: response
                    )
                    await send(.claudeUsageResponse(summary))
                } catch: { error, send in
                    await send(.claudeUsageFailed(error.localizedDescription))
                }

            case let .claudeUsageResponse(summary):
                state.isClaudeLoading = false
                state.claudeConnectionState = .connected(subscriptionType: summary.subscriptionType)
                state.claudeUsageSummary = summary
                return .send(.checkClaudeUsageThresholds)

            case let .claudeUsageFailed(message):
                state.isClaudeLoading = false
                if message == "notDetected" {
                    state.claudeConnectionState = .notDetected
                    state.claudeErrorMessage = nil
                } else {
                    state.claudeErrorMessage = message
                }
                return .none

            case .checkClaudeUsageThresholds:
                guard let summary = state.claudeUsageSummary else { return .none }
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

                    // Session (5h)
                    if let pct = summary.sessionUtilization,
                       let resetCycle = summary.sessionResetsAt {
                        let thresholds = UsageThreshold.reached(by: pct)
                        for threshold in thresholds {
                            let toolWindow = "claudeCode-session"
                            if !notificationClient.hasNotified(toolWindow, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: "Claude Code Session")
                                let body = threshold.body(usagePercent: pct)
                                try await notificationClient.send(
                                    "\(toolWindow)-\(threshold.rawValue)", title, body
                                )
                                notificationClient.markNotified(toolWindow, threshold.rawValue, resetCycle)
                            }
                        }
                    }

                    // Weekly (7d)
                    if let pct = summary.weeklyUtilization,
                       let resetCycle = summary.weeklyResetsAt {
                        let thresholds = UsageThreshold.reached(by: pct)
                        for threshold in thresholds {
                            let toolWindow = "claudeCode-weekly"
                            if !notificationClient.hasNotified(toolWindow, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: "Claude Code Weekly")
                                let body = threshold.body(usagePercent: pct)
                                try await notificationClient.send(
                                    "\(toolWindow)-\(threshold.rawValue)", title, body
                                )
                                notificationClient.markNotified(toolWindow, threshold.rawValue, resetCycle)
                            }
                        }
                    }

                    // Opus (7d)
                    if let pct = summary.opusUtilization,
                       let resetCycle = summary.opusResetsAt {
                        let thresholds = UsageThreshold.reached(by: pct)
                        for threshold in thresholds {
                            let toolWindow = "claudeCode-opus"
                            if !notificationClient.hasNotified(toolWindow, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: "Claude Code Opus")
                                let body = threshold.body(usagePercent: pct)
                                try await notificationClient.send(
                                    "\(toolWindow)-\(threshold.rawValue)", title, body
                                )
                                notificationClient.markNotified(toolWindow, threshold.rawValue, resetCycle)
                            }
                        }
                    }
                } catch: { _, _ in }

            // MARK: - Codex

            case .detectCodexCredentials:
                state.isCodexLoading = true
                state.codexErrorMessage = nil
                return .run { send in
                    @Dependency(\.codexAPIClient) var codexClient
                    guard let credentials = try codexClient.loadCredentials() else {
                        await send(.codexUsageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await codexClient.refreshTokenIfNeeded(credentials)
                    let (headers, response) = try await codexClient.fetchUsage(
                        refreshed.accessToken, refreshed.accountId
                    )
                    let summary = CodexUsageSummary(headers: headers, response: response)
                    await send(.codexUsageResponse(summary))
                } catch: { error, send in
                    // Retry on 401: force refresh and try again
                    if let apiError = error as? CodexAPIError,
                       case let .httpError(statusCode, _) = apiError,
                       statusCode == 401
                    {
                        await send(.fetchCodexUsage)
                    } else {
                        await send(.codexUsageFailed(error.localizedDescription))
                    }
                }

            case .fetchCodexUsage:
                state.isCodexLoading = true
                state.codexErrorMessage = nil
                return .run { send in
                    @Dependency(\.codexAPIClient) var codexClient
                    guard let credentials = try codexClient.loadCredentials() else {
                        await send(.codexUsageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await codexClient.refreshTokenIfNeeded(credentials)
                    let (headers, response) = try await codexClient.fetchUsage(
                        refreshed.accessToken, refreshed.accountId
                    )
                    let summary = CodexUsageSummary(headers: headers, response: response)
                    await send(.codexUsageResponse(summary))
                } catch: { error, send in
                    await send(.codexUsageFailed(error.localizedDescription))
                }

            case let .codexUsageResponse(summary):
                state.isCodexLoading = false
                state.codexConnectionState = .connected(planType: summary.planType)
                state.codexUsageSummary = summary
                return .send(.checkCodexUsageThresholds)

            case let .codexUsageFailed(message):
                state.isCodexLoading = false
                if message == "notDetected" {
                    state.codexConnectionState = .notDetected
                    state.codexErrorMessage = nil
                } else {
                    state.codexErrorMessage = message
                }
                return .none

            case .checkCodexUsageThresholds:
                guard let summary = state.codexUsageSummary else { return .none }
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

                    // Session (5h)
                    if let pct = summary.sessionUsedPercent,
                       let resetAt = summary.sessionResetAt
                    {
                        let resetCycle = String(Int(resetAt.timeIntervalSince1970))
                        let thresholds = UsageThreshold.reached(by: pct)
                        for threshold in thresholds {
                            let toolWindow = "codex-session"
                            if !notificationClient.hasNotified(toolWindow, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: "Codex Session")
                                let body = threshold.body(usagePercent: pct)
                                try await notificationClient.send(
                                    "\(toolWindow)-\(threshold.rawValue)", title, body
                                )
                                notificationClient.markNotified(toolWindow, threshold.rawValue, resetCycle)
                            }
                        }
                    }

                    // Weekly (7d)
                    if let pct = summary.weeklyUsedPercent,
                       let resetAt = summary.weeklyResetAt
                    {
                        let resetCycle = String(Int(resetAt.timeIntervalSince1970))
                        let thresholds = UsageThreshold.reached(by: pct)
                        for threshold in thresholds {
                            let toolWindow = "codex-weekly"
                            if !notificationClient.hasNotified(toolWindow, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: "Codex Weekly")
                                let body = threshold.body(usagePercent: pct)
                                try await notificationClient.send(
                                    "\(toolWindow)-\(threshold.rawValue)", title, body
                                )
                                notificationClient.markNotified(toolWindow, threshold.rawValue, resetCycle)
                            }
                        }
                    }
                } catch: { _, _ in }

            case let .usageFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none
                
            case let .toggleToolExpansion(tool):
                guard tool.isAvailable else { return .none }
                if state.expandedTool == tool {
                    state.expandedTool = nil
                } else {
                    state.expandedTool = tool
                }
                return .none
                
            case .openVerificationURL:
                if let urlString = state.deviceFlowState?.verificationUri,
                   let url = URL(string: urlString) {
                    return .run { _ in
                        await MainActor.run {
                            _ = NSWorkspace.shared.open(url)
                        }
                    }
                }
                return .none
                
            case .copyUserCode:
                if let code = state.deviceFlowState?.userCode {
                    return .run { _ in
                        @Dependency(\.pasteboard) var pasteboard
                        pasteboard.setString(code)
                    }
                }
                return .none
                
            case .dismissError:
                state.errorMessage = nil
                return .none

            case .dismissClaudeError:
                state.claudeErrorMessage = nil
                return .none

            case .dismissCodexError:
                state.codexErrorMessage = nil
                return .none
                
            case .quitApp:
                return .run { _ in
                    await MainActor.run {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
}
