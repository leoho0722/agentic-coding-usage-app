import AppKit

import AgenticCore
import AgenticUpdater
import ComposableArchitecture

// MARK: - MenuBarFeature

/// MenuBar 功能的 TCA Reducer，管理所有工具卡片的認證、用量查詢與通知邏輯。
@Reducer
struct MenuBarFeature {
    
    // MARK: - State
    
    /// MenuBar 功能的可觀察狀態，包含 Copilot、Claude Code、Codex 三個工具的完整狀態。
    @ObservableState
    struct State: Equatable {
        
        // MARK: Copilot
        
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
        
        // MARK: Claude Code
        
        /// Claude Code 的連線狀態
        var claudeConnectionState: ClaudeConnectionState = .notDetected
        
        /// Claude Code 用量摘要
        var claudeUsageSummary: ClaudeUsageSummary?
        
        /// Claude Code 用量是否正在載入
        var isClaudeLoading: Bool = false
        
        /// Claude Code 相關的錯誤訊息
        var claudeErrorMessage: String?
        
        // MARK: Codex

        /// Codex 的連線狀態
        var codexConnectionState: CodexConnectionState = .notDetected

        /// Codex 用量摘要
        var codexUsageSummary: CodexUsageSummary?

        /// Codex 用量是否正在載入
        var isCodexLoading: Bool = false

        /// Codex 相關的錯誤訊息
        var codexErrorMessage: String?

        // MARK: Antigravity

        /// Antigravity 的連線狀態
        var antigravityConnectionState: AntigravityConnectionState = .notDetected

        /// Antigravity 用量摘要
        var antigravityUsageSummary: AntigravityUsageSummary?

        /// Antigravity 用量是否正在載入
        var isAntigravityLoading: Bool = false

        /// Antigravity 相關的錯誤訊息
        var antigravityErrorMessage: String?

        /// 目前展開的工具卡片（手風琴），預設為 Copilot
        var expandedTool: ToolKind? = .copilot

        // MARK: Update

        /// 檢查到的更新資訊（nil = 無更新或尚未檢查）
        var updateInfo: UpdateInfo?

        /// 正在下載/安裝
        var isUpdating: Bool = false

        /// 更新錯誤訊息
        var updateError: String?
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
    
    /// Claude Code 的連線狀態列舉。
    enum ClaudeConnectionState: Equatable, Sendable {
        
        /// 未偵測到本地憑證
        case notDetected
        
        /// 已連線，附帶訂閱方案類型
        case connected(plan: ClaudePlan?)
    }
    
    /// Codex 的連線狀態列舉。
    enum CodexConnectionState: Equatable, Sendable {

        /// 未偵測到本地憑證
        case notDetected

        /// 已連線，附帶方案類型
        case connected(plan: CodexPlan?)
    }

    /// Antigravity 的連線狀態列舉。
    enum AntigravityConnectionState: Equatable, Sendable {

        /// 未偵測到本地憑證
        case notDetected

        /// 已連線，附帶方案類型
        case connected(plan: AntigravityPlan?)
    }
    
    // MARK: - Action
    
    /// MenuBar 功能的所有可觸發動作。
    enum Action: Equatable, Sendable {
        
        /// 畫面出現時觸發，負責初始化所有工具的狀態
        case onAppear
        
        /// 檢查鑰匙圈中是否已有 Copilot 的存取權杖
        case checkExistingAuth
        
        /// 向使用者請求本地通知授權
        case requestNotificationAuthorization
        
        // MARK: Copilot
        
        
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
        
        /// 開始擷取 Copilot 用量資料
        case fetchUsage
        
        
        /// Copilot 用量回應成功
        case usageResponse(CopilotUsageSummary)
        
        
        /// Copilot 用量擷取失敗
        case usageFailed(String)
        
        
        /// 檢查 Copilot 用量是否達到通知門檻
        case checkUsageThresholds
        
        // MARK: Claude Code
        
        /// 偵測本機是否存在 Claude Code 憑證
        case detectClaudeCredentials
        
        /// 手動重新擷取 Claude Code 用量
        case fetchClaudeUsage
        
