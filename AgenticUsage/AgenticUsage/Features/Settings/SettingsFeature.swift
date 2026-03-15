//
//  SettingsFeature.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/3/15.
//

import AgenticUpdater
import ComposableArchitecture

// MARK: - SettingsFeature

/// Settings 功能的 TCA Reducer，管理設定視圖的狀態與動作。
@Reducer
struct SettingsFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {

        /// 可用的更新資訊（nil = 已是最新版或尚未檢查）
        var updateInfo: UpdateInfo?

        /// 是否正在下載/安裝更新
        var isUpdating: Bool = false
    }

    // MARK: - Action

    enum Action: Equatable, Sendable {

        /// 使用者點擊「立即更新」按鈕
        case performUpdate
    }

    // MARK: - Reducer 主體

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { _, action in
            switch action {
            case .performUpdate:
                return .none  // 由父層攔截處理
            }
        }
    }
}
