//
//  ReminderCloudSync.swift
//  TLGX
//
//  Explicit-direction iCloud sync for ReminderStore.
//
//  Design: the user picks the direction every time — either upload local
//  to iCloud, or download iCloud to local. There is no automatic,
//  "smart" reconciler; both directions are unambiguous overwrites that
//  always show a confirmation preview with the entry counts and how many
//  entries on the destination side will be removed.
//
//  Storage: NSUbiquitousKeyValueStore (~1 MB quota, zero backend,
//  automatic across devices on the same Apple ID). The widget extension
//  never talks to iCloud directly — successful syncs are mirrored into
//  App Group UserDefaults and widget timelines are reloaded from there.
//

import Foundation
import WidgetKit

enum ReminderCloudSync {

    /// Posted (on main queue) when an explicit upload/download finishes.
    /// The UI uses this to refresh "last synced" and dismiss spinners.
    static let didFinishSyncNotification = Notification.Name("ReminderCloudSync.didFinishSync")

    private static let lastSyncedAtKey = "tlgx.icloud.lastSyncedAt"

    /// Wall-clock time of the most recent successful upload or download.
    /// `nil` means the user has never synced on this device.
    static var lastSyncedAt: Date? {
        let t = ReminderStore.defaults.double(forKey: lastSyncedAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// `true` when the device is signed into iCloud. KV store silently
    /// no-ops without an account, so we surface this to the user.
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Warm the KV store cache so the first preview after launch sees the
    /// latest cloud snapshot without an extra round trip. Local data is
    /// never modified here.
    static func bootstrap() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Preview

    struct DirectionPreview {
        enum Direction { case upload, download }

        enum Outcome {
            /// Ready to apply: the destination side will be overwritten.
            case ready
            /// Both sides already hold the same snapshot — nothing to do.
            case identical
            /// User isn't signed into iCloud — sync isn't possible.
            case notSignedIn
        }

        var direction: Direction
        var outcome: Outcome
        /// Reminders currently on this device.
        var localCount: Int
        /// Reminders currently in iCloud.
        var cloudCount: Int
        /// Entries that exist only on the destination side and will be
        /// removed when this sync is applied. For `.upload` this is the
        /// cloud-only count; for `.download` this is the local-only count.
        var willDelete: Int
    }

    static func previewUpload() -> DirectionPreview {
        makePreview(direction: .upload)
    }

    static func previewDownload() -> DirectionPreview {
        makePreview(direction: .download)
    }

    private static func makePreview(direction: DirectionPreview.Direction) -> DirectionPreview {
        guard isAvailable else {
            return DirectionPreview(direction: direction,
                                    outcome: .notSignedIn,
                                    localCount: 0, cloudCount: 0, willDelete: 0)
        }

        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        let defaults = ReminderStore.defaults

        let cloudData = kv.data(forKey: ReminderStore.remindersKey)
        let localData = defaults.data(forKey: ReminderStore.remindersKey)

        let decoder = JSONDecoder()
        let cloud: [Reminder] = cloudData.flatMap { try? decoder.decode([Reminder].self, from: $0) } ?? []
        let local: [Reminder] = localData.flatMap { try? decoder.decode([Reminder].self, from: $0) } ?? []
        let cloudIDs = Set(cloud.map(\.id))
        let localIDs = Set(local.map(\.id))

        // Treat byte-identical snapshots as a no-op so the UI can show a
        // friendly "already in sync" alert instead of a destructive one.
        if let cd = cloudData, let ld = localData, cd == ld {
            return DirectionPreview(direction: direction,
                                    outcome: .identical,
                                    localCount: local.count,
                                    cloudCount: cloud.count,
                                    willDelete: 0)
        }

        let willDelete: Int
        switch direction {
        case .upload:
            // Cloud will be replaced with local → cloud-only ids disappear.
            willDelete = cloudIDs.subtracting(localIDs).count
        case .download:
            // Local will be replaced with cloud → local-only ids disappear.
            willDelete = localIDs.subtracting(cloudIDs).count
        }

        return DirectionPreview(direction: direction,
                                outcome: .ready,
                                localCount: local.count,
                                cloudCount: cloud.count,
                                willDelete: willDelete)
    }

    // MARK: - Execute

    /// Overwrite the iCloud snapshot with the current local snapshot.
    /// Caller is responsible for confirming with the user first (see
    /// `previewUpload()`).
    static func uploadLocalToCloud() {
        let defaults = ReminderStore.defaults
        let kv = NSUbiquitousKeyValueStore.default

        if let localData = defaults.data(forKey: ReminderStore.remindersKey) {
            let stamp = Date().timeIntervalSince1970
            defaults.set(stamp, forKey: ReminderStore.updatedAtKey)
            kv.set(localData, forKey: ReminderStore.remindersKey)
            kv.set(stamp, forKey: ReminderStore.updatedAtKey)
        } else {
            // Local is empty: erase the cloud snapshot too.
            kv.removeObject(forKey: ReminderStore.remindersKey)
            kv.removeObject(forKey: ReminderStore.updatedAtKey)
        }
        kv.synchronize()

        defaults.set(Date().timeIntervalSince1970, forKey: lastSyncedAtKey)
        NotificationCenter.default.post(name: didFinishSyncNotification, object: nil)
    }

    /// Overwrite the local snapshot with the current iCloud snapshot.
    /// Caller is responsible for confirming with the user first (see
    /// `previewDownload()`).
    static func downloadCloudToLocal() {
        let defaults = ReminderStore.defaults
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()

        let stamp = Date().timeIntervalSince1970

        if let cloudData = kv.data(forKey: ReminderStore.remindersKey) {
            defaults.set(cloudData, forKey: ReminderStore.remindersKey)
            defaults.set(stamp, forKey: ReminderStore.updatedAtKey)
        } else {
            // Cloud is empty: clear local too.
            defaults.removeObject(forKey: ReminderStore.remindersKey)
            defaults.removeObject(forKey: ReminderStore.updatedAtKey)
        }

        defaults.set(stamp, forKey: lastSyncedAtKey)

        NotificationCenter.default.post(
            name: ReminderStore.didChangeRemotelyNotification,
            object: nil,
            userInfo: ["source": "download"]
        )
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: didFinishSyncNotification, object: nil)
    }
}
