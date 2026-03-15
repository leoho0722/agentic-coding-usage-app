import Foundation

import AgenticCore
import ComposableArchitecture

// MARK: - AntigravityFeature

/// Antigravity 工具的 TCA Reducer，管理憑證偵測、用量查詢與通知邏輯。
@Reducer
struct AntigravityFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {

        /// Antigravity 的連線狀態
        var connectionState: ConnectionState = .notDetected

        /// Antigravity 用量摘要
        var usageSummary: AntigravityUsageSummary?

        /// 用量是否正在載入
        var isLoading: Bool = false

        /// 錯誤訊息
        var errorMessage: String?
    }

    /// Antigravity 的連線狀態列舉。
    enum ConnectionState: Equatable, Sendable {

        /// 未偵測到本地憑證
        case notDetected

        /// 已連線，附帶方案類型
        case connected(plan: AntigravityPlan?)
    }

    // MARK: - Action

    enum Action: Equatable, Sendable {

        /// 偵測本機是否存在憑證
        case detectCredentials

        /// 手動重新擷取用量
        case fetchUsage

        /// 用量回應成功
        case usageResponse(AntigravityUsageSummary)

        /// 用量擷取失敗
        case usageFailed(String)

        /// 檢查用量是否達到通知門檻
        case checkUsageThresholds

        /// 關閉錯誤訊息
        case dismissError
    }

    // MARK: - Reducer 主體

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
            case .detectCredentials:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    @Dependency(\.antigravityAPIClient) var antigravityClient
                    guard let credentials = try antigravityClient.loadCredentials() else {
                        await send(.usageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await antigravityClient.refreshTokenIfNeeded(credentials)
                    let response = try await antigravityClient.fetchUsage(refreshed.accessToken)
                    let summary = AntigravityUsageSummary(plan: nil, response: response)
                    await send(.usageResponse(summary))
                } catch: { error, send in
                    // 收到 401 時，嘗試強制重新整理權杖後重試
                    if let apiError = error as? AntigravityAPIError,
                       case let .httpError(statusCode, _) = apiError,
                       statusCode == 401 {
                        await send(.fetchUsage)
                    } else {
                        await send(.usageFailed(error.localizedDescription))
                    }
                }

            case .fetchUsage:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    @Dependency(\.antigravityAPIClient) var antigravityClient
                    guard let credentials = try antigravityClient.loadCredentials() else {
                        await send(.usageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await antigravityClient.refreshTokenIfNeeded(credentials)
                    let response = try await antigravityClient.fetchUsage(refreshed.accessToken)
                    let summary = AntigravityUsageSummary(plan: nil, response: response)
                    await send(.usageResponse(summary))
                } catch: { error, send in
                    await send(.usageFailed(error.localizedDescription))
                }

            case let .usageResponse(summary):
                state.isLoading = false
                state.connectionState = .connected(plan: summary.plan)
                state.usageSummary = summary
                return .send(.checkUsageThresholds)

            case let .usageFailed(message):
                state.isLoading = false
                if message == "notDetected" {
                    state.connectionState = .notDetected
                    state.errorMessage = nil
                } else {
                    state.errorMessage = message
                }
                return .none

            case .checkUsageThresholds:
                guard let summary = state.usageSummary else { return .none }
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

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

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
