import Foundation

import AgenticCore
import ComposableArchitecture

// MARK: - CodexFeature

/// Codex 工具的 TCA Reducer，管理憑證偵測、用量查詢、自動重新整理與通知邏輯。
@Reducer
struct CodexFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {

        /// Codex 的連線狀態
        var connectionState: ConnectionState = .notDetected

        /// Codex 用量摘要
        var usageSummary: CodexUsageSummary?

        /// 用量是否正在載入
        var isLoading: Bool = false

        /// 錯誤訊息
        var errorMessage: String?

        /// 憑證快取，用於自動重新整理時跳過 loadCredentials()
        var cachedCredentials: CodexOAuth?
    }

    /// Codex 的連線狀態列舉。
    enum ConnectionState: Equatable, Sendable {

        /// 未偵測到本地憑證
        case notDetected

        /// 已連線，附帶方案類型
        case connected(plan: CodexPlan?)
    }

    // MARK: - Action

    enum Action: Equatable, Sendable {

        /// 偵測本機是否存在憑證
        case detectCredentials

        /// 手動重新擷取用量
        case fetchUsage

        /// 用量回應成功，附帶已重新整理的憑證供快取
        case usageResponse(CodexUsageSummary, CodexOAuth)

        /// 用量擷取失敗
        case usageFailed(String)

        /// 檢查用量是否達到通知門檻
        case checkUsageThresholds

        /// 自動重新整理用量（使用快取憑證，跳過 loadCredentials）
        case autoRefresh

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
                    @Dependency(\.codexAPIClient) var codexClient
                    guard let credentials = try codexClient.loadCredentials() else {
                        await send(.usageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await codexClient.refreshTokenIfNeeded(credentials)
                    let (headers, response) = try await codexClient.fetchUsage(
                        refreshed.accessToken, refreshed.accountId
                    )
                    let summary = CodexUsageSummary(headers: headers, response: response)
                    await send(.usageResponse(summary, refreshed))
                } catch: { error, send in
                    // 收到 401 時，嘗試強制重新整理權杖後重試
                    if let apiError = error as? CodexAPIError,
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
                    @Dependency(\.codexAPIClient) var codexClient
                    guard let credentials = try codexClient.loadCredentials() else {
                        await send(.usageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await codexClient.refreshTokenIfNeeded(credentials)
                    let (headers, response) = try await codexClient.fetchUsage(
                        refreshed.accessToken, refreshed.accountId
                    )
                    let summary = CodexUsageSummary(headers: headers, response: response)
                    await send(.usageResponse(summary, refreshed))
                } catch: { error, send in
                    await send(.usageFailed(error.localizedDescription))
                }

            case let .usageResponse(summary, credentials):
                state.isLoading = false
                state.connectionState = .connected(plan: summary.plan)
                state.usageSummary = summary
                state.cachedCredentials = credentials
                return .send(.checkUsageThresholds)

            case let .usageFailed(message):
                state.isLoading = false
                if message == "notDetected" {
                    state.connectionState = .notDetected
                    state.errorMessage = nil
                    state.cachedCredentials = nil
                } else {
                    state.errorMessage = message
                }
                return .none

            case .checkUsageThresholds:
                guard let summary = state.usageSummary else { 
                    return .none
                }
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

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

            case .autoRefresh:
                guard let cached = state.cachedCredentials else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { [cached] send in
                    @Dependency(\.codexAPIClient) var codexClient
                    let refreshed = try await codexClient.refreshTokenIfNeeded(cached)
                    let (headers, response) = try await codexClient.fetchUsage(
                        refreshed.accessToken, refreshed.accountId
                    )
                    let summary = CodexUsageSummary(headers: headers, response: response)
                    await send(.usageResponse(summary, refreshed))
                } catch: { error, send in
                    await send(.usageFailed(error.localizedDescription))
                }

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
