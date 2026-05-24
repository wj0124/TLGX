//
//  EmojiPickerView.swift
//  TLGX
//

import SwiftUI
import UIKit

struct EmojiPickerView: View {
    /// Current effective emoji (auto-detected or user-overridden).
    let current: String
    /// The emoji that would be auto-detected from the current title.
    let autoEmoji: String
    /// `true` if user is currently overriding the auto-detected value.
    let isOverridden: Bool

    /// Called with the chosen emoji (override) or `nil` to restore auto-detect.
    let onSelect: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    autoSection
                    pickerSection
                }
                .padding(16)
            }
            .navigationTitle("选择表情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var autoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自动识别")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                selectionHaptic()
                onSelect(nil)
            } label: {
                HStack(spacing: 12) {
                    Text(autoEmoji)
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("跟随文字自动识别")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(isOverridden ? "当前为手动选择" : "当前生效")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isOverridden
                              ? Color.fieldFill
                              : Color.indigo.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isOverridden ? Color.clear : Color.indigo,
                                lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手动选择")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(EmojiGenerator.pickerEmojis, id: \.self) { emoji in
                    Button {
                        selectionHaptic()
                        onSelect(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected(emoji)
                                          ? Color.indigo.opacity(0.18)
                                          : Color.fieldFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected(emoji) ? Color.indigo : Color.clear,
                                            lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isSelected(_ emoji: String) -> Bool {
        isOverridden && emoji == current
    }

    private func selectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
