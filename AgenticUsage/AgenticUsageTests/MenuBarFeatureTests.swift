import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUpdater
@testable import AgenticUsage

@MainActor
@Suite("MenuBarFeature", .serialized)
struct MenuBarFeatureTests {

    // MARK: - Copilot: loginCompleted

    /// 驗證登入完成後設定 loggedIn 狀態並觸發 fetchUsage
    @Test
    func loginCompleted_setsLoggedInState_andTriggersUsage() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        } withDependencies: {
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }
        let user = GitHubUser(login: "test", name: "Test User")
        await store.send(.loginCompleted(user, "token123")) {
            $0.authState = .loggedIn(user: user, accessToken: "token123")
            $0.deviceFlowState = nil
        }
        // loginCompleted 觸發 fetchUsage
        await store.receive(\.fetchUsage) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        // fetchUsage 觸發 usageResponse
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.detectedPlan = .pro
        }
        // usageResponse 觸發 checkUsageThresholds（無可見狀態變更）
        await store.receive(\.checkUsageThresholds)
    }

    /// 驗證登入失敗後重設狀態為 loggedOut 並設定錯誤訊息
    @Test
    func loginFailed_resetsState() async {
        var state = MenuBarFeature.State()
        state.authState = .authenticating
        state.deviceFlowState = MenuBarFeature.DeviceFlowState(
            userCode: "CODE", verificationUri: "https://example.com"
        )
        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.loginFailed("Something went wrong")) {
            $0.authState = .loggedOut
            $0.deviceFlowState = nil
            $0.errorMessage = "Something went wrong"
        }
    }

    // MARK: - Copilot: logoutCompleted

    /// 驗證登出完成後清除所有 Copilot 相關狀態
    @Test
    func logoutCompleted_resetsAllCopilotState() async {
        var state = MenuBarFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.usageSummary = CopilotUsageSummary(plan: .pro, planLimit: 300, daysUntilReset: 10, premiumPercentRemaining: 80.0)
        state.detectedPlan = .pro

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.logoutCompleted) {
            $0.authState = .loggedOut
            $0.usageSummary = nil
            $0.detectedPlan = nil
            $0.deviceFlowState = nil
        }
    }

    // MARK: - Copilot: usageResponse / usageFailed

    /// 驗證收到使用量回應後正確設定 usageSummary 與 detectedPlan
    @Test
    func usageResponse_setsState() async {
        var state = MenuBarFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.isLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        let summary = CopilotUsageSummary(
            plan: .proPlus, planLimit: 1500, daysUntilReset: 15,
            premiumPercentRemaining: 60.0
        )
        await store.send(.usageResponse(summary)) {
            $0.isLoading = false
            $0.usageSummary = summary
            $0.detectedPlan = .proPlus
        }
        await store.receive(\.checkUsageThresholds)
    }

    /// 驗證使用量查詢失敗時設定錯誤訊息並停止載入
    @Test
    func usageFailed_setsError() async {
        var state = MenuBarFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.usageFailed("Network error")) {
            $0.isLoading = false
            $0.errorMessage = "Network error"
        }
    }

    // MARK: - Copilot: deviceCodeReceived

    /// 驗證收到 Device Code 後正確設定 deviceFlowState
    @Test
    func deviceCodeReceived_setsFlowState() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let flowState = MenuBarFeature.DeviceFlowState(
            userCode: "ABCD-1234",
            verificationUri: "https://github.com/login/device"
        )
        await store.send(.deviceCodeReceived(flowState)) {
            $0.deviceFlowState = flowState
        }
    }

    // MARK: - Claude

    /// 驗證 Claude 使用量回應後設定 connected 狀態與 summary，並快取憑證
    @Test
    func claudeUsageResponse_setsConnectedState() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let credentials = ClaudeOAuth(accessToken: "tok", subscriptionType: "pro")
        let summary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 30.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
            )
        )
        await store.send(.claudeUsageResponse(summary, credentials)) {
            $0.isClaudeLoading = false
            $0.claudeConnectionState = .connected(plan: .pro)
            $0.claudeUsageSummary = summary
            $0.cachedClaudeCredentials = credentials
        }
        await store.receive(\.checkClaudeUsageThresholds)
    }

    /// 驗證 Claude 使用量失敗且為 notDetected 時重設連線狀態並清除快取
    @Test
    func claudeUsageFailed_notDetected_resetsState() async {
        var state = MenuBarFeature.State()
        state.isClaudeLoading = true
        state.claudeConnectionState = .connected(plan: .pro)
        state.cachedClaudeCredentials = ClaudeOAuth(accessToken: "old")

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.claudeUsageFailed("notDetected")) {
            $0.isClaudeLoading = false
            $0.claudeConnectionState = .notDetected
            $0.claudeErrorMessage = nil
            $0.cachedClaudeCredentials = nil
        }
    }

    /// 驗證 Claude 使用量失敗且為實際錯誤時設定錯誤訊息
    @Test
    func claudeUsageFailed_realError_setsMessage() async {
        var state = MenuBarFeature.State()
        state.isClaudeLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.claudeUsageFailed("HTTP 500")) {
            $0.isClaudeLoading = false
            $0.claudeErrorMessage = "HTTP 500"
        }
    }

    // MARK: - Codex

    /// 驗證 Codex 使用量回應後設定 connected 狀態與 summary，並快取憑證
    @Test
    func codexUsageResponse_setsConnectedState() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let credentials = CodexOAuth(accessToken: "tok", accountId: "acc1")
        let summary = CodexUsageSummary(
            headers: CodexUsageHeaders(primaryUsedPercent: 30.0),
            response: CodexUsageResponse(planType: "plus")
        )
        await store.send(.codexUsageResponse(summary, credentials)) {
            $0.isCodexLoading = false
            $0.codexConnectionState = .connected(plan: .plus)
            $0.codexUsageSummary = summary
            $0.cachedCodexCredentials = credentials
        }
        await store.receive(\.checkCodexUsageThresholds)
    }

    /// 驗證 Codex 使用量失敗且為 notDetected 時重設連線狀態並清除快取
    @Test
    func codexUsageFailed_notDetected() async {
        var state = MenuBarFeature.State()
        state.isCodexLoading = true
        state.cachedCodexCredentials = CodexOAuth(accessToken: "old")

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.codexUsageFailed("notDetected")) {
            $0.isCodexLoading = false
            $0.codexConnectionState = .notDetected
            $0.codexErrorMessage = nil
            $0.cachedCodexCredentials = nil
        }
    }

    /// 驗證 Codex 使用量失敗且為實際錯誤時設定錯誤訊息
    @Test
    func codexUsageFailed_realError() async {
        var state = MenuBarFeature.State()
        state.isCodexLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.codexUsageFailed("Timeout")) {
            $0.isCodexLoading = false
            $0.codexErrorMessage = "Timeout"
        }
    }

    // MARK: - Antigravity

    /// 驗證 Antigravity 使用量回應後設定 connected 狀態與 summary
    @Test
    func antigravityUsageResponse_setsConnectedState() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let summary = AntigravityUsageSummary(
            plan: nil,
            response: AntigravityUsageResponse(models: [
                "m": AntigravityModelInfo(
                    displayName: "Gemini 3",
                    quotaInfo: AntigravityQuotaInfo(remainingFraction: 0.8)
                ),
            ])
        )
        await store.send(.antigravityUsageResponse(summary)) {
            $0.isAntigravityLoading = false
            $0.antigravityConnectionState = .connected(plan: nil)
            $0.antigravityUsageSummary = summary
        }
        await store.receive(\.checkAntigravityUsageThresholds)
    }

    /// 驗證 Antigravity 使用量失敗且為 notDetected 時重設連線狀態
    @Test
    func antigravityUsageFailed_notDetected() async {
        var state = MenuBarFeature.State()
        state.isAntigravityLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.antigravityUsageFailed("notDetected")) {
            $0.isAntigravityLoading = false
            $0.antigravityConnectionState = .notDetected
            $0.antigravityErrorMessage = nil
        }
    }

    /// 驗證 Antigravity 使用量失敗且為實際錯誤時設定錯誤訊息
    @Test
    func antigravityUsageFailed_realError() async {
        var state = MenuBarFeature.State()
        state.isAntigravityLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.antigravityUsageFailed("Auth error")) {
            $0.isAntigravityLoading = false
            $0.antigravityErrorMessage = "Auth error"
        }
    }

    // MARK: - Update

    /// 驗證有可用更新時正確設定 updateInfo
    @Test
    func updateAvailable_setsInfo() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let release = GitHubRelease(
            tagName: "v2.0.0", name: "v2.0.0", body: "Changes",
            htmlUrl: "https://github.com/test/releases/tag/v2.0.0", assets: []
        )
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("2.0.0")!,
            release: release
        )
        await store.send(.updateAvailable(info)) {
            $0.updateInfo = info
            $0.settings.updateInfo = info
        }
    }

    /// 驗證無可用更新時清除 updateInfo
    @Test
    func updateNotAvailable_clearsInfo() async {
        let release = GitHubRelease(
            tagName: "v2.0.0", name: "v2.0.0", body: "Changes",
            htmlUrl: "https://github.com/test/releases/tag/v2.0.0", assets: []
        )
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("2.0.0")!,
            release: release
        )
        var state = MenuBarFeature.State()
        state.updateInfo = info
        state.settings.updateInfo = info

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.updateNotAvailable) {
            $0.updateInfo = nil
            $0.settings.updateInfo = nil
        }
    }

    /// 驗證更新失敗時設定錯誤訊息並停止更新狀態
    @Test
    func updateFailed_setsError() async {
        var state = MenuBarFeature.State()
        state.isUpdating = true
        state.settings.isUpdating = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.updateFailed("Download failed")) {
            $0.isUpdating = false
            $0.settings.isUpdating = false
            $0.updateError = "Download failed"
        }
    }

    /// 驗證關閉更新錯誤提示後清除 updateError
    @Test
    func dismissUpdateError_clearsError() async {
        var state = MenuBarFeature.State()
        state.updateError = "Some error"

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.dismissUpdateError) {
            $0.updateError = nil
        }
    }

    // MARK: - Settings

    /// 驗證 Settings 子功能的 performUpdate 動作轉發至父層
    @Test
    func settings_performUpdate_forwardsToParent() async {
        let release = GitHubRelease(
            tagName: "v2.0.0", name: "v2.0.0", body: "Changes",
            htmlUrl: "https://github.com/test/releases/tag/v2.0.0", assets: []
        )
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("2.0.0")!,
            release: release
        )
        var state = MenuBarFeature.State()
        state.updateInfo = info
        state.settings.updateInfo = info

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.updateClient = .init(
                checkForUpdate: { _ in nil },
                performUpdate: { _, _ in
                    throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
                },
                relaunchApp: { _ in }
            )
        }
        await store.send(.settings(.performUpdate))
        await store.receive(\.performUpdate) {
            $0.isUpdating = true
            $0.settings.isUpdating = true
            $0.updateError = nil
        }
        await store.receive(\.updateFailed) {
            $0.isUpdating = false
            $0.settings.isUpdating = false
            $0.updateError = "test error"
        }
    }

    // MARK: - toggleToolExpansion

    /// 驗證展開不同工具時切換 expandedTool 為新工具
    @Test
    func toggleToolExpansion_expandsDifferentTool() async {
        var state = MenuBarFeature.State()
        state.expandedTool = .copilot

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.toggleToolExpansion(.claudeCode)) {
            $0.expandedTool = .claudeCode
        }
    }

    /// 驗證收合已展開的同一工具時 expandedTool 設為 nil
    @Test
    func toggleToolExpansion_collapsesSameTool() async {
        var state = MenuBarFeature.State()
        state.expandedTool = .copilot

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.toggleToolExpansion(.copilot)) {
            $0.expandedTool = nil
        }
    }

    /// 驗證從無展開狀態展開工具時正確設定 expandedTool
    @Test
    func toggleToolExpansion_expandsFromNone() async {
        var state = MenuBarFeature.State()
        state.expandedTool = nil

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.toggleToolExpansion(.codex)) {
            $0.expandedTool = .codex
        }
    }

    // MARK: - dismissError series

    /// 驗證 dismissError 清除 Copilot 錯誤訊息
    @Test
    func dismissError_clearsMessage() async {
        var state = MenuBarFeature.State()
        state.errorMessage = "Some error"

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }

    /// 驗證 dismissClaudeError 清除 Claude 錯誤訊息
    @Test
    func dismissClaudeError_clearsMessage() async {
        var state = MenuBarFeature.State()
        state.claudeErrorMessage = "Claude error"

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.dismissClaudeError) {
            $0.claudeErrorMessage = nil
        }
    }

    /// 驗證 dismissCodexError 清除 Codex 錯誤訊息
    @Test
    func dismissCodexError_clearsMessage() async {
        var state = MenuBarFeature.State()
        state.codexErrorMessage = "Codex error"

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.dismissCodexError) {
            $0.codexErrorMessage = nil
        }
    }

    /// 驗證 dismissAntigravityError 清除 Antigravity 錯誤訊息
    @Test
    func dismissAntigravityError_clearsMessage() async {
        var state = MenuBarFeature.State()
        state.antigravityErrorMessage = "AG error"

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.dismissAntigravityError) {
            $0.antigravityErrorMessage = nil
        }
    }

    // MARK: - onAppear: hasInitialized guard

    /// 驗證第二次 onAppear 不觸發任何動作（hasInitialized guard）
    @Test
    func onAppear_secondTime_isNoOp() async {
        var state = MenuBarFeature.State()
        state.hasInitialized = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.onAppear)
        // hasInitialized 為 true，不觸發任何子動作，也不變更狀態
    }

    // MARK: - Auto-Refresh

    /// 驗證 menuDidAppear 設定 isMenuVisible 並立即刷新已連線服務 + 啟動計時器
    @Test
    func menuDidAppear_refreshesAndStartsTimer() async {
        let testClock = TestClock()

        var state = MenuBarFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.continuousClock = testClock
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }

        await store.send(.menuDidAppear(.seconds30)) {
            $0.isMenuVisible = true
        }

        // 立即刷新：Copilot fetchUsage
        await store.receive(\.fetchUsage) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        // Copilot 用量回應
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.detectedPlan = .pro
        }
        await store.receive(\.checkUsageThresholds)

        // 關閉選單以取消計時器
        await store.send(.menuDidDisappear) {
            $0.isMenuVisible = false
        }
    }

    /// 驗證 menuDidDisappear 取消計時器
    @Test
    func menuDidDisappear_cancelsTimer() async {
        var state = MenuBarFeature.State()
        state.isMenuVisible = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.menuDidDisappear) {
            $0.isMenuVisible = false
        }
    }

    /// 驗證 autoRefreshTick 僅刷新已連線且非載入中的服務
    @Test
    func autoRefreshTick_onlyRefreshesConnectedNonLoading() async {
        var state = MenuBarFeature.State()
        
        // Copilot: 已登入，非載入中 → 應刷新
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.isLoading = false
        
        // Claude: 已連線，但正在載入中 → 不應刷新
        state.claudeConnectionState = .connected(plan: .pro)
        state.isClaudeLoading = true
        
        // Codex: 未連線 → 不應刷新
        state.codexConnectionState = .notDetected

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }

        await store.send(.autoRefreshTick)

        // 僅 Copilot 被刷新
        await store.receive(\.fetchUsage) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.detectedPlan = .pro
        }
        await store.receive(\.checkUsageThresholds)
    }

    /// 驗證 refreshInterval 為 disabled 時不啟動計時器
    @Test
    func menuDidAppear_disabled_noTimer() async {
        var state = MenuBarFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }

        await store.send(.menuDidAppear(.disabled)) {
            $0.isMenuVisible = true
        }

        // 僅立即刷新一次，不啟動計時器
        await store.receive(\.fetchUsage) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.detectedPlan = .pro
        }
        await store.receive(\.checkUsageThresholds)
        // 無計時器 → 不需要 menuDidDisappear 來取消
    }

    /// 驗證 autoRefreshClaudeUsage 使用快取憑證，不呼叫 loadCredentials
    @Test
    func autoRefreshClaudeUsage_usesCachedCredentials() async {
        let cachedCredentials = ClaudeOAuth(accessToken: "cached-tok", subscriptionType: "pro")

        var state = MenuBarFeature.State()
        state.claudeConnectionState = .connected(plan: .pro)
        state.cachedClaudeCredentials = cachedCredentials

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.claudeAPIClient = ClaudeAPIClient(
                loadCredentials: { fatalError("loadCredentials 不應被呼叫") },
                refreshTokenIfNeeded: { current in current },
                fetchUsage: { _ in
                    ClaudeUsageResponse(
                        fiveHour: ClaudeUsagePeriod(utilization: 30.0, resetsAt: nil),
                        sevenDay: ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
                    )
                }
            )
        }

        await store.send(.autoRefreshClaudeUsage) {
            $0.isClaudeLoading = true
            $0.claudeErrorMessage = nil
        }

        let expectedSummary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 30.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
            )
        )
        await store.receive(\.claudeUsageResponse) {
            $0.isClaudeLoading = false
            $0.claudeConnectionState = .connected(plan: .pro)
            $0.claudeUsageSummary = expectedSummary
            $0.cachedClaudeCredentials = cachedCredentials
        }
        await store.receive(\.checkClaudeUsageThresholds)
    }

    /// 驗證 autoRefreshCodexUsage 使用快取憑證，不呼叫 loadCredentials
    @Test
    func autoRefreshCodexUsage_usesCachedCredentials() async {
        let cachedCredentials = CodexOAuth(accessToken: "cached-tok", accountId: "acc1")

        var state = MenuBarFeature.State()
        state.codexConnectionState = .connected(plan: .plus)
        state.cachedCodexCredentials = cachedCredentials

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.codexAPIClient = CodexAPIClient(
                loadCredentials: { fatalError("loadCredentials 不應被呼叫") },
                refreshTokenIfNeeded: { current in current },
                fetchUsage: { _, _ in
                    (
                        CodexUsageHeaders(primaryUsedPercent: 30.0),
                        CodexUsageResponse(planType: "plus")
                    )
                }
            )
        }

        await store.send(.autoRefreshCodexUsage) {
            $0.isCodexLoading = true
            $0.codexErrorMessage = nil
        }

        let expectedSummary = CodexUsageSummary(
            headers: CodexUsageHeaders(primaryUsedPercent: 30.0),
            response: CodexUsageResponse(planType: "plus")
        )
        await store.receive(\.codexUsageResponse) {
            $0.isCodexLoading = false
            $0.codexConnectionState = .connected(plan: .plus)
            $0.codexUsageSummary = expectedSummary
            $0.cachedCodexCredentials = cachedCredentials
        }
        await store.receive(\.checkCodexUsageThresholds)
    }

    /// 驗證 autoRefreshClaudeUsage 無快取憑證時不執行任何動作
    @Test
    func autoRefreshClaudeUsage_noCachedCredentials_isNoOp() async {
        var state = MenuBarFeature.State()
        state.claudeConnectionState = .connected(plan: .pro)
        state.cachedClaudeCredentials = nil

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.autoRefreshClaudeUsage)
    }

    /// 驗證 autoRefreshCodexUsage 無快取憑證時不執行任何動作
    @Test
    func autoRefreshCodexUsage_noCachedCredentials_isNoOp() async {
        var state = MenuBarFeature.State()
        state.codexConnectionState = .connected(plan: .plus)
        state.cachedCodexCredentials = nil

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.autoRefreshCodexUsage)
    }

    /// 驗證 autoRefreshTick 對有快取憑證的 Claude 使用 autoRefreshClaudeUsage
    @Test
    func autoRefreshTick_usesCachedCredentialsForClaude() async {
        let cachedCredentials = ClaudeOAuth(accessToken: "cached", subscriptionType: "pro")

        var state = MenuBarFeature.State()
        state.claudeConnectionState = .connected(plan: .pro)
        state.cachedClaudeCredentials = cachedCredentials
        state.isClaudeLoading = false

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.claudeAPIClient = ClaudeAPIClient(
                loadCredentials: { fatalError("不應被呼叫") },
                refreshTokenIfNeeded: { current in current },
                fetchUsage: { _ in
                    ClaudeUsageResponse(
                        fiveHour: ClaudeUsagePeriod(utilization: 20.0, resetsAt: nil),
                        sevenDay: ClaudeUsagePeriod(utilization: 40.0, resetsAt: nil)
                    )
                }
            )
        }

        await store.send(.autoRefreshTick)

        await store.receive(\.autoRefreshClaudeUsage) {
            $0.isClaudeLoading = true
            $0.claudeErrorMessage = nil
        }

        let expectedSummary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 20.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 40.0, resetsAt: nil)
            )
        )
        await store.receive(\.claudeUsageResponse) {
            $0.isClaudeLoading = false
            $0.claudeConnectionState = .connected(plan: .pro)
            $0.claudeUsageSummary = expectedSummary
            $0.cachedClaudeCredentials = cachedCredentials
        }
        await store.receive(\.checkClaudeUsageThresholds)
    }

    /// 驗證手動重新整理不受 auto-refresh 計時器影響
    @Test
    func manualRefresh_worksIndependently() async {
        var state = MenuBarFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.isMenuVisible = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }

        await store.send(.fetchUsage) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.detectedPlan = .pro
        }
        await store.receive(\.checkUsageThresholds)
    }
}
