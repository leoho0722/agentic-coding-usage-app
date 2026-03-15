import Foundation

import AgenticCore
import ComposableArchitecture

// MARK: - ClaudeCodeFeature

/// Claude Code 工具的 TCA Reducer，管理憑證偵測、用量查詢、自動重新整理與通知邏輯。
@Reducer
struct ClaudeCodeFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {

        /// Claude Code 的連線狀態
        var connectionState: ConnectionState = .notDetected

        /// Claude Code 用量摘要
        var usageSummary: ClaudeUsageSummary?

        /// 用量是否正在載入
        var isLoading: Bool = false

        /// 錯誤訊息
        var errorMessage: String?

        /// 憑證快取，用於自動重新整理時跳過 loadCredentials()
        var cachedCredentials: ClaudeOAuth?
    }

    /// Claude Code 的連線狀態列舉。
    enum ConnectionState: Equatable, Sendable {

        /// 未偵測到本地憑證
        case notDetected

        /// 已連線，附帶訂閱方案類型
        case connected(plan: ClaudePlan?)
    }

    // MARK: - Action

    enum Action: Equatable, Sendable {

        /// 偵測本機是否存在憑證
        case detectCredentials

        /// 手動重新擷取用量
        case fetchUsage

        /// 用量回應成功，附帶已重新整理的憑證供快取
        case usageResponse(ClaudeUsageSummary, ClaudeOAuth)

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
                    @Dependency(\.claudeAPIClient) var claudeClient
                    guard let credentials = try claudeClient.loadCredentials() else {
                        await send(.usageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
                    let response = try await claudeClient.fetchUsage(refreshed.accessToken)
                    let summary = ClaudeUsageSummary(
                        plan: ClaudePlan(from: refreshed.subscriptionType),
                        response: response
                    )
                    await send(.usageResponse(summary, refreshed))
                } catch: { error, send in
                    if let apiError = error as? ClaudeAPIError {
                        switch apiError {
                        case .refreshFailed(let statusCode, _) where statusCode == 400:
                            await send(.usageFailed("notDetected"))
                        case .insufficientScope:
                            await send(.usageFailed("notDetected"))
                        default:
                            await send(.usageFailed(error.localizedDescription))
                        }
                    } else {
                        await send(.usageFailed(error.localizedDescription))
                    }
                }

            case .fetchUsage:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    @Dependency(\.claudeAPIClient) var claudeClient
                    guard let credentials = try claudeClient.loadCredentials() else {
                        await send(.usageFailed("notDetected"))
                        return
                    }
                    let refreshed = try await claudeClient.refreshTokenIfNeeded(credentials)
                    let response = try await claudeClient.fetchUsage(refreshed.accessToken)
                    let summary = ClaudeUsageSummary(
                        plan: ClaudePlan(from: refreshed.subscriptionType),
                        response: response
                    )
                    await send(.usageResponse(summary, refreshed))
                } catch: { error, send in
                    if let apiError = error as? ClaudeAPIError {
                        switch apiError {
                        case .refreshFailed(let statusCode, _) where statusCode == 400:
                            await send(.usageFailed("notDetected"))
                        case .insufficientScope:
                            await send(.usageFailed("notDetected"))
                        default:
                            await send(.usageFailed(error.localizedDescription))
                        }
                    } else {
                        await send(.usageFailed(error.localizedDescription))
                    }
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
                guard let summary = state.usageSummary else { return .none }
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient

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

            case .autoRefresh:
                guard let cached = state.cachedCredentials else { 
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                return .run { [cached] send in
                    @Dependency(\.claudeAPIClient) var claudeClient
                    let refreshed = try await claudeClient.refreshTokenIfNeeded(cached)
                    let response = try await claudeClient.fetchUsage(refreshed.accessToken)
                    let summary = ClaudeUsageSummary(
                        plan: ClaudePlan(from: refreshed.subscriptionType),
                        response: response
                    )
                    await send(.usageResponse(summary, refreshed))
                } catch: { error, send in
                    if let apiError = error as? ClaudeAPIError {
                        switch apiError {
                        case .refreshFailed(let statusCode, _) where statusCode == 400:
                            await send(.usageFailed("notDetected"))
                        case .insufficientScope:
                            await send(.usageFailed("notDetected"))
                        default:
                            await send(.usageFailed(error.localizedDescription))
                        }
                    } else {
                        await send(.usageFailed(error.localizedDescription))
                    }
                }

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
