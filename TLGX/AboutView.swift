//
//  AboutView.swift
//  TLGX
//
//  Privacy promise, usage tips, and contact info. UI 排版参考 iOS 系统
//  「设置 - 蓝牙 - 设备详情」：顶部居中的大图标 + 名称 + 版本，下面是
//  一组 inset-grouped 列表，key-value 行 / 链接行。
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var iconManager = AppIconManager.shared

    private let contactEmail = "w2287307@gmail.com"

    private var appVersionShort: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    private var appVersionFull: String { "\(appVersionShort) (\(appBuild))" }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                privacySection
                usageSection
                contactSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("关于")
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
        }
    }

    // MARK: - Header（仿蓝牙详情顶部居中介绍卡）

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                appIconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }

                Text("提了个醒")
                    .font(.title.weight(.bold))

                Text("一款专注个人提醒的轻量 App，支持锁屏实时活动、桌面小组件与 iCloud 同步。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    /// 显示当前生效的 App 图标（含切换后的备用图标）。
    /// 读取 `iconManager.currentKey` 以便切换后 SwiftUI 自动刷新。
    private var appIconImage: Image {
        let key = iconManager.currentKey
        if let key, let ui = UIImage(named: key) {
            return Image(uiImage: ui)
        }
        if let ui = AppIconManager.shared.previewImage(for: .init(key: nil, displayName: "", subtitle: "", previewAssetName: nil)) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "app.fill")
    }

    // MARK: - 隐私

    private var privacySection: some View {
        Section {
            bulletRow("提醒数据仅保存在你的设备和你自己的 iCloud 中")
            bulletRow("iCloud 同步由系统直接完成，作者无法看到你的内容")
            bulletRow("不收集、不上传任何信息到第三方服务器")
            bulletRow("没有账号系统、没有广告 SDK、没有数据分析")
            bulletRow("通知、实时活动、桌面小组件均由系统本地调度")
        } header: {
            Label("隐私承诺", systemImage: "lock.shield.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        }
        .listRowSeparator(.hidden)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.footnote)
                .padding(.top, 3)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 使用说明

    private var usageSection: some View {
        Section {
            tipRow(icon: "plus.bubble",
                   title: "新建",
                   detail: "在底部输入框写下提醒，点发送即可")
            tipRow(icon: "pencil",
                   title: "编辑",
                   detail: "点击任意一条提醒可重新编辑内容")
            tipRow(icon: "pin",
                   title: "置顶",
                   detail: "向右滑动一条提醒")
            tipRow(icon: "clock",
                   title: "定时",
                   detail: "向右滑动后点击「时间」可设置每日 / 每周提醒")
            tipRow(icon: "switch.2",
                   title: "开启",
                   detail: "右侧开关把提醒推到锁屏与状态栏持续显示")
            tipRow(icon: "trash",
                   title: "删除",
                   detail: "向左滑动一条提醒")
        } header: {
            Text("使用说明")
        }
        .listRowSeparator(.hidden)
    }

    private func tipRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.indigo)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 联系

    private var contactSection: some View {
        Section {
            Link(destination: mailURL) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.indigo)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("发邮件给作者")
                            .foregroundStyle(.primary)
                        Text(contactEmail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("联系作者")
        } footer: {
            Text("欢迎反馈 bug、功能建议或使用感受。")
        }
    }

    // MARK: - Helpers

    private var mailURL: URL {
        let subject = String(localized: "提了个醒 反馈")
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(contactEmail)?subject=\(encoded)")
            ?? URL(string: "mailto:\(contactEmail)")!
    }
}

#Preview {
    AboutView()
}
