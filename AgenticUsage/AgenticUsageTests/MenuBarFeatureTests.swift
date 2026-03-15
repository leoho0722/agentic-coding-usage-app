import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUpdater
@testable import AgenticUsage

@MainActor
@Suite("MenuBarFeature", .serialized)
struct MenuBarFeatureTests {

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
    }

    // MARK: - Auto-Refresh

    /// 驗證 menuDidAppear 設定 isMenuVisible 並立即刷新已連線服務 + 啟動計時器
    @Test
    func menuDidAppear_refreshesAndStartsTimer() async {
        let testClock = TestClock()

        var state = MenuBarFeature.State()
        state.copilot.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")

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

        await store.receive(\.copilot.fetchUsage) {
            $0.copilot.isLoading = true
            $0.copilot.errorMessage = nil
        }

        await store.receive(\.copilot.usageResponse) {
            $0.copilot.isLoading = false
            $0.copilot.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.copilot.detectedPlan = .pro
        }
        await store.receive(\.copilot.checkUsageThresholds)

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
        state.copilot.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.copilot.isLoading = false

        // Claude: 已連線，但正在載入中 → 不應刷新
        state.claude.connectionState = .connected(plan: .pro)
        state.claude.isLoading = true

        // Codex: 未連線 → 不應刷新
        state.codex.connectionState = .notDetected

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }

        await store.send(.autoRefreshTick)

        await store.receive(\.copilot.fetchUsage) {
            $0.copilot.isLoading = true
            $0.copilot.errorMessage = nil
        }
        await store.receive(\.copilot.usageResponse) {
            $0.copilot.isLoading = false
            $0.copilot.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.copilot.detectedPlan = .pro
        }
        await store.receive(\.copilot.checkUsageThresholds)
    }

    /// 驗證 refreshInterval 為 disabled 時不啟動計時器
    @Test
    func menuDidAppear_disabled_noTimer() async {
        var state = MenuBarFeature.State()
        state.copilot.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")

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

        await store.receive(\.copilot.fetchUsage) {
            $0.copilot.isLoading = true
            $0.copilot.errorMessage = nil
        }
        await store.receive(\.copilot.usageResponse) {
            $0.copilot.isLoading = false
            $0.copilot.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.copilot.detectedPlan = .pro
        }
        await store.receive(\.copilot.checkUsageThresholds)
    }

    /// 驗證 autoRefreshTick 對有快取憑證的 Claude 使用 autoRefresh
    @Test
    func autoRefreshTick_usesCachedCredentialsForClaude() async {
        let cachedCredentials = ClaudeOAuth(accessToken: "cached", subscriptionType: "pro")

        var state = MenuBarFeature.State()
        state.claude.connectionState = .connected(plan: .pro)
        state.claude.cachedCredentials = cachedCredentials
        state.claude.isLoading = false

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

        await store.receive(\.claude.autoRefresh) {
            $0.claude.isLoading = true
            $0.claude.errorMessage = nil
        }

        let expectedSummary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 20.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 40.0, resetsAt: nil)
            )
        )
        await store.receive(\.claude.usageResponse) {
            $0.claude.isLoading = false
            $0.claude.connectionState = .connected(plan: .pro)
            $0.claude.usageSummary = expectedSummary
            $0.claude.cachedCredentials = cachedCredentials
        }
        await store.receive(\.claude.checkUsageThresholds)
    }

    /// 驗證手動重新整理不受 auto-refresh 計時器影響
    @Test
    func manualRefresh_worksIndependently() async {
        var state = MenuBarFeature.State()
        state.copilot.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.isMenuVisible = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        } withDependencies: {
            $0.gitHubAPIClient = GitHubAPIClient(
                fetchUser: { _ in GitHubUser(login: "test") },
                fetchCopilotStatus: { _ in CopilotStatusResponse(copilotPlan: "copilot_for_individual_user") }
            )
        }

        await store.send(.copilot(.fetchUsage)) {
            $0.copilot.isLoading = true
            $0.copilot.errorMessage = nil
        }
        await store.receive(\.copilot.usageResponse) {
            $0.copilot.isLoading = false
            $0.copilot.usageSummary = CopilotUsageSummary(
                plan: .pro, planLimit: 300, daysUntilReset: DateUtils.daysUntilReset(),
                premiumPercentRemaining: nil
            )
            $0.copilot.detectedPlan = .pro
        }
        await store.receive(\.copilot.checkUsageThresholds)
    }
}
