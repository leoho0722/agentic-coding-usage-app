//
//  Bundle+Extensions.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/2/18.
//

import Foundation

// MARK: - Bundle + 便捷方法

extension Bundle {
    
    /// 從指定 Bundle 的 Info.plist 中取得字串值。
    /// - Parameters:
    ///   - bundle: 目標 Bundle
    ///   - key: Info.plist 中的鍵名
    /// - Returns: 對應的字串值，若不存在或型別不符則回傳 `nil`
    class func getValue(from bundle: Bundle, with key: String) -> String? {
        return bundle.infoDictionary?[key] as? String
    }

    /// App 的簡短版本號（`CFBundleShortVersionString`），例如 "1.2.0"。
    ///
    /// 若 Info.plist 中未包含此鍵，則回傳 "–"。
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
}
