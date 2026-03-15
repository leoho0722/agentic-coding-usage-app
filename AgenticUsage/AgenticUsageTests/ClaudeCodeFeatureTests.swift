import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUsage

@MainActor
@Suite("ClaudeCodeFeature", .serialized)
struct ClaudeCodeFeatureTests {

    // MARK: - usageResponse

    /// 驗證用量回應後設定 connected 狀態與 summary，並快取憑證
    @Test
    func usageResponse_setsConnectedState() async {
        let store = TestStore(initialState: ClaudeCodeFeature.State()) {
            ClaudeCodeFeature()
        }
        let credentials = ClaudeOAuth(accessToken: "tok", subscriptionType: "pro")
        let summary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 30.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
            )
        )
        await store.send(.usageResponse(summary, credentials)) {
            $0.isLoading = false
            $0.connectionState = .connected(plan: .pro)
            $0.usageSummary = summary
            $0.cachedCredentials = credentials
        }
        await store.receive(\.checkUsageThresholds)
    }

    // MARK: - usageFailed

    /// 驗證用量失敗且為 notDetected 時重設連線狀態並清除快取
    @Test
    func usageFailed_notDetected_resetsState() async {
        var state = ClaudeCodeFeature.State()
        state.isLoading = true
        state.connectionState = .connected(plan: .pro)
        state.cachedCredentials = ClaudeOAuth(accessToken: "old")

        let store = TestStore(initialState: state) {
            ClaudeCodeFeature()
        }
        await store.send(.usageFailed("notDetected")) {
            $0.isLoading = false
            $0.connectionState = .notDetected
            $0.errorMessage = nil
            $0.cachedCredentials = nil
        }
    }

    /// 驗證用量失敗且為實際錯誤時設定錯誤訊息
    @Test
    func usageFailed_realError_setsMessage() async {
        var state = ClaudeCodeFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            ClaudeCodeFeature()
        }
        await store.send(.usageFailed("HTTP 500")) {
            $0.isLoading = false
            $0.errorMessage = "HTTP 500"
        }
    }

    // MARK: - autoRefresh

    /// 驗證 autoRefresh 使用快取憑證，不呼叫 loadCredentials
    @Test
    func autoRefresh_usesCachedCredentials() async {
        let cachedCredentials = ClaudeOAuth(accessToken: "cached-tok", subscriptionType: "pro")

        var state = ClaudeCodeFeature.State()
        state.connectionState = .connected(plan: .pro)
        state.cachedCredentials = cachedCredentials

        let store = TestStore(initialState: state) {
            ClaudeCodeFeature()
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

        await store.send(.autoRefresh) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        let expectedSummary = ClaudeUsageSummary(
            plan: .pro,
            response: ClaudeUsageResponse(
                fiveHour: ClaudeUsagePeriod(utilization: 30.0, resetsAt: nil),
                sevenDay: ClaudeUsagePeriod(utilization: 50.0, resetsAt: nil)
            )
        )
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.connectionState = .connected(plan: .pro)
            $0.usageSummary = expectedSummary
            $0.cachedCredentials = cachedCredentials
        }
        await store.receive(\.checkUsageThresholds)
    }

    /// 驗證 autoRefresh 無快取憑證時不執行任何動作
    @Test
    func autoRefresh_noCachedCredentials_isNoOp() async {
        var state = ClaudeCodeFeature.State()
        state.connectionState = .connected(plan: .pro)
        state.cachedCredentials = nil

        let store = TestStore(initialState: state) {
            ClaudeCodeFeature()
        }
        await store.send(.autoRefresh)
    }

    // MARK: - dismissError

    /// 驗證 dismissError 清除錯誤訊息
    @Test
    func dismissError_clearsMessage() async {
        var state = ClaudeCodeFeature.State()
        state.errorMessage = "Claude error"

        let store = TestStore(initialState: state) {
            ClaudeCodeFeature()
        }
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }
}
