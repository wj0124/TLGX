//
//  ContentView.swift
//  TLGX
//

import SwiftUI
import ActivityKit

struct ContentView: View {
    @State private var text: String = ""
    @State private var activity: Activity<TLGXAttributes>? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("实时活动 Demo")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("输入要显示的内容", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .onChange(of: text) { newValue in
                    Task { await updateOrStart(message: newValue) }
                }

            HStack(spacing: 16) {
                Button {
                    Task { await startActivity() }
                } label: {
                    Text("开始活动").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task { await endActivity() }
                } label: {
                    Text("结束活动").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    private func updateOrStart(message: String) async {
        if activity == nil {
            await startActivity()
        } else {
            await updateActivity(message: message)
        }
    }

    private func startActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = "系统未开启实时活动权限，请在 设置 > TLGX 中允许。"
            return
        }
        if activity != nil {
            await updateActivity(message: text)
            return
        }
        let attributes = TLGXAttributes(name: "TLGX")
        let state = TLGXAttributes.ContentState(message: text)
        do {
            let act = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            activity = act
            errorMessage = nil
        } catch {
            errorMessage = "启动失败：\(error.localizedDescription)"
        }
    }

    private func updateActivity(message: String) async {
        guard let activity else { return }
        let state = TLGXAttributes.ContentState(message: message)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    private func endActivity() async {
        guard let activity else { return }
        let state = TLGXAttributes.ContentState(message: text)
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.activity = nil
    }
}

#Preview {
    ContentView()
}
