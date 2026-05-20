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
                        if let subtitle = context.state.subtitle, !subtitle.isEmpty {
                            Label(subtitle, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                        }
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
                Image("isLandIcon")
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    /// Lock-screen / banner presentation: tinted background, emoji badge,
    /// title + optional subtitle, and a one-tap end button (iOS 17+).
    @ViewBuilder
    private func lockScreenBanner(
        context: ActivityViewContext<TLGXAttributes>
    ) -> some View {
        let tint = EmojiGenerator.tint(for: context.state.emoji)

        HStack(spacing: 12) {
            Text(context.state.emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.25)))

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(2)
                if let subtitle = context.state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: EndActivityIntent(reminderID: context.attributes.reminderID)) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("结束实时活动")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
        .activitySystemActionForegroundColor(.primary)
    }
}
