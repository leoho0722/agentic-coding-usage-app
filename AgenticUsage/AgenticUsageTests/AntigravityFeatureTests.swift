import ComposableArchitecture
import Foundation
import Testing

@testable import AgenticCore
@testable import AgenticUsage

@MainActor
@Suite("AntigravityFeature", .serialized)
struct AntigravityFeatureTests {

    // MARK: - usageResponse

    /// 驗證用量回應後設定 connected 狀態與 summary
    @Test
    func usageResponse_setsConnectedState() async {
        let store = TestStore(initialState: AntigravityFeature.State()) {
            AntigravityFeature()
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
        await store.send(.usageResponse(summary)) {
            $0.isLoading = false
            $0.connectionState = .connected(plan: nil)
            $0.usageSummary = summary
        }
        await store.receive(\.checkUsageThresholds)
    }

    // MARK: - usageFailed

    /// 驗證用量失敗且為 notDetected 時重設連線狀態
    @Test
    func usageFailed_notDetected() async {
        var state = AntigravityFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            AntigravityFeature()
        }
        await store.send(.usageFailed("notDetected")) {
            $0.isLoading = false
            $0.connectionState = .notDetected
            $0.errorMessage = nil
        }
    }

    /// 驗證用量失敗且為實際錯誤時設定錯誤訊息
    @Test
    func usageFailed_realError() async {
        var state = AntigravityFeature.State()
        state.isLoading = true

        let store = TestStore(initialState: state) {
            AntigravityFeature()
        }
        await store.send(.usageFailed("Auth error")) {
            $0.isLoading = false
            $0.errorMessage = "Auth error"
        }
    }

    // MARK: - dismissError

    /// 驗證 dismissError 清除錯誤訊息
    @Test
    func dismissError_clearsMessage() async {
        var state = AntigravityFeature.State()
        state.errorMessage = "AG error"

        let store = TestStore(initialState: state) {
            AntigravityFeature()
        }
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }
}
