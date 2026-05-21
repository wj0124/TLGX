//
//  Reminder.swift
//  TLGX (shared with TLGXWidget extension)
//

import Foundation

struct ReminderSchedule: Codable, Hashable {
    /// 0-23
    var hour: Int
    /// 0-59
    var minute: Int
    /// 1 = Sunday ... 7 = Saturday. Empty = one-shot at next occurrence of hour:minute.
    var weekdays: Set<Int>
    /// Optional custom push body; nil falls back to the reminder's title.
    var pushText: String?

    /// Next trigger date strictly after `now`. Returns `nil` only on extreme
    /// calendar errors. For one-shot schedules (`weekdays` empty), returns the
    /// next occurrence of `hour:minute` (today if not yet passed, else
    /// tomorrow). For recurring schedules, scans up to 8 days ahead and picks
    /// the first day whose weekday is in `weekdays`.
    func nextTriggerDate(after now: Date = Date()) -> Date? {
        let cal = Calendar.current
        if weekdays.isEmpty {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let candidate = cal.date(from: comps) else { return nil }
            return candidate > now
                ? candidate
                : cal.date(byAdding: .day, value: 1, to: candidate)
        }
        for offset in 0...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: day)
            guard weekdays.contains(weekday) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let candidate = cal.date(from: comps) else { continue }
            if candidate > now { return candidate }
        }
        return nil
    }
}

struct Reminder: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var schedule: ReminderSchedule?
    /// User-picked emoji override. `nil` means use `EmojiGenerator` auto-detect.
    var emoji: String?
    /// Whether the user has pinned this reminder to the top of the list.
    var isPinned: Bool

    init(id: UUID = UUID(),
         title: String,
         schedule: ReminderSchedule? = nil,
         emoji: String? = nil,
         isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.schedule = schedule
        self.emoji = emoji
        self.isPinned = isPinned
    }

    // Custom decode so older persisted payloads (without `isPinned`) keep working.
    private enum CodingKeys: String, CodingKey {
        case id, title, schedule, emoji, isPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        schedule = try c.decodeIfPresent(ReminderSchedule.self, forKey: .schedule)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

enum ReminderStore {
    static let appGroupID = "group.tixingwo"
    static let remindersKey = "tlgx.reminders.v1"
    static let updatedAtKey = "tlgx.reminders.updatedAt"

    /// Posted on the main thread whenever iCloud delivers a remote change
    /// that we merged into local storage. Observers (e.g. the list view in
    /// `ContentView`) should reload from `load()` and refresh widgets.
    static let didChangeRemotelyNotification = Notification.Name("ReminderStore.didChangeRemotely")

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> [Reminder] {
        guard let data = defaults.data(forKey: remindersKey),
              let items = try? JSONDecoder().decode([Reminder].self, from: data) else {
            return []
        }
        return items
    }

    /// Persist `items` locally and mirror them to iCloud Key-Value storage
    /// so other devices on the same Apple ID can pick up the change.
    static func save(_ items: [Reminder]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        let stamp = Date().timeIntervalSince1970

        defaults.set(data, forKey: remindersKey)
        defaults.set(stamp, forKey: updatedAtKey)

        let kv = NSUbiquitousKeyValueStore.default
        kv.set(data, forKey: remindersKey)
        kv.set(stamp, forKey: updatedAtKey)
        kv.synchronize()
    }
}
