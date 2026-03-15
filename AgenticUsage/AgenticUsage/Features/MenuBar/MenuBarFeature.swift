import AppKit

import AgenticCore
import AgenticUpdater
import ComposableArchitecture

// MARK: - MenuBarFeature

/// MenuBar 功能的 TCA Reducer，作為協調層管理生命週期、自動重新整理、更新與 UI 邏輯。
/// 各工具的業務邏輯委派給對應的 Child Reducer（CopilotFeature、ClaudeCodeFeature、CodexFeature、AntigravityFeature）。
@Reducer
struct MenuBarFeature {

    // MARK: - State

    /// MenuBar 功能的可觀察狀態，組合各工具的子狀態與共用的 UI / 更新狀態。
    @ObservableState
    struct State: Equatable {

        // MARK: Tool Features

        /// Copilot 子功能狀態
        var copilot: CopilotFeature.State = .init()

        /// Claude Code 子功能狀態
        var claude: ClaudeCodeFeature.State = .init()

        /// Codex 子功能狀態
        var codex: CodexFeature.State = .init()

        /// Antigravity 子功能狀態
        var antigravity: AntigravityFeature.State = .init()

        // MARK: Settings

        /// Settings 子功能狀態
        var settings: SettingsFeature.State = .init()

        // MARK: UI

        /// 目前展開的工具卡片（手風琴），預設為 Copilot
        var expandedTool: ToolKind? = .copilot

        // MARK: Update

        /// 檢查到的更新資訊（nil = 無更新或尚未檢查）
        var updateInfo: UpdateInfo?

        /// 正在下載/安裝
        var isUpdating: Bool = false

        /// 更新錯誤訊息
        var updateError: String?

        // MARK: Lifecycle

        /// 標記是否已完成初始化，避免每次開啟選單列時重複偵測憑證
        var hasInitialized: Bool = false

        /// 選單視窗是否可見，用於控制自動重新整理計時器
        var isMenuVisible: Bool = false
    }

    // MARK: - Action

    /// MenuBar 功能的所有可觸發動作。
    enum Action: Equatable, Sendable {

        // MARK: Child Features

        /// Copilot 子功能動作
        case copilot(CopilotFeature.Action)

        /// Claude Code 子功能動作
        case claude(ClaudeCodeFeature.Action)

        /// Codex 子功能動作
        case codex(CodexFeature.Action)

        /// Antigravity 子功能動作
        case antigravity(AntigravityFeature.Action)

        /// Settings 子功能動作
        case settings(SettingsFeature.Action)

        // MARK: Lifecycle

        /// 畫面出現時觸發，負責初始化所有工具的狀態
        case onAppear

        /// 向使用者請求本地通知授權
        case requestNotificationAuthorization

        // MARK: UI

        /// 切換指定工具卡片的展開/收合狀態
        case toggleToolExpansion(ToolKind)

        // MARK: Auto-Refresh

        /// 選單視窗開啟時觸發，附帶目前的重新整理間隔設定
        case menuDidAppear(RefreshInterval)

        /// 選單視窗關閉時觸發，停止自動重新整理計時器
        case menuDidDisappear

        /// 自動重新整理計時器觸發
        case autoRefreshTick

        // MARK: Update

        /// 啟動時檢查更新
        case checkForUpdate

        /// 檢查到新版本
        case updateAvailable(UpdateInfo)

        /// 已是最新版本
        case updateNotAvailable

        /// 檢查更新失敗（靜默處理）
        case updateCheckFailed(String)

        /// 使用者點擊「更新」按鈕
        case performUpdate

        /// 更新完成，準備重啟
        case updateCompleted

        /// 更新失敗
        case updateFailed(String)

        /// 關閉更新錯誤訊息
        case dismissUpdateError

        /// 結束應用程式
        case quitApp
    }

    // MARK: - CancelID

    /// Effect 取消識別碼。
    private enum CancelID {
        case autoRefreshTimer
    }

    // MARK: - Dependencies

    @Dependency(\.continuousClock) private var clock

    // MARK: - Reducer 主體

