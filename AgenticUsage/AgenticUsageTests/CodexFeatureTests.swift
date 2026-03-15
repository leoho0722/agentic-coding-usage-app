import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUsage

@MainActor
@Suite("CodexFeature", .serialized)
struct CodexFeatureTests {

    // MARK: - usageResponse

    /// 驗證用量回應後設定 connected 狀態與 summary，並快取憑證
    @Test
    func usageResponse_setsConnectedState() async {
        let store = TestStore(initialState: CodexFeature.State()) {
            CodexFeature()
        }
        let credentials = CodexOAuth(accessToken: "tok", accountId: "acc1")
        let summary = CodexUsageSummary(
            headers: CodexUsageHeaders(primaryUsedPercent: 30.0),
            response: CodexUsageResponse(planType: "plus")
        )
        await store.send(.usageResponse(summary, credentials)) {
            $0.isLoading = false
            $0.connectionState = .connected(plan: .plus)
            $0.usageSummary = summary
            $0.cachedCredentials = credentials
        }
        await store.receive(\.checkUsageThresholds)
    }

    // MARK: - usageFailed

    /// 驗證用量失敗且為 notDetected 時重設連線狀態並清除快取
    @Test
    func usageFailed_notDetected() async {
        var state = CodexFeature.State()
        state.isLoading = true
        state.cachedCredentials = CodexOAuth(accessToken: "old")

        let store = TestStore(initialState: state) {
            CodexFeature()
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
    func usageFailed_realError() async {
        var state = CodexFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            CodexFeature()
        }
        await store.send(.usageFailed("Timeout")) {
            $0.isLoading = false
            $0.errorMessage = "Timeout"
        }
    }

    // MARK: - autoRefresh

    /// 驗證 autoRefresh 使用快取憑證，不呼叫 loadCredentials
    @Test
    func autoRefresh_usesCachedCredentials() async {
        let cachedCredentials = CodexOAuth(accessToken: "cached-tok", accountId: "acc1")

        var state = CodexFeature.State()
        state.connectionState = .connected(plan: .plus)
        state.cachedCredentials = cachedCredentials

        let store = TestStore(initialState: state) {
            CodexFeature()
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

        await store.send(.autoRefresh) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        let expectedSummary = CodexUsageSummary(
            headers: CodexUsageHeaders(primaryUsedPercent: 30.0),
            response: CodexUsageResponse(planType: "plus")
        )
        await store.receive(\.usageResponse) {
            $0.isLoading = false
            $0.connectionState = .connected(plan: .plus)
            $0.usageSummary = expectedSummary
            $0.cachedCredentials = cachedCredentials
        }
        await store.receive(\.checkUsageThresholds)
    }

    /// 驗證 autoRefresh 無快取憑證時不執行任何動作
    @Test
    func autoRefresh_noCachedCredentials_isNoOp() async {
        var state = CodexFeature.State()
        state.connectionState = .connected(plan: .plus)
        state.cachedCredentials = nil

        let store = TestStore(initialState: state) {
            CodexFeature()
        }
        await store.send(.autoRefresh)
    }

    // MARK: - dismissError

    /// 驗證 dismissError 清除錯誤訊息
    @Test
    func dismissError_clearsMessage() async {
        var state = CodexFeature.State()
        state.errorMessage = "Codex error"

        let store = TestStore(initialState: state) {
            CodexFeature()
        }
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }
}
