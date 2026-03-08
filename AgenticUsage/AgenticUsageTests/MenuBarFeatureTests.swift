import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUpdater
@testable import AgenticUsage

@MainActor
@Suite("MenuBarFeature")
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

    /// 驗證 Claude 使用量回應後設定 connected 狀態與 summary
    @Test
    func claudeUsageResponse_setsConnectedState() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let summary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 30.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
            )
        )
        await store.send(.claudeUsageResponse(summary)) {
            $0.isClaudeLoading = false
            $0.claudeConnectionState = .connected(plan: .pro)
            $0.claudeUsageSummary = summary
        }
        await store.receive(\.checkClaudeUsageThresholds)
    }

    /// 驗證 Claude 使用量失敗且為 notDetected 時重設連線狀態
    @Test
    func claudeUsageFailed_notDetected_resetsState() async {
        var state = MenuBarFeature.State()
        state.isClaudeLoading = true
        state.claudeConnectionState = .connected(plan: .pro)

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.claudeUsageFailed("notDetected")) {
            $0.isClaudeLoading = false
            $0.claudeConnectionState = .notDetected
            $0.claudeErrorMessage = nil
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

    /// 驗證 Codex 使用量回應後設定 connected 狀態與 summary
    @Test
    func codexUsageResponse_setsConnectedState() async {
        let store = TestStore(initialState: MenuBarFeature.State()) {
            MenuBarFeature()
        }
        let summary = CodexUsageSummary(
            headers: CodexUsageHeaders(primaryUsedPercent: 30.0),
            response: CodexUsageResponse(planType: "plus")
        )
        await store.send(.codexUsageResponse(summary)) {
            $0.isCodexLoading = false
            $0.codexConnectionState = .connected(plan: .plus)
            $0.codexUsageSummary = summary
        }
        await store.receive(\.checkCodexUsageThresholds)
    }

    /// 驗證 Codex 使用量失敗且為 notDetected 時重設連線狀態
    @Test
    func codexUsageFailed_notDetected() async {
        var state = MenuBarFeature.State()
        state.isCodexLoading = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.codexUsageFailed("notDetected")) {
            $0.isCodexLoading = false
            $0.codexConnectionState = .notDetected
            $0.codexErrorMessage = nil
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
        }
    }

    /// 驗證無可用更新時清除 updateInfo
    @Test
    func updateNotAvailable_clearsInfo() async {
        let release = GitHubRelease(
            tagName: "v2.0.0", name: "v2.0.0", body: "Changes",
            htmlUrl: "https://github.com/test/releases/tag/v2.0.0", assets: []
        )
        var state = MenuBarFeature.State()
        state.updateInfo = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("2.0.0")!,
            release: release
        )

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.updateNotAvailable) {
            $0.updateInfo = nil
        }
    }

    /// 驗證更新失敗時設定錯誤訊息並停止更新狀態
    @Test
    func updateFailed_setsError() async {
        var state = MenuBarFeature.State()
        state.isUpdating = true

        let store = TestStore(initialState: state) {
            MenuBarFeature()
        }
        await store.send(.updateFailed("Download failed")) {
            $0.isUpdating = false
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
}
