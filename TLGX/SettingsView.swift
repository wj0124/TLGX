//
//  SettingsView.swift
//  TLGX
//
//  App-level functional settings. Today this is just iCloud sync controls;
//  future toggles (appearance, default sound, data export, etc.) go here so
//  the About page stays purely informational.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var lastSyncedAt: Date? = ReminderCloudSync.lastSyncedAt
    @State private var isSyncing = false
    // Bumped on a 30s timer so the relative-time label stays accurate
    // while the sheet is open, without re-rendering on every tick.
    @State private var relativeTimeTick = 0

    var body: some View {
        NavigationStack {
            List {
                iCloudSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("关闭")
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: ReminderCloudSync.didFinishSyncNotification
            )) { _ in
                lastSyncedAt = ReminderCloudSync.lastSyncedAt
                isSyncing = false
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    relativeTimeTick &+= 1
                }
            }
        }
    }

    // MARK: - iCloud

    private var iCloudSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: ReminderCloudSync.isAvailable
                      ? "icloud.fill"
                      : "icloud.slash")
                    .foregroundStyle(ReminderCloudSync.isAvailable ? .blue : .secondary)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ReminderCloudSync.isAvailable ? "iCloud 同步已开启" : "未登录 iCloud")
                        .font(.subheadline.weight(.medium))
                    Text(syncStatusDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .id(relativeTimeTick)
                }

                Spacer()

                Button {
                    triggerSync()
                } label: {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isSyncing || !ReminderCloudSync.isAvailable)
                .accessibilityLabel("立即同步")
            }
            .padding(.vertical, 2)
        } header: {
            Text("iCloud 同步")
        } footer: {
            if ReminderCloudSync.isAvailable {
                Text("同一 Apple ID 的设备之间自动同步。点右侧按钮可手动触发。")
            } else {
                Text("在「设置 - Apple 账户 - iCloud」登录后即可在多设备间自动同步。")
            }
        }
    }

    private var syncStatusDetail: String {
        guard ReminderCloudSync.isAvailable else {
            return "提醒数据仅保存在本机"
        }
        guard let date = lastSyncedAt else {
            return "尚未同步"
        }
        return "上次同步：" + Self.relativeString(for: date)
    }

    /// `RelativeDateTimeFormatter` 在中文下对刚发生的时间会输出
    /// "0秒后" / "0秒前" 这类奇怪文案，所以短间隔自己处理。
    static func relativeString(for date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 {
            return "\(Int(seconds / 60)) 分钟前"
        }
        if seconds < 86_400 {
            return "\(Int(seconds / 3600)) 小时前"
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func triggerSync() {
        guard !isSyncing else { return }
        isSyncing = true
        ReminderCloudSync.syncNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if isSyncing {
                lastSyncedAt = ReminderCloudSync.lastSyncedAt
                isSyncing = false
            }
        }
    }
}

#Preview {
    SettingsView()
}
