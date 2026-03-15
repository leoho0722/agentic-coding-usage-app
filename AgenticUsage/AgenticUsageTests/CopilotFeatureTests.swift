import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUsage

@MainActor
@Suite("CopilotFeature", .serialized)
struct CopilotFeatureTests {

    // MARK: - loginCompleted

    /// 驗證登入完成後設定 loggedIn 狀態並觸發 fetchUsage
    @Test
    func loginCompleted_setsLoggedInState_andTriggersUsage() async {
        let store = TestStore(initialState: CopilotFeature.State()) {
            CopilotFeature()
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
        var state = CopilotFeature.State()
        state.authState = .authenticating
        state.deviceFlowState = CopilotFeature.DeviceFlowState(
            userCode: "CODE", verificationUri: "https://example.com"
        )
        let store = TestStore(initialState: state) {
            CopilotFeature()
        }
        await store.send(.loginFailed("Something went wrong")) {
            $0.authState = .loggedOut
            $0.deviceFlowState = nil
            $0.errorMessage = "Something went wrong"
        }
    }

    // MARK: - logoutCompleted

    /// 驗證登出完成後清除所有 Copilot 相關狀態
    @Test
    func logoutCompleted_resetsAllState() async {
        var state = CopilotFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.usageSummary = CopilotUsageSummary(plan: .pro, planLimit: 300, daysUntilReset: 10, premiumPercentRemaining: 80.0)
        state.detectedPlan = .pro

        let store = TestStore(initialState: state) {
            CopilotFeature()
        }
        await store.send(.logoutCompleted) {
            $0.authState = .loggedOut
            $0.usageSummary = nil
            $0.detectedPlan = nil
            $0.deviceFlowState = nil
        }
    }

    // MARK: - usageResponse / usageFailed

    /// 驗證收到使用量回應後正確設定 usageSummary 與 detectedPlan
    @Test
    func usageResponse_setsState() async {
        var state = CopilotFeature.State()
        state.authState = .loggedIn(user: GitHubUser(login: "test"), accessToken: "tok")
        state.isLoading = true

        let store = TestStore(initialState: state) {
            CopilotFeature()
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
        var state = CopilotFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            CopilotFeature()
        }
        await store.send(.usageFailed("Network error")) {
            $0.isLoading = false
            $0.errorMessage = "Network error"
        }
    }

    // MARK: - deviceCodeReceived

    /// 驗證收到 Device Code 後正確設定 deviceFlowState
    @Test
    func deviceCodeReceived_setsFlowState() async {
        let store = TestStore(initialState: CopilotFeature.State()) {
            CopilotFeature()
        }
        let flowState = CopilotFeature.DeviceFlowState(
            userCode: "ABCD-1234",
            verificationUri: "https://github.com/login/device"
        )
        await store.send(.deviceCodeReceived(flowState)) {
            $0.deviceFlowState = flowState
        }
    }

    // MARK: - dismissError

    /// 驗證 dismissError 清除錯誤訊息
    @Test
    func dismissError_clearsMessage() async {
        var state = CopilotFeature.State()
        state.errorMessage = "Some error"

        let store = TestStore(initialState: state) {
            CopilotFeature()
        }
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }
}
