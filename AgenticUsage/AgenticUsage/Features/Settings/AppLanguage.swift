//
//  AppLanguage.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/3/13.
//

import SwiftUI

// MARK: - AppLanguage

/// 應用程式支援的顯示語言選項。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    
    /// 跟隨系統設定
    case system
    
    /// 英文
    case en
    
    /// 繁體中文
    case zhHant = "zh-Hant"
    
    var id: String { rawValue }
    
    /// 顯示在設定中的語言名稱，語言原名不隨 locale 變動。
    var displayName: LocalizedStringKey {
        switch self {
        case .system: "System Default"
        case .en: "English"
        case .zhHant: "繁體中文"
        }
    }
    
    /// 將使用者選擇轉換為 `Locale`，若為 `.system` 則回傳 `nil` 表示使用系統預設。
    var locale: Locale? {
        switch self {
        case .system: nil
        case .en: Locale(identifier: "en")
        case .zhHant: Locale(identifier: "zh-Hant")
        }
    }
}
