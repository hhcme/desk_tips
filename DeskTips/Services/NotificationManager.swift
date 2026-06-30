import Foundation
import UserNotifications
import DeskTipsCore

/// Manages system notifications for todo reminders.
@MainActor
final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    /// Request notification permission.
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("[DeskTips] Notification permission error: %@", error.localizedDescription)
            return false
        }
    }

    /// Schedule a reminder notification for a todo item.
    func scheduleNotification(for item: TodoStore, reminderOffset: TimeInterval) {
        // This method is called per-item; see scheduleNotification(for:) below
    }

    /// Schedule a notification for a specific todo item.
    func scheduleNotification(for item: TodoItem, reminderOffset: TimeInterval) {
        guard let dueDate = item.dueDate, !item.isCompleted else { return }
        guard reminderOffset > 0 else { return }

        let triggerDate = dueDate.addingTimeInterval(-reminderOffset)
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = item.title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "desktips-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[DeskTips] Schedule notification error: %@", error.localizedDescription)
            }
        }
    }

    /// Remove notification for a specific todo item.
    func removeNotification(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["desktips-\(id.uuidString)"])
    }

    /// Remove all pending notifications.
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Check for overdue items and send a summary notification if any exist.
    func checkOverdueItems(store: TodoStore) {
        let overdue = store.overdueItems
        guard !overdue.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "过期待办"
        content.body = "你有 \(overdue.count) 个待办已过期：\(overdue.prefix(3).map(\.title).joined(separator: "、"))"
        content.sound = .default

        // Fire in 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "desktips-overdue-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Reschedule all notifications for active items with due dates.
    func rescheduleAll(store: TodoStore, reminderOffset: TimeInterval) {
        removeAllNotifications()
        for item in store.items where item.dueDate != nil && !item.isCompleted {
            scheduleNotification(for: item, reminderOffset: reminderOffset)
        }
    }
}
