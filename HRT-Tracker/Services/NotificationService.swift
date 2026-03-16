import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let doseReminderPrefix = "dose-reminder-"

    /// Called when user taps a notification; set by the app to handle dose reminders.
    var onDoseReminderTapped: ((UUID) -> Void)?

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Request notification permission from the user.
    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    /// Schedule a local notification for a specific template's dose reminder.
    func scheduleDoseReminder(id: String, at date: Date, title: String, body: String) {
        // Remove existing reminder for this ID first
        cancelDoseReminder(id: id)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = doseReminderPrefix + id
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        Task {
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Cancel a specific template's dose reminder.
    func cancelDoseReminder(id: String) {
        let identifier = doseReminderPrefix + id
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel all dose reminder notifications.
    func cancelAllDoseReminders() {
        Task {
            let requests = await center.pendingNotificationRequests()
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(doseReminderPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        if identifier.hasPrefix(doseReminderPrefix) {
            let templateIDString = String(identifier.dropFirst(doseReminderPrefix.count))
            if let templateID = UUID(uuidString: templateIDString) {
                Task { @MainActor in
                    onDoseReminderTapped?(templateID)
                }
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
