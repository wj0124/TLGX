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
                        // 标题自适应：短文案用 title2 一行大字撑场，
                        // 一旦放不下就回退到 headline 两行小字。
                        ViewThatFits(in: .horizontal) {
                            Text(context.state.title)
                                .font(.title2.weight(.semibold))
                                .lineLimit(1)
                            Text(context.state.title)
                                .font(.headline)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                        }
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
                compactTrailing(for: context.state)
            } minimal: {
                Text(context.state.emoji)
                    .font(.system(size: 14))
            }
        }
    }

    @ViewBuilder
    private func compactTrailing(for state: TLGXAttributes.ContentState) -> some View {
        switch state.islandMode {
        case .compact:
            EmptyView()
        case .standard:
            compactTitle(state.title)
        }
    }

    /// 标准模式右侧文案：最多 2 行 × 2 字，超出丢弃。
    /// 4 字 → 2+2 两行居中 12pt；2 字 → 单行 17pt。
    @ViewBuilder
    private func compactTitle(_ raw: String) -> some View {
        let chars = Array(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        if chars.count <= 2 {
            Text(String(chars))
                .font(.system(size: 17, weight: .regular))
                .lineLimit(1)
                .padding(.trailing, 4)
        } else {
            let first = String(chars.prefix(2))
            let second = String(chars.dropFirst(2).prefix(2))
            Text("\(first)\n\(second)")
                .font(.system(size: 12, weight: .regular))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 4)
        }
    }

    /// Lock-screen / banner presentation: tinted background, emoji badge,
    /// title + optional subtitle, and a one-tap end button (iOS 17+).
    @ViewBuilder
    private func lockScreenBanner(
        context: ActivityViewContext<TLGXAttributes>
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(context.state.emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                // 标题尽量完整显示。封顶 5 行避免顶满后底部"开启于"被系统裁掉，
                // 超出 5 行用省略号收尾。
                Text(context.state.title)
                    .font(.headline)
                    .fontDesign(.monospaced)
                    .tracking(0.2)
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("开启于")
                    Text(context.attributes.startedAt, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
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
