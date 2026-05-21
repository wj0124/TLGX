//
//  AboutView.swift
//  TLGX
//
//  Privacy promise, usage tips, and contact info. All content is hard-coded,
//  no network requests, no analytics.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let contactEmail = "w2287307@gmail.com"

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "提了个醒"
    }

    var body: some View {
        NavigationStack {
            List {
                heroSection
                privacySection
                liveActivitySection
                usageSection
                contactSection
            }
            .listStyle(.insetGrouped)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(backgroundGradient.ignoresSafeArea())
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

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color.indigo.opacity(0.08),
                Color(.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        Section {
            VStack(spacing: 12) {
                appIconView
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)

                VStack(spacing: 4) {
                    Text(appName)
                        .font(.title2.weight(.semibold))
                    Text(appVersion)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text("一个安静、不打扰、不耗电的提醒小工具")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        if let image = Self.appIconImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    /// Best-effort lookup of the bundled AppIcon (works even when the icon
    /// is only declared inside Assets.xcassets).
    private static func appIconImage() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastName = files.last,
           let image = UIImage(named: lastName) {
            return image
        }
        return UIImage(named: "AppIcon") ?? UIImage(named: "appicon")
    }

    // MARK: - Sections

    private var privacySection: some View {
        Section {
            sectionHeader(icon: "lock.shield.fill",
                          color: .green,
                          title: "隐私承诺")

            bullet("提醒数据仅保存在你的设备和你自己的 iCloud 中", color: .green)
            bullet("iCloud 同步由系统直接完成，作者无法看到你的内容", color: .green)
            bullet("不收集、不上传任何信息到第三方服务器", color: .green)
            bullet("没有账号系统、没有广告 SDK、没有数据分析", color: .green)
        }
    }

    private var liveActivitySection: some View {
        Section {
            sectionHeader(icon: "bolt.badge.checkmark.fill",
                          color: .orange,
                          title: "放心使用")

            bullet("实时活动由系统统一调度，App 不会一直在后台运行", color: .orange)
            bullet("几乎不耗电：显示与刷新都由系统接管", color: .orange)
            bullet("即使 App 被划掉杀死，锁屏与灵动岛上的提醒依然正常显示", color: .orange)
            bullet("通知与定时提醒同样由系统本地调度，不依赖 App 是否打开", color: .orange)
        } footer: {
            Text("你可以放心划掉 App，提醒不会因此失效。")
        }
    }

    private var usageSection: some View {
        Section {
            sectionHeader(icon: "hand.tap.fill",
                          color: .indigo,
                          title: "使用说明")

            tipRow(icon: "plus.bubble.fill", color: .indigo,
                   title: "新建",
                   detail: "在底部输入框写下提醒，点发送即可")
            tipRow(icon: "pencil", color: .blue,
                   title: "编辑",
                   detail: "点击任意一条提醒可重新编辑内容")
            tipRow(icon: "pin.fill", color: .pink,
                   title: "置顶",
                   detail: "向右滑动一条提醒")
            tipRow(icon: "clock.fill", color: .orange,
                   title: "定时",
                   detail: "向右滑动后点击「时间」可设置每日 / 每周提醒")
            tipRow(icon: "switch.2", color: .green,
                   title: "开启",
                   detail: "右侧开关把提醒推到锁屏与状态栏持续显示")
            tipRow(icon: "trash.fill", color: .red,
                   title: "删除",
                   detail: "向左滑动一条提醒")
        }
    }

    private var contactSection: some View {
        Section {
            Button {
                openURL(mailURL)
            } label: {
                HStack(spacing: 12) {
                    iconBadge(systemName: "envelope.fill", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("发邮件给作者")
                            .foregroundStyle(.primary)
                            .font(.subheadline.weight(.medium))
                        Text(contactEmail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
        } header: {
            Text("联系作者")
        } footer: {
            Text("欢迎反馈 bug、功能建议或使用感受。")
        }
    }

    // MARK: - Helpers

    private var mailURL: URL {
        let subject = "提了个醒 反馈"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(contactEmail)?subject=\(encoded)")
            ?? URL(string: "mailto:\(contactEmail)")!
    }

    private func sectionHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            iconBadge(systemName: icon, color: color)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
    }

    private func iconBadge(systemName: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color.gradient)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private func bullet(_ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color)
                .imageScale(.small)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
    }

    private func tipRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            iconBadge(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    AboutView()
}
