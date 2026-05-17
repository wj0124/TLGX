//
//  ContentView.swift
//  TLGX
//

import ActivityKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var reminders: [Reminder] = []
    @State private var activeID: UUID? = nil
    @State private var activity: Activity<TLGXAttributes>? = nil
    @State private var errorMessage: String? = nil

    @State private var composerText: String = ""
    @State private var editingID: UUID? = nil
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("提了个醒")
            .safeAreaInset(edge: .bottom) {
                composerBar
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            reminders = ReminderStore.load()
            syncWithSystem()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("还没有提醒")
                .font(.headline)
            Text("在下方输入框新建一条")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            Section {
                ForEach(reminders) { reminder in
                    row(reminder)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(reminder)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            } footer: {
                Text("点击行可编辑内容；右侧开关用于开启 / 关闭实时活动；桌面小组件请长按“编辑”选择要显示的提醒。")
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func row(_ reminder: Reminder) -> some View {
        let isLive = activeID == reminder.id
        let isEditing = editingID == reminder.id
        HStack(alignment: .center, spacing: 12) {
            Button {
                beginEdit(reminder)
            } label: {
                Text(reminder.title)
                    .font(.body)
                    .foregroundStyle(isEditing ? Color.indigo : .primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 24)

            Toggle("实时活动", isOn: Binding(
                get: { isLive },
                set: { toggle(reminder, on: $0) }
            ))
            .labelsHidden()
            .tint(.indigo)
        }
        .padding(.vertical, 4)
        .listRowBackground(isEditing ? Color.indigo.opacity(0.08) : nil)
    }

    private var composerBar: some View {
        let isEditing = editingID != nil
        let canSubmit = !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center, spacing: 10) {
                TextField(
                    isEditing ? "修改提醒内容" : "新建提醒…",
                    text: $composerText,
                    axis: .vertical
                )
                .font(.body)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .systemGray6))
                )

                Button {
                    if canSubmit {
                        submit()
                    } else {
                        composerFocused = false
                    }
                } label: {
                    trailingIcon(isEditing: isEditing, canSubmit: canSubmit)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: canSubmit)
                .animation(.easeInOut(duration: 0.15), value: composerFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea(edges: .bottom)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: -2)
            )
            .animation(.easeInOut(duration: 0.18), value: isEditing)
        }
    }

    // MARK: - Composer Actions

    private func beginEdit(_ reminder: Reminder) {
        if editingID == reminder.id {
            cancelEdit()
        } else {
            editingID = reminder.id
            composerText = reminder.title
            composerFocused = true
        }
    }

    @ViewBuilder
    private func trailingIcon(isEditing: Bool, canSubmit: Bool) -> some View {
        if !canSubmit && composerFocused {
            // Keyboard dismiss: render inside a filled circle so it visually
            // matches the size/weight of the filled-circle action icons.
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.6), in: Circle())
        } else {
            Image(systemName: isEditing ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(canSubmit ? Color.indigo : Color.secondary.opacity(0.5))
        }
    }

    private func cancelEdit() {
        editingID = nil
        composerText = ""
        composerFocused = false
    }

    private func submit() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let id = editingID, let idx = reminders.firstIndex(where: { $0.id == id }) {
            reminders[idx].title = trimmed
            ReminderStore.save(reminders)
            WidgetCenter.shared.reloadAllTimelines()
            syncActiveActivityTitle(for: reminders[idx])
            editingID = nil
            composerText = ""
            composerFocused = false
        } else {
            let new = Reminder(title: trimmed)
            reminders.insert(new, at: 0)
            ReminderStore.save(reminders)
            WidgetCenter.shared.reloadAllTimelines()
            composerText = ""
            // Keep focus to allow rapid entry
        }
    }

    private func delete(_ reminder: Reminder) {
        if activeID == reminder.id {
            Task { await endActivity() }
        }
        if editingID == reminder.id {
            cancelEdit()
        }
        reminders.removeAll { $0.id == reminder.id }
        ReminderStore.save(reminders)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncActiveActivityTitle(for reminder: Reminder) {
        guard activeID == reminder.id, let act = activity else { return }
        let trimmed = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let state = TLGXAttributes.ContentState(title: trimmed)
        Task {
            await act.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func toggle(_ reminder: Reminder, on: Bool) {
        Task {
            if on {
                await startActivity(for: reminder)
            } else if activeID == reminder.id {
                await endActivity()
            }
        }
    }

    // MARK: - Live Activity

    private func syncWithSystem() {
        let existing = Activity<TLGXAttributes>.activities.first
        if let existing, let uuid = UUID(uuidString: existing.attributes.reminderID) {
            activity = existing
            activeID = uuid
            observe(existing)
        } else {
            activity = nil
            activeID = nil
        }
    }

    private func startActivity(for reminder: Reminder) async {
        // End any existing activity first (only one allowed at a time)
        if let current = activity {
            await current.end(nil, dismissalPolicy: .immediate)
            activity = nil
            activeID = nil
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await MainActor.run {
                errorMessage = "请在 设置 > 提了个醒 中开启「实时活动」权限"
            }
            return
        }

        let attrs = TLGXAttributes(reminderID: reminder.id.uuidString)
        let state = TLGXAttributes.ContentState(title: reminder.title)
        do {
            let act = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            await MainActor.run {
                self.activity = act
                self.activeID = reminder.id
            }
            observe(act)
        } catch {
            await MainActor.run {
                errorMessage = "启动失败：\(error.localizedDescription)"
            }
        }
    }

    private func endActivity() async {
        guard let current = activity else {
            await MainActor.run { activeID = nil }
            return
        }
        await current.end(nil, dismissalPolicy: .immediate)
        await MainActor.run {
            self.activity = nil
            self.activeID = nil
        }
    }

    private func observe(_ act: Activity<TLGXAttributes>) {
        Task {
            for await state in act.activityStateUpdates {
                if state == .dismissed || state == .ended {
                    await MainActor.run {
                        if self.activity?.id == act.id {
                            self.activity = nil
                            self.activeID = nil
                        }
                    }
                    break
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
