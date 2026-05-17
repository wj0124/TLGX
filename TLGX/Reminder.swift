//
//  Reminder.swift
//  TLGX (shared with TLGXWidget extension)
//

import Foundation

struct Reminder: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
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
