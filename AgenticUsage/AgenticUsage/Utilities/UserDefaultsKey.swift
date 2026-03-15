//
//  UserDefaultsKey.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/3/13.
//

import Foundation

// MARK: - UserDefaultsKey

/// 集中管理所有 `UserDefaults` 鍵值，避免散落各處的字串常量。
enum UserDefaultsKey: String, Sendable {
    
    /// 使用者選擇的顯示語言
    case appLanguage

    /// 自動重新整理間隔
    case refreshInterval
}
