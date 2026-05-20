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

    /// Resolve the emoji for a reminder: user-picked override first,
    /// otherwise fall back to `EmojiGenerator`'s keyword auto-detection.
    private func emoji(for r: Reminder) -> String {
        r.emoji ?? EmojiGenerator.emoji(for: r.title)
    }

    var body: some View {
        if let r = entry.reminder {
            switch family {
            case .accessoryInline:
                // 锁屏顶部一行文本（不支持多行、不支持自定义颜色）
                Text("\(emoji(for: r)) \(r.title)")

            case .accessoryCircular:
                // 锁屏圆形：只能塞极少量信息
                ZStack {
                    AccessoryWidgetBackground()
                    Text(emoji(for: r))
                        .font(.system(size: 22))
                        .minimumScaleFactor(0.5)
                        .padding(4)
                }

            case .accessoryRectangular:
                // 锁屏长条：可显示 2-3 行
                HStack(alignment: .center, spacing: 8) {
                    Text(emoji(for: r))
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("提醒")
                            .font(.caption2)
                            .widgetAccentable()
                        Text(r.title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            default:
                // 主屏 small / medium
                VStack(alignment: .leading, spacing: 6) {
                    Text(emoji(for: r))
                        .font(.system(size: 28))
                    Text(r.title)
                        .font(.headline)
                        .lineLimit(family == .systemSmall ? 5 : 3)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            switch family {
            case .accessoryInline:
                Text("点击选择提醒")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "hand.tap")
                }
            case .accessoryRectangular:
                Text("长按编辑选择提醒")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            default:
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
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
