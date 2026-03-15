//
//  RefreshInterval.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/3/13.
//

import SwiftUI

// MARK: - RefreshInterval

/// 自動重新整理的間隔選項，使用者可在設定中選擇。
enum RefreshInterval: String, CaseIterable, Identifiable, Sendable {

    /// 停用自動重新整理
    case disabled

    /// 每 15 秒
    case seconds15 = "15"

    /// 每 30 秒
    case seconds30 = "30"

    /// 每 60 秒
    case seconds60 = "60"

    /// 每 120 秒
    case seconds120 = "120"

    var id: String { rawValue }

    /// 顯示在設定中的間隔名稱。
    var displayName: LocalizedStringKey {
        switch self {
        case .disabled: "Disabled"
        case .seconds15: "15 seconds"
        case .seconds30: "30 seconds"
        case .seconds60: "60 seconds"
        case .seconds120: "120 seconds"
        }
    }

    /// 對應的 `Duration`，`disabled` 時回傳 `nil`。
    var duration: Duration? {
        switch self {
        case .disabled: nil
        case .seconds15: .seconds(15)
        case .seconds30: .seconds(30)
        case .seconds60: .seconds(60)
        case .seconds120: .seconds(120)
        }
    }
}
