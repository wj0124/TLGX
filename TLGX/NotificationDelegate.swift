//
//  NotificationDelegate.swift
//  TLGX
//
//  Bridges UNUserNotificationCenter callbacks into SwiftUI.
//  When the user taps a delivered local notification, the reminder's UUID
//  is exposed via `pendingReminderID` so the UI can start a Live Activity.
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationDelegate: NSObject, ObservableObject {

    static let shared = NotificationDelegate()

    /// Set when the user taps a notification. The view layer is expected to
    /// consume it (start a Live Activity for the matching reminder) and reset
    /// it back to `nil`.
    @Published var pendingReminderID: UUID?

    /// Install as the system notification center delegate. Must be called
    /// early in app launch so that taps on cold-start notifications are
    /// delivered to us.
    func register() {
        UNUserNotificationCenter.current().delegate = bridge
    }

    private lazy var bridge: Bridge = Bridge(owner: self)

    // MARK: - Objective-C bridge

    /// `UNUserNotificationCenterDelegate` methods cannot be declared on a
    /// `@MainActor` class without bouncing through `nonisolated`, so we keep
    /// the protocol conformance on a plain NSObject helper and forward into
    /// the main-actor owner.
    final class Bridge: NSObject, UNUserNotificationCenterDelegate {
        weak var owner: NotificationDelegate?

        init(owner: NotificationDelegate) {
            self.owner = owner
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            // Show banner + sound even when the app is in the foreground so
            // the user can still tap it to start the Live Activity.
            completionHandler([.banner, .sound, .list])
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            let identifier = response.notification.request.identifier
            if let uuid = ReminderScheduler.reminderID(fromNotificationIdentifier: identifier) {
                Task { @MainActor [weak owner] in
                    owner?.pendingReminderID = uuid
                }
            }
            completionHandler()
        }
    }
}
