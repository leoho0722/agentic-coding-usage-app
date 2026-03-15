import AppKit

import AgenticCore
import ComposableArchitecture

// MARK: - CopilotFeature

/// Copilot 工具的 TCA Reducer，管理 GitHub OAuth 認證、用量查詢與通知邏輯。
@Reducer
struct CopilotFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {

        /// Copilot 的 GitHub OAuth 認證狀態
        var authState: AuthState = .loggedOut

        /// Copilot 用量摘要
        var usageSummary: CopilotUsageSummary?

        /// 偵測到的 Copilot 方案類型
        var detectedPlan: CopilotPlan?

        /// Copilot 用量是否正在載入
        var isLoading: Bool = false

        /// Copilot 相關的錯誤訊息
        var errorMessage: String?

        /// GitHub Device Flow 認證的中繼狀態
        var deviceFlowState: DeviceFlowState?
    }

    /// Copilot 的 GitHub OAuth 認證狀態列舉。
    enum AuthState: Equatable, Sendable {

        /// 尚未登入
        case loggedOut

        /// 正在進行 Device Flow 認證
        case authenticating

        /// 已登入，附帶使用者資訊與存取權杖
        case loggedIn(user: GitHubUser, accessToken: String)

        /// 取得目前的存取權杖，僅在已登入狀態下回傳。
        var accessToken: String? {
            if case let .loggedIn(_, token) = self { return token }
            return nil
        }
    }

    /// GitHub Device Flow 認證過程中的中繼狀態，包含使用者驗證碼與驗證 URL。
    struct DeviceFlowState: Equatable, Sendable {

        /// 使用者需輸入的驗證碼
        let userCode: String

        /// GitHub 驗證頁面的 URL
        let verificationUri: String
    }

    // MARK: - Action

    enum Action: Equatable, Sendable {

        /// 檢查鑰匙圈中是否已有存取權杖
        case checkExistingAuth

        /// 使用者點擊登入按鈕
        case loginButtonTapped

        /// 收到 GitHub Device Flow 的驗證碼
        case deviceCodeReceived(DeviceFlowState)

        /// 登入成功，附帶使用者資訊與存取權杖
        case loginCompleted(GitHubUser, String)

        /// 登入失敗，附帶錯誤訊息
        case loginFailed(String)

        /// 使用者點擊登出按鈕
        case logoutButtonTapped

        /// 登出流程完成
        case logoutCompleted

        /// 開始擷取用量資料
        case fetchUsage

        /// 用量回應成功
        case usageResponse(CopilotUsageSummary)

        /// 用量擷取失敗
        case usageFailed(String)

        /// 檢查用量是否達到通知門檻
        case checkUsageThresholds

        /// 在瀏覽器中開啟 GitHub 驗證頁面
        case openVerificationURL

        /// 將 Device Flow 驗證碼複製到剪貼簿
        case copyUserCode

        /// 關閉錯誤訊息
        case dismissError
    }

    // MARK: - 常數

    /// GitHub OAuth App 的 Client ID，從 Info.plist 讀取。
    static let gitHubClientID: String = {
        guard let clientID = Bundle.main.infoDictionary?["GitHubClientID"] as? String,
              !clientID.isEmpty,
              clientID != "YOUR_GITHUB_CLIENT_ID_HERE" else {
            fatalError(
                """
                GitHubClientID not configured. \
                Copy Secrets.xcconfig.template to Secrets.xcconfig \
                and set your GitHub OAuth App client ID.
                """
            )
        }
        return clientID
    }()

    // MARK: - 重設週期輔助工具

    /// 取得 Copilot 每月重設週期的字串標識（UTC 時區的 "YYYY-MM" 格式）。
    private static func copilotResetCycle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    // MARK: - Reducer 主體

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
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
                guard let token = state.authState.accessToken else { 
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    @Dependency(\.gitHubAPIClient) var apiClient
                    let status = try await apiClient.fetchCopilotStatus(token)
                    let plan = CopilotPlan(from: status.copilotPlan)
                    let daysUntilReset = DateUtils.daysUntilReset()

                    let summary: CopilotUsageSummary
                    if plan == .free {
                        summary = CopilotUsageSummary(
                            plan: plan,
                            planLimit: plan?.limit ?? 0,
                            daysUntilReset: daysUntilReset,
                            freeChatRemaining: status.limitedUserQuotas?.chat,
                            freeChatTotal: status.monthlyQuotas?.chat,
                            freeCompletionsRemaining: status.limitedUserQuotas?.completions,
                            freeCompletionsTotal: status.monthlyQuotas?.completions
                        )
                    } else {
                        let premiumPercentRemaining = status.quotaSnapshots?.premiumInteractions?.percentRemaining
                        summary = CopilotUsageSummary(
                            plan: plan,
                            planLimit: plan?.limit ?? 0,
                            daysUntilReset: daysUntilReset,
                            premiumPercentRemaining: premiumPercentRemaining
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

            case let .usageFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .checkUsageThresholds:
                guard let summary = state.usageSummary else {
                    return .none
                }
                let tool = ToolKind.copilot
                let resetCycle = Self.copilotResetCycle()
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

                    if summary.isFreeTier {
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
            }
        }
    }
}
