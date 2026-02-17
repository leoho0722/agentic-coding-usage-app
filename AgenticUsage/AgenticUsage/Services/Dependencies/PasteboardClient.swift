import AppKit

import Dependencies

// MARK: - PasteboardClient

/// 剪貼簿操作的 TCA 相依性。
struct PasteboardClient: Sendable {
    
    /// 將指定字串寫入系統剪貼簿。
    var setString: @Sendable (_ string: String) -> Void
}

// MARK: - 測試實作

/// 測試用的模擬實作，不執行任何剪貼簿操作。
extension PasteboardClient: TestDependencyKey {
    
    /// 測試用的模擬實作
    static let testValue = PasteboardClient(setString: { _ in })
}

// MARK: - 正式版實作

extension PasteboardClient {
    
    /// 正式版實作，使用 `NSPasteboard` 寫入系統剪貼簿。
    static let live = PasteboardClient(
        setString: { string in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    )
}

// MARK: - 相依性註冊

extension DependencyValues {
    
    /// 剪貼簿客戶端相依性
    var pasteboard: PasteboardClient {
        get { self[PasteboardClient.self] }
        set { self[PasteboardClient.self] = newValue }
    }
}