    var body: some ReducerOf<Self> {
        Scope(state: \.copilot, action: \.copilot) {
            CopilotFeature()
        }
        Scope(state: \.claude, action: \.claude) {
            ClaudeCodeFeature()
        }
        Scope(state: \.codex, action: \.codex) {
            CodexFeature()
        }
        Scope(state: \.antigravity, action: \.antigravity) {
            AntigravityFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce<State, Action> { state, action in
            switch action {
            case .onAppear:
                // 僅在首次開啟時執行完整初始化（偵測憑證、通知授權、更新檢查）
                // 後續開啟選單列時跳過，避免重複觸發 SecItemCopyMatching 導致鑰匙圈權限彈窗
                guard !state.hasInitialized else {
                    return .none
                }

                state.hasInitialized = true

                return .merge(
                    .send(.copilot(.checkExistingAuth)),
                    .send(.claude(.detectCredentials)),
                    .send(.codex(.detectCredentials)),
                    .send(.antigravity(.detectCredentials)),
                    .send(.requestNotificationAuthorization),
                    .send(.checkForUpdate)
                )

            case .requestNotificationAuthorization:
                return .run { _ in
                    @Dependency(\.notificationClient) var notificationClient
                    _ = try await notificationClient.requestAuthorization()
                } catch: { _, _ in }

            case let .toggleToolExpansion(tool):
                // 僅已啟用的工具才可展開
                guard tool.isAvailable else {
                    return .none
                }

                if state.expandedTool == tool {
                    state.expandedTool = nil
                } else {
                    state.expandedTool = tool
                }

                return .none

                // MARK: - Auto-Refresh

            case let .menuDidAppear(interval):
                state.isMenuVisible = true

                guard let duration = interval.duration else {
                    // disabled — 僅立即刷新一次，不啟動計時器
                    return refreshConnectedServices(state: state)
                }

                return .merge(
                    refreshConnectedServices(state: state),
                    .run { send in
                        for await _ in self.clock.timer(interval: duration) {
                            await send(.autoRefreshTick)
                        }
                    }
                    .cancellable(id: CancelID.autoRefreshTimer, cancelInFlight: true)
                )

            case .menuDidDisappear:
                state.isMenuVisible = false
                return .cancel(id: CancelID.autoRefreshTimer)

            case .autoRefreshTick:
                return refreshConnectedServices(state: state)

                // MARK: - Update

            case .checkForUpdate:
                return .run { send in
                    @Dependency(\.updateClient) var updateClient
                    let currentVersion = Bundle.main.shortVersionString
                    if let info = try await updateClient.checkForUpdate(currentVersion) {
                        await send(.updateAvailable(info))
                    } else {
                        await send(.updateNotAvailable)
                    }
                } catch: { error, send in
                    await send(.updateCheckFailed(error.localizedDescription))
                }

            case let .updateAvailable(info):
                state.updateInfo = info
                state.settings.updateInfo = info
                return .none

            case .updateNotAvailable:
                state.updateInfo = nil
                state.settings.updateInfo = nil
                return .none

            case .updateCheckFailed:
                // 靜默處理，不顯示錯誤
                return .none

            case .performUpdate:
                guard let info = state.updateInfo else { return .none }
                state.isUpdating = true
                state.settings.isUpdating = true
                state.updateError = nil
                return .run { send in
                    @Dependency(\.updateClient) var updateClient
                    let currentAppPath = Bundle.main.bundleURL.path
                    try await updateClient.performUpdate(info, currentAppPath)
                    await send(.updateCompleted)
                } catch: { error, send in
                    await send(.updateFailed(error.localizedDescription))
                }

            case .updateCompleted:
                state.isUpdating = false
                state.settings.isUpdating = false
                // 重啟 App：先啟動延遲 shell 再立即結束自己
                return .run { _ in
                    @Dependency(\.updateClient) var updateClient
                    let appPath = Bundle.main.bundleURL.path
                    try updateClient.relaunchApp(appPath)
                    await MainActor.run {
                        NSApplication.shared.terminate(nil)
                    }
                } catch: { _, _ in }

            case let .updateFailed(message):
                state.isUpdating = false
                state.settings.isUpdating = false
                state.updateError = message
                return .none

            case .dismissUpdateError:
                state.updateError = nil
                return .none

            case .quitApp:
                return .run { _ in
                    await MainActor.run {
                        NSApplication.shared.terminate(nil)
                    }
                }

            // MARK: - Settings

            case .settings(.performUpdate):
                return .send(.performUpdate)

            // Child reducer actions — 由各自的 Scope 處理
            case .copilot, .claude, .codex, .antigravity, .settings:
                return .none
            }
        }
    }

    // MARK: - Private Helpers

    /// 刷新所有已連線且非載入中的服務用量。
    private func refreshConnectedServices(state: State) -> Effect<Action> {
        var effects: [Effect<Action>] = []

        // Copilot: 已登入且未載入中
        if state.copilot.authState.accessToken != nil, !state.copilot.isLoading {
            effects.append(.send(.copilot(.fetchUsage)))
        }

        // Claude Code: 已連線、非載入中、有快取憑證 → 使用快取跳過 loadCredentials
        if case .connected = state.claude.connectionState,
           !state.claude.isLoading,
           state.claude.cachedCredentials != nil {
            effects.append(.send(.claude(.autoRefresh)))
        }

        // Codex: 已連線、非載入中、有快取憑證 → 使用快取跳過 loadCredentials
        if case .connected = state.codex.connectionState,
           !state.codex.isLoading,
           state.codex.cachedCredentials != nil {
            effects.append(.send(.codex(.autoRefresh)))
        }

        // Antigravity: 已連線且未載入中
        if case .connected = state.antigravity.connectionState, !state.antigravity.isLoading {
            effects.append(.send(.antigravity(.fetchUsage)))
        }

        return effects.isEmpty ? .none : .merge(effects)
    }
}