        /// Claude Code 用量回應成功
        case claudeUsageResponse(ClaudeUsageSummary)
        
        /// Claude Code 用量擷取失敗
        case claudeUsageFailed(String)
        
        /// 檢查 Claude Code 用量是否達到通知門檻
        case checkClaudeUsageThresholds
        
        // MARK: Codex
        
        /// 偵測本機是否存在 Codex 憑證
        case detectCodexCredentials
        
        /// 手動重新擷取 Codex 用量
        case fetchCodexUsage
        
        /// Codex 用量回應成功
        case codexUsageResponse(CodexUsageSummary)
        
        /// Codex 用量擷取失敗
        case codexUsageFailed(String)
        
        /// 檢查 Codex 用量是否達到通知門檻
        case checkCodexUsageThresholds

        // MARK: Antigravity

        /// 偵測本機是否存在 Antigravity 憑證
        case detectAntigravityCredentials

        /// 手動重新擷取 Antigravity 用量
        case fetchAntigravityUsage

        /// Antigravity 用量回應成功
        case antigravityUsageResponse(AntigravityUsageSummary)

        /// Antigravity 用量擷取失敗
        case antigravityUsageFailed(String)

        /// 檢查 Antigravity 用量是否達到通知門檻
        case checkAntigravityUsageThresholds

        // MARK: Update

        /// 啟動時檢查更新
        case checkForUpdate

        /// 檢查到新版本
        case updateAvailable(UpdateInfo)

        /// 已是最新版本
        case updateNotAvailable

        /// 檢查更新失敗（靜默處理）
        case updateCheckFailed(String)

        /// 使用者點擊「更新」按鈕
        case performUpdate

        /// 更新完成，準備重啟
        case updateCompleted

        /// 更新失敗
        case updateFailed(String)

        /// 關閉更新錯誤訊息
        case dismissUpdateError

        // MARK: UI

        /// 切換指定工具卡片的展開/收合狀態
        case toggleToolExpansion(ToolKind)
        
        /// 在瀏覽器中開啟 GitHub 驗證頁面
        case openVerificationURL
        
        /// 將 Device Flow 驗證碼複製到剪貼簿
        case copyUserCode
        
        /// 關閉 Copilot 錯誤訊息
        case dismissError
        
        /// 關閉 Claude Code 錯誤訊息
        case dismissClaudeError
        
        /// 關閉 Codex 錯誤訊息
        case dismissCodexError

        /// 關閉 Antigravity 錯誤訊息
        case dismissAntigravityError

        /// 結束應用程式
        case quitApp
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
    /// - Returns: 當前月份的字串，例如 "2026-02"
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
            case .onAppear:
                // 同時啟動所有工具的初始化流程、通知授權與更新檢查
                return .merge(
                    .send(.checkExistingAuth),
                    .send(.detectClaudeCredentials),
                    .send(.detectCodexCredentials),
                    .send(.detectAntigravityCredentials),
                    .send(.requestNotificationAuthorization),
                    .send(.checkForUpdate)
                )
                
            case .requestNotificationAuthorization:
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient
                    _ = try await notificationClient.requestAuthorization()
                } catch: { _, _ in }
                
            case .checkExistingAuth:
                // 嘗試從鑰匙圈還原已儲存的存取權杖
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
                
                // 1. 向 GitHub 請求 Device Code
                // 2. 輪詢等待使用者授權
                // 3. 取得存取權杖後驗證使用者身份並儲存至鑰匙圈
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
                // 從鑰匙圈刪除存取權杖，無論成功與否都完成登出
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
                    
