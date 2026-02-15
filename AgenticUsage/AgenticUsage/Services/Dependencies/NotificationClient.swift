import Dependencies
import Foundation
import UserNotifications

/// TCA dependency for local notification operations.
struct NotificationClient: Sendable {
    /// Request notification authorization from the user.
    var requestAuthorization: @Sendable () async throws -> Bool
    /// Send a local notification with the given title and body.
    var send: @Sendable (_ id: String, _ title: String, _ body: String) async throws -> Void
    /// Check whether a threshold has already been notified for a given tool in the current reset cycle.
    var hasNotified: @Sendable (_ tool: String, _ threshold: Int) -> Bool
    /// Mark a threshold as notified for a given tool in the current reset cycle.
    var markNotified: @Sendable (_ tool: String, _ threshold: Int) -> Void
    /// Clear all notified thresholds (e.g. on monthly reset).
    var clearNotified: @Sendable () -> Void
}

// MARK: - Live Implementation

extension NotificationClient {
    /// UserDefaults key storing `[String: [Int]]` — tool id → list of notified threshold raw values.
    /// Also stores the reset-cycle month so we can auto-clear on a new month.
    private static let notifiedKey = "notifiedUsageThresholds"
    private static let resetMonthKey = "notifiedResetMonth"

    /// Returns a "YYYY-MM" string for the current UTC month.
    private static func currentResetMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    /// Auto-clears notified records if the month has changed (usage counters reset on the 1st UTC).
    private static func autoResetIfNeeded() {
        let current = currentResetMonth()
        let stored = UserDefaults.standard.string(forKey: resetMonthKey)
        if stored != current {
            UserDefaults.standard.removeObject(forKey: notifiedKey)
            UserDefaults.standard.set(current, forKey: resetMonthKey)
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
        hasNotified: { tool, threshold in
            autoResetIfNeeded()
            let dict = UserDefaults.standard.dictionary(forKey: notifiedKey) as? [String: [Int]] ?? [:]
            return dict[tool]?.contains(threshold) ?? false
        },
        markNotified: { tool, threshold in
            autoResetIfNeeded()
            var dict = UserDefaults.standard.dictionary(forKey: notifiedKey) as? [String: [Int]] ?? [:]
            var list = dict[tool] ?? []
            if !list.contains(threshold) {
                list.append(threshold)
            }
            dict[tool] = list
            UserDefaults.standard.set(dict, forKey: notifiedKey)
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
        hasNotified: { _, _ in false },
        markNotified: { _, _ in },
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
