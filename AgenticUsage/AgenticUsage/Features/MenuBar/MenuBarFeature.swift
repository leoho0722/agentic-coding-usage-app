import AgenticCore
import ComposableArchitecture
import SwiftUI

@Reducer
struct MenuBarFeature {
    
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        var authState: AuthState = .loggedOut
        var usageSummary: CopilotUsageSummary?
        var selectedPlan: CopilotPlan = .pro
        var isLoading: Bool = false
        var errorMessage: String?
        var deviceFlowState: DeviceFlowState?
    }
    
    enum AuthState: Equatable, Sendable {
        case loggedOut
        case authenticating
        case loggedIn(user: GitHubUser, accessToken: String)
        
        var isLoggedIn: Bool {
            if case .loggedIn = self { return true }
            return false
        }
        
        var user: GitHubUser? {
            if case let .loggedIn(user, _) = self { return user }
            return nil
        }
        
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
        
        case planChanged(CopilotPlan)
        
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
                state.deviceFlowState = nil
                return .none
                
            case .fetchUsage:
                guard let token = state.authState.accessToken,
                      let user = state.authState.user
                else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let plan = state.selectedPlan
                let username = user.login
                return .run { send in
                    @Dependency(\.gitHubAPIClient) var apiClient
                    let period = DateUtils.currentBillingPeriod()
                    let response = try await apiClient.fetchPremiumRequestUsage(
                        token, username, period.year, period.month
                    )
                    let copilotUsage = response.usageItems
                        .filter { $0.product == "Copilot" }
                        .reduce(0) { $0 + $1.grossQuantity }
                    let summary = CopilotUsageSummary(
                        premiumRequestsUsed: copilotUsage,
                        planLimit: plan.limit,
                        plan: plan,
                        daysUntilReset: DateUtils.daysUntilReset()
                    )
                    await send(.usageResponse(summary))
                } catch: { error, send in
                    await send(.usageFailed(error.localizedDescription))
                }
                
            case let .usageResponse(summary):
                state.isLoading = false
                state.usageSummary = summary
                return .none
                
            case let .usageFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none
                
            case let .planChanged(plan):
                state.selectedPlan = plan
                if state.authState.isLoggedIn {
                    return .send(.fetchUsage)
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
