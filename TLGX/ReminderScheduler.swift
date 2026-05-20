//
//  ReminderScheduler.swift
//  TLGX
//
//  Local notification scheduling for reminders.
//

import Foundation
import UserNotifications

enum ReminderScheduler {

    /// Ensure the user has granted notification authorization.
    /// Returns true if currently authorized (including provisional).
    static func requestAuthIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
            return granted
        case .denied:
            return false
        case .authorized, .provisional, .ephemeral:
            return true
        @unknown default:
            return false
        }
    }

    /// (Re)schedule notifications for a reminder based on its `schedule`.
    /// Always cancels any previously-registered notifications for the same
    /// reminder first, so calling this is idempotent.
    static func schedule(reminder: Reminder) async throws {
        cancel(reminderID: reminder.id)
        guard let schedule = reminder.schedule else { return }

        let body: String = {
            if let custom = schedule.pushText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !custom.isEmpty {
                return custom
            }
            return reminder.title
        }()

        let content = UNMutableNotificationContent()
        content.title = "提了个醒"
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let center = UNUserNotificationCenter.current()

        if schedule.weekdays.isEmpty {
            // One-shot: fire at the next occurrence of hour:minute.
            var comp = DateComponents()
            comp.hour = schedule.hour
            comp.minute = schedule.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)
            let request = UNNotificationRequest(
                identifier: oneShotIdentifier(for: reminder.id),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        } else {
            // One repeating notification per selected weekday.
            for weekday in schedule.weekdays {
                var comp = DateComponents()
                comp.weekday = weekday
                comp.hour = schedule.hour
                comp.minute = schedule.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
                let request = UNNotificationRequest(
                    identifier: weeklyIdentifier(for: reminder.id, weekday: weekday),
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            }
        }
    }

    /// Cancel every pending notification belonging to a reminder
    /// (one-shot + every weekday slot).
    static func cancel(reminderID: UUID) {
        var ids = [oneShotIdentifier(for: reminderID)]
        for weekday in 1...7 {
            ids.append(weeklyIdentifier(for: reminderID, weekday: weekday))
        }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Identifiers

    /// Returns the leading reminder UUID embedded in a notification identifier
    /// produced by this scheduler. Both `"{uuid}-once"` and `"{uuid}-w{n}"`
    /// shapes are supported.
    static func reminderID(fromNotificationIdentifier identifier: String) -> UUID? {
        let prefix = String(identifier.prefix(36))
        return UUID(uuidString: prefix)
    }

    private static func oneShotIdentifier(for id: UUID) -> String {
        "\(id.uuidString)-once"
    }

    private static func weeklyIdentifier(for id: UUID, weekday: Int) -> String {
        "\(id.uuidString)-w\(weekday)"
    }
}
