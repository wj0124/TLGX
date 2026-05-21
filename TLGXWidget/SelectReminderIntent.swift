//
//  SelectReminderIntent.swift
//  TLGXWidget
//

import AppIntents
import WidgetKit

struct ReminderEntity: AppEntity {
    var id: UUID
    var title: String
    var emoji: String
    var subtitle: String?

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "提醒")
    }

    var displayRepresentation: DisplayRepresentation {
        let displayTitle = title.isEmpty ? "未命名" : title
        // Prefix the emoji directly in the title. We intentionally do NOT pass
        // an `image:` here: in the picker list it would duplicate the emoji
        // already shown in the title, and in the "current value" chip iOS
        // would render it as a single-color template (a blank square).
        let titleWithEmoji = "\(emoji) \(displayTitle)"
        if let subtitle, !subtitle.isEmpty {
            return DisplayRepresentation(
                title: "\(titleWithEmoji)",
                subtitle: "\(subtitle)"
            )
        }
        return DisplayRepresentation(title: "\(titleWithEmoji)")
    }

    static var defaultQuery = ReminderQuery()
}

private extension ReminderEntity {
    init(reminder: Reminder) {
        self.init(
            id: reminder.id,
            title: reminder.title,
            emoji: reminder.emoji ?? EmojiGenerator.emoji(for: reminder.title),
            subtitle: ReminderEntity.subtitle(for: reminder)
        )
    }

    static func subtitle(for reminder: Reminder) -> String? {
        guard let sched = reminder.schedule else { return nil }
        let time = String(format: "%02d:%02d", sched.hour, sched.minute)
        let repeats: String
        if sched.weekdays.isEmpty { repeats = "一次" }
        else if sched.weekdays.count == 7 { repeats = "每天" }
        else if sched.weekdays == [2, 3, 4, 5, 6] { repeats = "工作日" }
        else if sched.weekdays == [1, 7] { repeats = "周末" }
        else {
            let chars = ["日", "一", "二", "三", "四", "五", "六"]
            repeats = "周" + sched.weekdays.sorted().map { chars[$0 - 1] }.joined()
        }
        return "\(repeats) · \(time)"
    }
}

struct ReminderQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ReminderEntity] {
        ReminderStore.load()
            .filter { identifiers.contains($0.id) }
            .map(ReminderEntity.init(reminder:))
    }

    func entities(matching string: String) async throws -> [ReminderEntity] {
        let query = string.lowercased()
        return ReminderStore.load()
            .filter {
                query.isEmpty || $0.title.lowercased().contains(query)
            }
            .map(ReminderEntity.init(reminder:))
    }

    func suggestedEntities() async throws -> [ReminderEntity] {
        ReminderStore.load().map(ReminderEntity.init(reminder:))
    }

    func defaultResult() async -> ReminderEntity? {
        ReminderStore.load().first.map(ReminderEntity.init(reminder:))
    }
}

struct SelectReminderIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择提醒"
    static var description = IntentDescription("选择要在小组件中显示的提醒。")

    @Parameter(title: "显示哪条提醒")
    var reminder: ReminderEntity?

    init() {}
}
