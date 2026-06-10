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

    /// Set when the user taps upload or download. Presence drives the
    /// confirmation alert; the contained `DirectionPreview` shapes its
    /// title/message/buttons.
    @State private var pendingPreview: ReminderCloudSync.DirectionPreview?

    @StateObject private var iconManager = AppIconManager.shared
    @AppStorage(AppearanceStorageKey.mode) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(DynamicIslandDisplayMode.storageKey) private var islandModeRaw = DynamicIslandDisplayMode.compact.rawValue

    var body: some View {
        NavigationStack {
            List {
                iCloudSection
                dynamicIslandSection
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
            .alert(
                syncAlertTitle,
                isPresented: Binding(
                    get: { pendingPreview != nil },
                    set: { if !$0 { pendingPreview = nil } }
                ),
                presenting: pendingPreview
            ) { preview in
                syncAlertActions(for: preview)
            } message: { preview in
                Text(syncAlertMessage(for: preview))
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
                    Text(ReminderCloudSync.isAvailable ? String(localized: "iCloud 同步已开启") : String(localized: "未登录 iCloud"))
                        .font(.subheadline.weight(.medium))
                    Text(syncStatusDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .id(relativeTimeTick)
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.vertical, 2)

            Button {
                requestPreview(direction: .upload)
            } label: {
                directionRow(
                    systemImage: "icloud.and.arrow.up",
                    title: String(localized: "上传到 iCloud"),
                    subtitle: String(localized: "用本机覆盖云端")
                )
            }
            .disabled(isSyncing || !ReminderCloudSync.isAvailable)

            Button {
                requestPreview(direction: .download)
            } label: {
                directionRow(
                    systemImage: "icloud.and.arrow.down",
                    title: String(localized: "从 iCloud 下载"),
                    subtitle: String(localized: "用云端覆盖本机")
                )
            }
            .disabled(isSyncing || !ReminderCloudSync.isAvailable)
        } header: {
            Text("iCloud 同步")
        } footer: {
            if ReminderCloudSync.isAvailable {
                Text("为避免误删，同步不会自动进行。请明确选择方向，点击后会先弹出预览。")
            } else {
                Text("在「设置 - Apple 账户 - iCloud」登录后即可在多设备间手动同步。")
            }
        }
    }

    @ViewBuilder
    private func directionRow(systemImage: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var syncStatusDetail: String {
        guard ReminderCloudSync.isAvailable else {
            return String(localized: "提醒数据仅保存在本机")
        }
        guard let date = lastSyncedAt else {
            return String(localized: "尚未同步")
        }
        return String(localized: "上次同步：") + Self.relativeString(for: date)
    }

    /// `RelativeDateTimeFormatter` 在中文下对刚发生的时间会输出
    /// "0秒后" / "0秒前" 这类奇怪文案，所以短间隔自己处理。
    static func relativeString(for date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 { return String(localized: "刚刚") }
        if seconds < 3600 {
            return String(localized: "\(Int(seconds / 60)) 分钟前")
        }
        if seconds < 86_400 {
            return String(localized: "\(Int(seconds / 3600)) 小时前")
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale.current
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func requestPreview(direction: ReminderCloudSync.DirectionPreview.Direction) {
        guard !isSyncing else { return }
        switch direction {
        case .upload:   pendingPreview = ReminderCloudSync.previewUpload()
        case .download: pendingPreview = ReminderCloudSync.previewDownload()
        }
    }

    private func performSync(_ preview: ReminderCloudSync.DirectionPreview) {
        guard !isSyncing else { return }
        isSyncing = true
        switch preview.direction {
        case .upload:   ReminderCloudSync.uploadLocalToCloud()
        case .download: ReminderCloudSync.downloadCloudToLocal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if isSyncing {
                lastSyncedAt = ReminderCloudSync.lastSyncedAt
                isSyncing = false
            }
        }
    }

    // MARK: - Sync confirmation alert

    private var syncAlertTitle: String {
        guard let p = pendingPreview else { return "" }
        switch p.outcome {
        case .identical:
            return String(localized: "本机与 iCloud 已一致")
        case .notSignedIn:
            return String(localized: "未登录 iCloud")
        case .ready:
            return p.direction == .upload ? String(localized: "上传到 iCloud") : String(localized: "从 iCloud 下载")
        }
    }

    private func syncAlertMessage(for p: ReminderCloudSync.DirectionPreview) -> String {
        switch p.outcome {
        case .identical:
            return String(localized: "两边都是 \(p.localCount) 条提醒，不需要同步。")
        case .notSignedIn:
            return String(localized: "请先在系统「设置」中登录 iCloud。")
        case .ready:
            var parts: [String] = []
            switch p.direction {
            case .upload:
                parts.append(String(localized: "本机 \(p.localCount) 条 → iCloud \(p.cloudCount) 条"))
                if p.willDelete > 0 {
                    parts.append(String(localized: "其中 \(p.willDelete) 条仅在 iCloud 中，将被删除。"))
                }
            case .download:
                parts.append(String(localized: "iCloud \(p.cloudCount) 条 → 本机 \(p.localCount) 条"))
                if p.willDelete > 0 {
                    parts.append(String(localized: "其中 \(p.willDelete) 条仅在本机，将被删除。"))
                }
            }
            parts.append(String(localized: "是否继续？"))
            return parts.joined(separator: "\n")
        }
    }

    @ViewBuilder
    private func syncAlertActions(for preview: ReminderCloudSync.DirectionPreview) -> some View {
        switch preview.outcome {
        case .identical, .notSignedIn:
            Button("好", role: .cancel) { pendingPreview = nil }
        case .ready:
            Button("取消", role: .cancel) { pendingPreview = nil }
            Button(preview.willDelete > 0 ? String(localized: "继续") : (preview.direction == .upload ? String(localized: "上传") : String(localized: "下载")),
                   role: preview.willDelete > 0 ? .destructive : nil) {
                let p = preview
                pendingPreview = nil
                performSync(p)
            }
        }
    }

    // MARK: - App Icon

    private var dynamicIslandSection: some View {
        let current = DynamicIslandDisplayMode(rawValue: islandModeRaw) ?? .compact
        return Section {
            Picker(selection: Binding(
                get: { DynamicIslandDisplayMode(rawValue: islandModeRaw) ?? .compact },
                set: { islandModeRaw = $0.rawValue }
            )) {
                ForEach(DynamicIslandDisplayMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName)
                        .tag(mode)
                }
            } label: {
                Label(String(localized: "灵动岛常态"), systemImage: current.symbolName)
            }
            .pickerStyle(.menu)
        } header: {
            Text("灵动岛")
        } footer: {
            Text("紧凑：仅显示左侧图标。标准：左侧图标 + 右侧短文字。详细：右侧展示更多文字。")
        }
    }

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
