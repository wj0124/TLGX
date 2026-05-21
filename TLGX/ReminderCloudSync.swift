//
//  ReminderCloudSync.swift
//  TLGX
//
//  Lightweight iCloud key-value sync for ReminderStore. The dataset is tiny
//  (a few dozen reminders, KBs of JSON) so NSUbiquitousKeyValueStore is the
//  right tool: ~1 MB quota, zero backend, automatic across devices on the
//  same Apple ID. The widget extension never talks to iCloud directly — the
//  main app mirrors every remote change into App Group UserDefaults and then
//  asks WidgetCenter to reload, so the widget always reads fresh data.
//

import Foundation
import WidgetKit

enum ReminderCloudSync {

    /// Posted (on main queue) whenever a reconcile pass finishes, regardless
    /// of whether anything actually changed. UI uses this to refresh the
    /// "last synced" label.
    static let didFinishSyncNotification = Notification.Name("ReminderCloudSync.didFinishSync")

    private static let lastSyncedAtKey = "tlgx.icloud.lastSyncedAt"

    /// Wall-clock time of the most recent successful reconcile attempt.
    /// `nil` means we have never managed to talk to iCloud on this device.
    static var lastSyncedAt: Date? {
        let t = ReminderStore.defaults.double(forKey: lastSyncedAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// `true` when the device has an iCloud account signed in. KV store
    /// silently no-ops without one, so we surface this to the user.
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// User-triggered sync. Pulls the cloud snapshot immediately and pushes
    /// any pending local changes. Safe to call from the main thread.
    static func syncNow() {
        NSUbiquitousKeyValueStore.default.synchronize()
        reconcileWithCloud(source: "manual")
    }

    /// Wires up KV-store observation and reconciles initial state with the
    /// cloud. Call once during app launch (e.g. from `TLGXApp.init`).
    static func bootstrap() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { note in
            handleRemoteChange(note)
        }

        // Force an early pull from iCloud so the very first launch on a new
        // device shows data instead of an empty list while we wait for an
        // external-change notification.
        NSUbiquitousKeyValueStore.default.synchronize()
        reconcileWithCloud(source: "bootstrap")
    }

    // MARK: - Reconciliation

    /// Pull the cloud snapshot and decide which side wins based on a simple
    /// last-write-wins timestamp. On a tie we keep local to avoid spurious
    /// rewrites.
    static func reconcileWithCloud(source: String) {
        let kv = NSUbiquitousKeyValueStore.default
        let defaults = ReminderStore.defaults

        let cloudData = kv.data(forKey: ReminderStore.remindersKey)
        let cloudStamp = kv.double(forKey: ReminderStore.updatedAtKey)
        let localData = defaults.data(forKey: ReminderStore.remindersKey)
        let localStamp = defaults.double(forKey: ReminderStore.updatedAtKey)

        switch (cloudData, localData) {
        case (nil, nil):
            return

        case (let cd?, nil):
            applyCloud(data: cd, stamp: cloudStamp, source: source)

        case (nil, let ld?):
            // Local has data the cloud has never seen — push it up.
            kv.set(ld, forKey: ReminderStore.remindersKey)
            kv.set(localStamp, forKey: ReminderStore.updatedAtKey)
            kv.synchronize()

        case (let cd?, let ld?):
            if cloudStamp > localStamp {
                applyCloud(data: cd, stamp: cloudStamp, source: source)
            } else if localStamp > cloudStamp {
                kv.set(ld, forKey: ReminderStore.remindersKey)
                kv.set(localStamp, forKey: ReminderStore.updatedAtKey)
                kv.synchronize()
            }
            // Equal timestamps: assume already in sync, do nothing.
        }

        // Always stamp the last-attempt time so the UI can show "just now"
        // even when nothing actually moved.
        defaults.set(Date().timeIntervalSince1970, forKey: lastSyncedAtKey)
        NotificationCenter.default.post(name: didFinishSyncNotification, object: nil)
    }

    private static func applyCloud(data: Data, stamp: Double, source: String) {
        let defaults = ReminderStore.defaults
        // Skip rewrites when the bytes are identical — saves a SwiftUI
        // refresh storm when iCloud occasionally re-delivers the same value.
        if defaults.data(forKey: ReminderStore.remindersKey) == data {
            defaults.set(stamp, forKey: ReminderStore.updatedAtKey)
            return
        }
        defaults.set(data, forKey: ReminderStore.remindersKey)
        defaults.set(stamp, forKey: ReminderStore.updatedAtKey)

        NotificationCenter.default.post(
            name: ReminderStore.didChangeRemotelyNotification,
            object: nil,
            userInfo: ["source": source]
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Notification handler

    private static func handleRemoteChange(_ note: Notification) {
        let info = note.userInfo ?? [:]
        let reason = info[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            ?? NSUbiquitousKeyValueStoreServerChange

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange,
             NSUbiquitousKeyValueStoreAccountChange:
            reconcileWithCloud(source: "remote")
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            // ~1 MB quota exceeded. With our schema this means the user has
            // thousands of reminders — far beyond the design target. Logging
            // is enough; we keep local data intact.
            print("[ReminderCloudSync] iCloud KV quota exceeded; local data preserved.")
        default:
            reconcileWithCloud(source: "unknown")
        }
    }
}
