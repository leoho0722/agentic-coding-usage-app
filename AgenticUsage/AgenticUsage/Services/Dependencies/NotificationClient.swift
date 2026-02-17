import Foundation
import UserNotifications

import Dependencies

// MARK: - NotificationClient

/// 本地通知操作的 TCA 相依性，負責授權請求、通知發送與門檻追蹤。
struct NotificationClient: Sendable {
    
    /// 向使用者請求通知授權，回傳是否獲得授權。
    var requestAuthorization: @Sendable () async throws -> Bool
    
    /// 發送一則本地通知。
    var send: @Sendable (_ id: String, _ title: String, _ body: String) async throws -> Void
    
    /// 檢查指定工具窗口在目前重設週期內是否已發送過該門檻通知。
    var hasNotified: @Sendable (_ toolWindow: String, _ threshold: Int, _ resetCycle: String) -> Bool
    
    /// 標記指定工具窗口在目前重設週期內已發送過該門檻通知。
    var markNotified: @Sendable (_ toolWindow: String, _ threshold: Int, _ resetCycle: String) -> Void
    
    /// 清除所有已通知的門檻紀錄（用於測試或手動重設）。
    var clearNotified: @Sendable () -> Void
}

// MARK: - 正式版實作

extension NotificationClient {
    
    /// UserDefaults 中儲存 `[String: NotifiedRecord]` JSON 資料的鍵名。
    ///
    /// 每個工具窗口各自擁有獨立的重設週期識別碼與已通知門檻清單。
    private static let notifiedKey = "notifiedUsageThresholds_v2"

    /// 單一工具窗口的門檻通知紀錄，記錄目前的重設週期與已通知的門檻列表。
    private struct NotifiedRecord: Codable {
        
        /// 重設週期識別碼
        var resetCycle: String
        
        /// 已通知的門檻數值列表
        var thresholds: [Int]
    }

    /// 從 UserDefaults 載入所有工具窗口的通知紀錄。
    /// - Returns: 工具窗口 ID 對應通知紀錄的字典
    private static func loadRecords() -> [String: NotifiedRecord] {
        guard let data = UserDefaults.standard.data(forKey: notifiedKey),
              let dict = try? JSONDecoder().decode([String: NotifiedRecord].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// 將通知紀錄字典儲存至 UserDefaults。
    /// - Parameter records: 工具窗口 ID 對應通知紀錄的字典
    private static func saveRecords(_ records: [String: NotifiedRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: notifiedKey)
        }
    }

    /// 正式版實作，使用 `UNUserNotificationCenter` 與 `UserDefaults`。
    static let live = NotificationClient(
        requestAuthorization: {
            let center = UNUserNotificationCenter.current()
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        },
        send: { id, title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: nil // 立即送達
            )
            try await UNUserNotificationCenter.current().add(request)
        },
        hasNotified: { toolWindow, threshold, resetCycle in
            var records = loadRecords()
            
            // 若該工具窗口的重設週期已改變，清除其門檻紀錄
            if let record = records[toolWindow], record.resetCycle != resetCycle {
                records[toolWindow] = NotifiedRecord(resetCycle: resetCycle, thresholds: [])
                saveRecords(records)
                return false
            }
            return records[toolWindow]?.thresholds.contains(threshold) ?? false
        },
        markNotified: { toolWindow, threshold, resetCycle in
            var records = loadRecords()
            var record = records[toolWindow] ?? NotifiedRecord(resetCycle: resetCycle, thresholds: [])
            
            // 若重設週期已改變，重新初始化門檻紀錄
            if record.resetCycle != resetCycle {
                record = NotifiedRecord(resetCycle: resetCycle, thresholds: [])
            }
            if !record.thresholds.contains(threshold) {
                record.thresholds.append(threshold)
            }
            records[toolWindow] = record
            saveRecords(records)
        },
        clearNotified: {
            UserDefaults.standard.removeObject(forKey: notifiedKey)
        }
    )
}

// MARK: - 測試實作

/// 測試用的模擬實作，不發送實際通知。
extension NotificationClient: TestDependencyKey {
    /// 測試用的模擬實作
    static let testValue = NotificationClient(
        requestAuthorization: { true },
        send: { _, _, _ in },
        hasNotified: { _, _, _ in false },
        markNotified: { _, _, _ in },
        clearNotified: {}
    )
}

// MARK: - 相依性註冊

extension DependencyValues {
    /// 通知客戶端相依性
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
