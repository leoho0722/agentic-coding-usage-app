//
//  Bundle+Extensions.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/2/18.
//

import Foundation

extension Bundle {
    
    class func getValue(from bundle: Bundle, with key: String) -> String? {
        return bundle.infoDictionary?[key] as? String
    }
    
    /// `CFBundleShortVersionString` (e.g. "1.2.0"), falling back to "–" if missing.
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
}
