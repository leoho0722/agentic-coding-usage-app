import Dependencies
import Foundation
import UserNotifications

/// TCA dependency for local notification operations.
struct NotificationClient: Sendable {
    /// Request notification authorization from the user.
    var requestAuthorization: @Sendable () async throws -> Bool
    /// Send a local notification with the given title and body.
    var send: @Sendable (_ id: String, _ title: String, _ body: String) async throws -> Void
    /// Check whether a threshold has already been notified for a given tool-window in the current reset cycle.
    var hasNotified: @Sendable (_ toolWindow: String, _ threshold: Int, _ resetCycle: String) -> Bool
    /// Mark a threshold as notified for a given tool-window in the current reset cycle.
    var markNotified: @Sendable (_ toolWindow: String, _ threshold: Int, _ resetCycle: String) -> Void
    /// Clear all notified thresholds (e.g. for testing or manual reset).
    var clearNotified: @Sendable () -> Void
}

// MARK: - Live Implementation

extension NotificationClient {
    /// UserDefaults key storing `[String: NotifiedRecord]` encoded as JSON.
    /// Each tool-window has its own reset cycle identifier and list of notified thresholds.
    private static let notifiedKey = "notifiedUsageThresholds_v2"

    /// Per-tool-window record of which thresholds have been notified and for which cycle.
    private struct NotifiedRecord: Codable {
        var resetCycle: String
        var thresholds: [Int]
    }

    /// Load the notified records dictionary from UserDefaults.
    private static func loadRecords() -> [String: NotifiedRecord] {
        guard let data = UserDefaults.standard.data(forKey: notifiedKey),
              let dict = try? JSONDecoder().decode([String: NotifiedRecord].self, from: data)
        else {
            return [:]
        }
        return dict
    }

    /// Save the notified records dictionary to UserDefaults.
    private static func saveRecords(_ records: [String: NotifiedRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: notifiedKey)
        }
    }

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
                trigger: nil // deliver immediately
            )
            try await UNUserNotificationCenter.current().add(request)
        },
        hasNotified: { toolWindow, threshold, resetCycle in
            var records = loadRecords()
            // If cycle changed for this tool-window, clear its thresholds
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
            // If cycle changed, reset thresholds
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

// MARK: - Test Implementation

extension NotificationClient: TestDependencyKey {
    static let testValue = NotificationClient(
        requestAuthorization: { true },
        send: { _, _, _ in },
        hasNotified: { _, _, _ in false },
        markNotified: { _, _, _ in },
        clearNotified: {}
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
