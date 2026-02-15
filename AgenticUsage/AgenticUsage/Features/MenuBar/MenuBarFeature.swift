import AgenticCore
import AppKit
import ComposableArchitecture

@Reducer
struct MenuBarFeature {
    
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        var authState: AuthState = .loggedOut
        var usageSummary: CopilotUsageSummary?
        var detectedPlan: CopilotPlan?
        var isLoading: Bool = false
        var errorMessage: String?
        var deviceFlowState: DeviceFlowState?
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
    
    // MARK: - Action
    
    enum Action: Equatable, Sendable {
        case onAppear
        case checkExistingAuth
        
        case loginButtonTapped
        case deviceCodeReceived(DeviceFlowState)
        case loginCompleted(GitHubUser, String)
        case loginFailed(String)
        case logoutButtonTapped
        case logoutCompleted
        
        case fetchUsage
        case usageResponse(CopilotUsageSummary)
        case usageFailed(String)
        
        case toggleToolExpansion(ToolKind)
        
        case openVerificationURL
        case copyUserCode
        case dismissError
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
    
    // MARK: - Body
    
    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
                
            case .onAppear:
                return .send(.checkExistingAuth)
                
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
                        // Free tier: use limited_user_quotas
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
                        // Paid tier: use quota_snapshots
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
                return .none
                
            case let .usageFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none
                
            case let .toggleToolExpansion(tool):
                // Only available tools can be expanded; coming soon tools are not expandable.
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
