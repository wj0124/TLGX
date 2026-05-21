//
//  TLGXReminderWidget.swift
//  TLGXWidget
//

import SwiftUI
import WidgetKit

struct ReminderEntry: TimelineEntry {
    let date: Date
    /// The single reminder the user picked in the widget configuration, or
    /// `nil` when nothing is selected yet.
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

    /// Re-hydrate the picked entity ID against the latest `ReminderStore`
    /// snapshot so renamed / re-emojied reminders show up-to-date text in
    /// the widget. Returns `nil` when the user hasn't picked anything yet so
    /// the widget shows its empty / call-to-action state.
    private func resolve(_ configuration: SelectReminderIntent) -> Reminder? {
        guard let id = configuration.reminder?.id else { return nil }
        return ReminderStore.load().first(where: { $0.id == id })
    }
}

struct ReminderWidgetView: View {
    var entry: ReminderEntry
    @Environment(\.widgetFamily) private var family

    private func emoji(for r: Reminder) -> String {
        r.emoji ?? EmojiGenerator.emoji(for: r.title)
    }

    private func line(for r: Reminder) -> String {
        "\(emoji(for: r)) \(r.title)"
    }

    var body: some View {
        if let r = entry.reminder {
            content(for: r)
        } else {
            emptyState
        }
    }

    // MARK: - Content per family

    @ViewBuilder
    private func content(for r: Reminder) -> some View {
        switch family {
        case .systemSmall:
            Text(line(for: r))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        default:
            Text(line(for: r))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("长按编辑\n选择要显示的提醒")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .containerBackground(for: .widget) {
                    WidgetBackground(entry: entry)
                }
        }
        .configurationDisplayName("提醒卡片")
        .description("把一条提醒放上桌面。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

/// Container background for the home-screen widget. Uses a subtle diagonal
/// gradient tinted by the picked reminder's emoji color so different
/// reminders look visually distinct on the Home Screen.
private struct WidgetBackground: View {
    let entry: ReminderEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let tint = entry.reminder.map { r in
            EmojiGenerator.tint(for: r.emoji ?? EmojiGenerator.emoji(for: r.title))
        } ?? .gray

        switch family {
        case .systemSmall, .systemMedium:
            LinearGradient(
                colors: [tint.opacity(0.18), tint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            Color.clear.background(.background)
        }
    }
}
