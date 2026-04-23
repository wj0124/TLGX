//
//  TLGXLiveActivity.swift
//  TLGXWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TLGXLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TLGXAttributes.self) { context in
            // Lock screen / banner UI
            VStack(alignment: .leading, spacing: 4) {
                Text("输入内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.state.message.isEmpty ? "（未输入）" : context.state.message)
                    .font(.title3)
                    .lineLimit(3)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.message.isEmpty ? "（未输入）" : context.state.message)
                        .font(.headline)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("TLGX 实时活动")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "text.bubble.fill")
            } compactTrailing: {
                Text(String(context.state.message.prefix(8)))
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "text.bubble.fill")
            }
        }
    }
}
