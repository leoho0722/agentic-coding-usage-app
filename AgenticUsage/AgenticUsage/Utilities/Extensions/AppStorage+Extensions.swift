//
//  AppStorage+Extensions.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/3/13.
//

import SwiftUI

// MARK: - AppStorage + UserDefaultsKey

extension AppStorage where Value: RawRepresentable, Value.RawValue == String {
    
    /// 以 `UserDefaultsKey` 建立 `AppStorage`，避免手動輸入字串鍵值。
    /// - Parameters:
    ///   - key: `UserDefaultsKey` 列舉值
    ///   - defaultValue: 預設值
    init(_ key: UserDefaultsKey, defaultValue: Value) {
        self.init(wrappedValue: defaultValue, key.rawValue)
    }
}
