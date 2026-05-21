//
//  TLGXLiveActivity.swift
//  TLGXWidget
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct TLGXLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TLGXAttributes.self) { context in
            lockScreenBanner(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("开启于")
                            Text(context.attributes.startedAt, format: .dateTime.hour().minute())
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Text(context.state.emoji)
                    .font(.system(size: 16))
            } compactTrailing: {
                Text(context.state.title)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            } minimal: {
                Text(context.state.emoji)
                    .font(.system(size: 14))
            }
        }
    }

    /// Lock-screen / banner presentation: tinted background, emoji badge,
    /// title + optional subtitle, and a one-tap end button (iOS 17+).
    @ViewBuilder
    private func lockScreenBanner(
        context: ActivityViewContext<TLGXAttributes>
    ) -> some View {
        HStack(spacing: 12) {
            Text(context.state.emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text("开启于")
                    Text(context.attributes.startedAt, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: EndActivityIntent(reminderID: context.attributes.reminderID)) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.primary.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("结束实时活动")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        // Intentionally omit `activityBackgroundTint`: dynamic system colors
        // (e.g. `.secondarySystemBackground`) don't reliably re-resolve under
        // the lock-screen / Liquid Glass render trait, which can produce
        // white-on-white. Letting the system supply its own opaque background
        // guarantees text contrast.
        .activitySystemActionForegroundColor(.indigo)
    }
}
