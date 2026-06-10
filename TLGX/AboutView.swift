//
//  AboutView.swift
//  TLGX
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion: String = {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }()

    var body: some View {
        NavigationStack {
            List {
                headerSection
                infoSection
                actionsSection
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

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(spacing: 4) {
                    Text("提了个醒")
                        .font(.title3.weight(.semibold))
                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            LabeledContent("描述", value: "一款专注个人提醒的轻量 App")
            LabeledContent("同步", value: "支持 iCloud 多设备自动同步")
            LabeledContent("实时活动", value: "锁屏与状态栏持续显示")
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            Link(destination: mailURL) {
                Label("发邮件给作者", systemImage: "envelope.fill")
            }
        } footer: {
            Text("欢迎反馈 bug、功能建议或使用感受。")
        }
    }

    private var mailURL: URL {
        let subject = String(localized: "提了个醒 反馈")
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:w2287307@gmail.com?subject=\(encoded)")
            ?? URL(string: "mailto:w2287307@gmail.com")!
    }
}

#Preview {
    AboutView()
}
