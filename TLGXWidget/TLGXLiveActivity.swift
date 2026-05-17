//
//  TLGXLiveActivity.swift
//  TLGXWidget
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TLGXLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TLGXAttributes.self) { context in
            // Lock screen / banner
            HStack(spacing: 12) {
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .activityBackgroundTint(Color(uiColor: .systemGray3))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image("isLandIcon")
                    .resizable()
                    .scaledToFit()
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
}
