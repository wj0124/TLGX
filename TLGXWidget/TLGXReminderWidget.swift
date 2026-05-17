//
//  TLGXReminderWidget.swift
//  TLGXWidget
//

import SwiftUI
import WidgetKit

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminder: Reminder?
}

struct ReminderProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: Date(), reminder: Reminder(title: "写日报"))
    }

    func snapshot(for configuration: SelectReminderIntent, in context: Context) async -> ReminderEntry {
        ReminderEntry(date: Date(), reminder: resolve(configuration))
    }

    func timeline(for configuration: SelectReminderIntent, in context: Context) async -> Timeline<ReminderEntry> {
        let entry = ReminderEntry(date: Date(), reminder: resolve(configuration))
        return Timeline(entries: [entry], policy: .never)
    }

    private func resolve(_ configuration: SelectReminderIntent) -> Reminder? {
        let all = ReminderStore.load()
        if let id = configuration.reminder?.id,
           let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.first
    }
}

struct ReminderWidgetView: View {
    var entry: ReminderEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let r = entry.reminder {
            VStack(alignment: .leading, spacing: 6) {
                Text(r.title)
                    .font(.headline)
                    .lineLimit(family == .systemSmall ? 6 : 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("长按编辑\n选择要显示的提醒")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TLGXReminderWidget: Widget {
    let kind = "TLGXReminderWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectReminderIntent.self,
            provider: ReminderProvider()
        ) { entry in
            ReminderWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("提了个醒")
        .description("长按小组件选择要显示的提醒。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
