//
//  SelectReminderIntent.swift
//  TLGXWidget
//

import AppIntents
import WidgetKit

struct ReminderEntity: AppEntity {
    var id: UUID
    var title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "提醒")
    }

    var displayRepresentation: DisplayRepresentation {
        let displayTitle = title.isEmpty ? "未命名" : title
        return DisplayRepresentation(title: "\(displayTitle)")
    }

    static var defaultQuery = ReminderQuery()
}

struct ReminderQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ReminderEntity] {
        ReminderStore.load()
            .filter { identifiers.contains($0.id) }
            .map { ReminderEntity(id: $0.id, title: $0.title) }
    }

    func entities(matching string: String) async throws -> [ReminderEntity] {
        let query = string.lowercased()
        return ReminderStore.load()
            .filter {
                query.isEmpty || $0.title.lowercased().contains(query)
            }
            .map { ReminderEntity(id: $0.id, title: $0.title) }
    }

    func suggestedEntities() async throws -> [ReminderEntity] {
        ReminderStore.load()
            .map { ReminderEntity(id: $0.id, title: $0.title) }
    }

    func defaultResult() async -> ReminderEntity? {
        ReminderStore.load().first.map {
            ReminderEntity(id: $0.id, title: $0.title)
        }
    }
}

struct SelectReminderIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择提醒"
    static var description = IntentDescription("选择要在小组件中显示的提醒。")

    @Parameter(title: "提醒")
    var reminder: ReminderEntity?

    init() {}
}
