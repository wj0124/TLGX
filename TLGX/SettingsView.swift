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

    @StateObject private var iconManager = AppIconManager.shared
    @AppStorage(AppearanceStorageKey.mode) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        NavigationStack {
            List {
                iCloudSection
                appearanceSection
                appIconSection
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
        .appAppearance()
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

    // MARK: - App Icon

    private var appearanceSection: some View {
        let current = AppearanceMode(rawValue: appearanceRaw) ?? .system
        return Section {
            Picker(selection: Binding(
                get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
                set: { appearanceRaw = $0.rawValue }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName)
                        .tag(mode)
                }
            } label: {
                Label("外观", systemImage: current.symbolName)
            }
            .pickerStyle(.menu)
        } header: {
            Text("外观")
        } footer: {
            Text("设置只生效于当前设备，不同步到其他设备。")
        }
    }

    private var appIconSection: some View {
        Section {
            HStack(spacing: 16) {
                ForEach(iconManager.options) { option in
                    iconTile(option)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .disabled(!iconManager.supportsAlternateIcons)
        } header: {
            Text("App 图标")
        } footer: {
            if iconManager.supportsAlternateIcons {
                Text("切换后主屏、Spotlight、设置里的 App 图标会马上更新。桌面小组件与实时活动仍然使用主图标。")
            } else {
                Text("当前设备或环境不支持切换 App 图标。")
            }
        }
    }

    @ViewBuilder
    private func iconTile(_ option: AppIconOption) -> some View {
        let isSelected = iconManager.currentKey == option.key
        Button {
            Task { await switchIcon(to: option.key) }
        } label: {
            VStack(spacing: 8) {
                Group {
                    if let image = iconManager.previewImage(for: option) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                // 用极轻的投影把图标从列表底色里"托"起来，白底图标也能看清轮廓，
                // 又不会像描边那样被误以为是选中状态。
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

                // 选中提示放在图标下方，避免被当成图标的一部分。
                // 未选中时用同尺寸占位，保证两种状态布局不抖动。
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.footnote)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func switchIcon(to key: String?) async {
        guard let option = iconManager.options.first(where: { $0.key == key }) else { return }
        try? await iconManager.apply(option)
    }
}

#Preview {
    SettingsView()
}
