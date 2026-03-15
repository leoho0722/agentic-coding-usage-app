//
//  SettingsView.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/3/13.
//

import SwiftUI
import ComposableArchitecture

// MARK: - SettingsView

/// 應用程式設定視圖，以分段 Form 佈局呈現各類設定選項。
struct SettingsView: View {

    /// SettingsFeature 的 TCA Store
    let store: StoreOf<SettingsFeature>

    /// 使用者選擇的語言偏好，儲存於 UserDefaults
    @AppStorage(.appLanguage, defaultValue: .system)
    private var appLanguage: AppLanguage

    /// 自動重新整理間隔，儲存於 UserDefaults
    @AppStorage(.refreshInterval, defaultValue: .seconds30)
    private var refreshInterval: RefreshInterval

    /// 目前 App 版號
    private var version: String { 
        Bundle.main.shortVersionString
    }

    var body: some View {
        Form {
            // MARK: 一般設定
            Section {
                Picker("Language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                Picker("Auto-Refresh Interval", selection: $refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName)
                            .tag(interval)
                    }
                }
            } header: {
                Text("General")
            }

            // MARK: 關於
            Section {
                if store.updateInfo != nil {
                    LabeledContent("Version") {
                        Text("\(version) (\(Text("Update Available")))")
                    }
                    Button {
                        store.send(.performUpdate)
                    } label: {
                        if store.isUpdating {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Updating...")
                            }
                        } else {
                            Text("Update Now")
                        }
                    }
                    .disabled(store.isUpdating)
                } else {
                    LabeledContent("Version") {
                        Text("\(version) (\(Text("Up to Date")))")
                    }
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 250)
    }
}
