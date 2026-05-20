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
    private static let remindersKey = "tlgx.reminders.v1"

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

    static func save(_ items: [Reminder]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: remindersKey)
        }
    }
}
