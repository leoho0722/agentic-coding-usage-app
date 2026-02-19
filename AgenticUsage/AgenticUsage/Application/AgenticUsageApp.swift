//
//  AgenticUsageApp.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/2/15.
//

import SwiftUI
import AgenticCore
import ComposableArchitecture

// MARK: - AgenticUsageApp

/// AgenticUsage 應用程式的進入點，以 MenuBarExtra 形式呈現於系統選單列。
@main
struct AgenticUsageApp: App {
    
    /// TCA Store，管理整個 MenuBar 功能的狀態與副作用，並注入所有正式版相依性。
    @State private var store = Store(initialState: MenuBarFeature.State()) {
        MenuBarFeature()
    } withDependencies: {
        $0.gitHubAPIClient = .live
        $0.oAuthService = .live
        $0.keychainService = .live
        $0.pasteboard = .live
        $0.notificationClient = .live
        $0.claudeAPIClient = .live(clientID: bundleString("ClaudeClientID"))
        $0.codexAPIClient = .live(clientID: bundleString("CodexClientID"))
        $0.antigravityAPIClient = .live(
            clientID: bundleString("AntigravityClientID"),
            clientSecret: bundleString("AntigravityClientSecret")
        )
    }

    var body: some Scene {
        // 以視窗樣式的 MenuBarExtra 呈現主要 UI
        MenuBarExtra {
            MenuBarView(store: self.store)
        } label: {
            Label("AgenticUsage", systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - 私有輔助工具

private extension AgenticUsageApp {
    
    /// 從 Info.plist 取得指定鍵值的字串，若未設定則觸發 fatalError。
    /// - Parameter key: Info.plist 中的鍵名（例如 `ClaudeClientID`）
    /// - Returns: 對應的字串值
    static func bundleString(_ key: String) -> String {
        guard let value = Bundle.getValue(from: .main, with: key), !value.isEmpty else {
            fatalError(
                "\(key) not configured. Copy Secrets.xcconfig.template to Secrets.xcconfig and set your values."
            )
        }
        return value
    }
}