                    // 根據方案類型組裝不同結構的用量摘要
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
                        let premiumPercentRemaining = status.quotaSnapshots?.premiumInteractions?.percentRemaining
                        summary = CopilotUsageSummary(
                            plan: plan,
                            planLimit: plan.limit,
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
                
            case .checkUsageThresholds:
                guard let summary = state.usageSummary else { return .none }
                let tool = ToolKind.copilot
                let resetCycle = Self.copilotResetCycle()
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient
                    
                    if summary.isFreeTier {
                        // 免費方案：分別檢查 Chat 和 Completions 的門檻
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
                        // 付費方案：使用單一百分比計算門檻
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
                
                // 1. 從本機載入憑證
                // 2. 必要時重新整理存取權杖
                // 3. 擷取用量資料
                return .run { send in
                    @Dependency(\.claudeAPIClient) var claudeClient
                    guard let credentials = try claudeClient.loadCredentials() else {
                        await send(.claudeUsageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
                    let response = try await claudeClient.fetchUsage(refreshed.accessToken)
                    let summary = ClaudeUsageSummary(
                        plan: ClaudePlan.fromAPIString(refreshed.subscriptionType),
                        response: response
                    )
                    await send(.claudeUsageResponse(summary))
                } catch: { error, send in
                    if let apiError = error as? ClaudeAPIError {
                        switch apiError {
                        case .refreshFailed(let statusCode, _) where statusCode == 400:
                            await send(.claudeUsageFailed("notDetected"))
                        case .insufficientScope:
                            await send(.claudeUsageFailed("notDetected"))
                        default:
                            await send(.claudeUsageFailed(error.localizedDescription))
                        }
                    } else {
                        await send(.claudeUsageFailed(error.localizedDescription))
                    }
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
                        plan: ClaudePlan.fromAPIString(refreshed.subscriptionType),
                        response: response
                    )
                    await send(.claudeUsageResponse(summary))
                } catch: { error, send in
                    if let apiError = error as? ClaudeAPIError {
                        switch apiError {
                        case .refreshFailed(let statusCode, _) where statusCode == 400:
                            await send(.claudeUsageFailed("notDetected"))
                        case .insufficientScope:
                            await send(.claudeUsageFailed("notDetected"))
                        default:
                            await send(.claudeUsageFailed(error.localizedDescription))
                        }
                    } else {
                        await send(.claudeUsageFailed(error.localizedDescription))
                    }
                }

            case let .claudeUsageResponse(summary):
                state.isClaudeLoading = false
                state.claudeConnectionState = .connected(plan: summary.plan)
                state.claudeUsageSummary = summary
                return .send(.checkClaudeUsageThresholds)
                
            case let .claudeUsageFailed(message):
                state.isClaudeLoading = false
                
                // "notDetected" 為特殊標記，表示無本地憑證而非真正的錯誤
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
                    
                    // 工作階段用量（5 小時窗口）
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
                    
                    // 每週用量（7 天窗口）
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
                    
                    // Opus 模型用量（7 天窗口）
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
                    // 收到 401 時，嘗試強制重新整理權杖後重試
                    if let apiError = error as? CodexAPIError,
                       case let .httpError(statusCode, _) = apiError,
                       statusCode == 401 {
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
                state.codexConnectionState = .connected(plan: summary.plan)
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
                    
                    // 工作階段用量（5 小時窗口）
                    if let pct = summary.sessionUsedPercent,
                       let resetAt = summary.sessionResetAt {
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
                    
                    // 每週用量（7 天窗口）
                    if let pct = summary.weeklyUsedPercent,
                       let resetAt = summary.weeklyResetAt {
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

                // MARK: - Antigravity

            case .detectAntigravityCredentials:
                state.isAntigravityLoading = true
                state.antigravityErrorMessage = nil
                return .run { send in
                    @Dependency(\.antigravityAPIClient) var antigravityClient
                    guard let credentials = try antigravityClient.loadCredentials() else {
                        await send(.antigravityUsageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await antigravityClient.refreshTokenIfNeeded(credentials)
                    let response = try await antigravityClient.fetchUsage(refreshed.accessToken)
                    let summary = AntigravityUsageSummary(plan: nil, response: response)
                    await send(.antigravityUsageResponse(summary))
                } catch: { error, send in
                    // 收到 401 時，嘗試強制重新整理權杖後重試
                    if let apiError = error as? AntigravityAPIError,
                       case let .httpError(statusCode, _) = apiError,
                       statusCode == 401 {
                        await send(.fetchAntigravityUsage)
                    } else {
                        await send(.antigravityUsageFailed(error.localizedDescription))
                    }
                }

            case .fetchAntigravityUsage:
                state.isAntigravityLoading = true
                state.antigravityErrorMessage = nil
                return .run { send in
                    @Dependency(\.antigravityAPIClient) var antigravityClient
                    guard let credentials = try antigravityClient.loadCredentials() else {
                        await send(.antigravityUsageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await antigravityClient.refreshTokenIfNeeded(credentials)
                    let response = try await antigravityClient.fetchUsage(refreshed.accessToken)
                    let summary = AntigravityUsageSummary(plan: nil, response: response)
                    await send(.antigravityUsageResponse(summary))
                } catch: { error, send in
                    await send(.antigravityUsageFailed(error.localizedDescription))
                }

            case let .antigravityUsageResponse(summary):
                state.isAntigravityLoading = false
                state.antigravityConnectionState = .connected(plan: summary.plan)
                state.antigravityUsageSummary = summary
                return .send(.checkAntigravityUsageThresholds)

            case let .antigravityUsageFailed(message):
                state.isAntigravityLoading = false

                if message == "notDetected" {
                    state.antigravityConnectionState = .notDetected
                    state.antigravityErrorMessage = nil
                } else {
                    state.antigravityErrorMessage = message
                }
                return .none

            case .checkAntigravityUsageThresholds:
                guard let summary = state.antigravityUsageSummary else { return .none }
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

                    // 逐模型檢查門檻
                    for modelUsage in summary.modelUsages {
                        let pct = modelUsage.usedPercent
                        let resetCycle: String
                        if let resetAt = modelUsage.resetAt {
                            resetCycle = String(Int(resetAt.timeIntervalSince1970))
                        } else {
                            resetCycle = "unknown"
                        }
                        let thresholds = UsageThreshold.reached(by: pct)
                        for threshold in thresholds {
                            let toolWindow = "antigravity-\(modelUsage.modelID)"
                            if !notificationClient.hasNotified(toolWindow, threshold.rawValue, resetCycle) {
                                let title = threshold.title(for: "Antigravity \(modelUsage.displayName)")
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

                // MARK: - Update

            case .checkForUpdate:
                return .run { send in
                    @Dependency(\.updateClient) var updateClient
                    let currentVersion = Bundle.main.shortVersionString
                    if let info = try await updateClient.checkForUpdate(currentVersion) {
                        await send(.updateAvailable(info))
                    } else {
                        await send(.updateNotAvailable)
                    }
                } catch: { error, send in
                    await send(.updateCheckFailed(error.localizedDescription))
                }

            case let .updateAvailable(info):
                state.updateInfo = info
                return .none

            case .updateNotAvailable:
                state.updateInfo = nil
                return .none

            case .updateCheckFailed:
                // 靜默處理，不顯示錯誤
                return .none

            case .performUpdate:
                guard let info = state.updateInfo else { return .none }
                state.isUpdating = true
                state.updateError = nil
                return .run { send in
                    @Dependency(\.updateClient) var updateClient
                    let currentAppPath = Bundle.main.bundleURL.path
                    try await updateClient.performUpdate(info, currentAppPath)
                    await send(.updateCompleted)
                } catch: { error, send in
                    await send(.updateFailed(error.localizedDescription))
                }

            case .updateCompleted:
                state.isUpdating = false
                // 重啟 App：先啟動延遲 shell 再立即結束自己
                return .run { _ in
                    @Dependency(\.updateClient) var updateClient
                    let appPath = Bundle.main.bundleURL.path
                    try updateClient.relaunchApp(appPath)
                    await MainActor.run {
                        NSApplication.shared.terminate(nil)
                    }
                } catch: { _, _ in }

            case let .updateFailed(message):
                state.isUpdating = false
                state.updateError = message
                return .none

            case .dismissUpdateError:
                state.updateError = nil
                return .none

            case let .toggleToolExpansion(tool):
                // 僅已啟用的工具才可展開
                guard tool.isAvailable else {
                    return .none
                }
                
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

            case .dismissAntigravityError:
                state.antigravityErrorMessage = nil
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
