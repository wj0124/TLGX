//
//  ContentView.swift
//  TLGX
//

import ActivityKit
import SwiftUI
import UserNotifications
import WidgetKit

struct ContentView: View {
    @EnvironmentObject private var notifications: NotificationDelegate

    @State private var reminders: [Reminder] = []
    @State private var activeID: UUID? = nil
    @State private var activity: Activity<TLGXAttributes>? = nil
    @State private var errorMessage: String? = nil

    @State private var composerText: String = ""
    @State private var editingID: UUID? = nil
    @FocusState private var composerFocused: Bool

    /// User-picked emoji override for the composer; `nil` = auto-detect from text.
    @State private var composerEmoji: String? = nil
    /// Controls the emoji picker sheet visibility.
    @State private var showEmojiPicker: Bool = false

    /// Reminder waiting for the user to confirm starting a Live Activity
    /// (set when the user taps a delivered local notification).
    @State private var pendingActivityReminder: Reminder? = nil

    /// Reminder currently being edited in the schedule editor sheet.
    @State private var editingScheduleReminder: Reminder? = nil

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
            .alert(
                "开启实时活动？",
                isPresented: Binding(
                    get: { pendingActivityReminder != nil },
                    set: { if !$0 { pendingActivityReminder = nil } }
                ),
                presenting: pendingActivityReminder
            ) { reminder in
                Button("开启") {
                    pendingActivityReminder = nil
                    Task { await startActivity(for: reminder) }
                }
                Button("稍后", role: .cancel) {
                    pendingActivityReminder = nil
                }
            } message: { reminder in
                Text("是否将「\(reminder.title)」开启到灵动岛 / 锁屏？")
            }
            .sheet(item: $editingScheduleReminder) { reminder in
                ScheduleEditorView(
                    reminderTitle: reminder.title,
                    initialSchedule: reminder.schedule,
                    onSave: { newSchedule in
                        saveSchedule(newSchedule, for: reminder)
                        editingScheduleReminder = nil
                    },
                    onCancel: {
                        editingScheduleReminder = nil
                    }
                )
            }
        }
        .onAppear {
            reminders = ReminderStore.load()
            syncWithSystem()
            handlePendingReminder()
        }
        .onChange(of: notifications.pendingReminderID) { _, _ in
            handlePendingReminder()
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
                ForEach(displayReminders) { reminder in
                    row(reminder)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                togglePin(reminder)
                            } label: {
                                Label(reminder.isPinned ? "取消置顶" : "置顶",
                                      systemImage: reminder.isPinned ? "pin.slash.fill" : "pin.fill")
                            }
                            .tint(.orange)

                            Button {
                                editingScheduleReminder = reminder
                            } label: {
                                Label("提醒时间", systemImage: "clock")
                            }
                            .tint(.indigo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(reminder)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            } footer: {
                Text("点击行可编辑内容；右侧开关用于开启 / 关闭实时活动；左滑可置顶或设置提醒时间；桌面小组件请长按“编辑”选择要显示的提醒。")
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    /// Reminders ordered for display: pinned items first, otherwise preserving
    /// the underlying insertion order in `reminders`.
    private var displayReminders: [Reminder] {
        reminders.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isPinned != rhs.element.isPinned {
                    return lhs.element.isPinned && !rhs.element.isPinned
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    @ViewBuilder
    private func row(_ reminder: Reminder) -> some View {
        let isLive = activeID == reminder.id
        let isEditing = editingID == reminder.id

        let displayEmoji = reminder.emoji ?? EmojiGenerator.emoji(for: reminder.title)
        let tint = EmojiGenerator.tint(for: displayEmoji)

        HStack(alignment: .center, spacing: 12) {
            Text(displayEmoji)
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.18)))
                .id(displayEmoji)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.6),
                           value: displayEmoji)

            Button {
                beginEdit(reminder)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if reminder.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .accessibilityLabel("已置顶")
                        }
                        Text(reminder.title)
                            .font(.body)
                            .foregroundStyle(isEditing ? Color.indigo : .primary)
                            .lineLimit(2)
                    }
                    if let schedule = reminder.schedule {
                        Label(schedule.displayText, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
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
                Button {
                    composerFocused = false
                    showEmojiPicker = true
                } label: {
                    let composerTint = EmojiGenerator.tint(for: effectiveComposerEmoji)
                    Text(effectiveComposerEmoji)
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(composerTint.opacity(0.18))
                        )
                        .overlay(
                            Circle()
                                .stroke(composerEmoji != nil ? composerTint : Color.clear,
                                        lineWidth: 1.5)
                        )
                        .id(effectiveComposerEmoji)
                        .transition(.scale.combined(with: .opacity))
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.35, dampingFraction: 0.6),
                           value: effectiveComposerEmoji)

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
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(
                current: effectiveComposerEmoji,
                autoEmoji: EmojiGenerator.emoji(for: composerText),
                isOverridden: composerEmoji != nil,
                onSelect: { picked in
                    composerEmoji = picked
                }
            )
        }
    }

    /// Effective emoji shown on the composer button: user override > auto-detect.
    private var effectiveComposerEmoji: String {
        composerEmoji ?? EmojiGenerator.emoji(for: composerText)
    }

    // MARK: - Composer Actions

    private func beginEdit(_ reminder: Reminder) {
        if editingID == reminder.id {
            cancelEdit()
        } else {
            editingID = reminder.id
            composerText = reminder.title
            composerEmoji = reminder.emoji
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
        composerEmoji = nil
        composerFocused = false
    }

    private func submit() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let id = editingID, let idx = reminders.firstIndex(where: { $0.id == id }) {
            reminders[idx].title = trimmed
            reminders[idx].emoji = composerEmoji
            ReminderStore.save(reminders)
            WidgetCenter.shared.reloadAllTimelines()
            syncActiveActivityTitle(for: reminders[idx])
            // If this reminder has a schedule with no custom push text, the
            // notification body uses the title; re-register so the change
            // takes effect.
            if let sched = reminders[idx].schedule,
               (sched.pushText ?? "").isEmpty {
                let updated = reminders[idx]
                Task { try? await ReminderScheduler.schedule(reminder: updated) }
            }
            editingID = nil
            composerText = ""
            composerEmoji = nil
            composerFocused = false
        } else {
            let new = Reminder(title: trimmed, emoji: composerEmoji)
            reminders.insert(new, at: 0)
            ReminderStore.save(reminders)
            WidgetCenter.shared.reloadAllTimelines()
            composerText = ""
            composerEmoji = nil
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
        ReminderScheduler.cancel(reminderID: reminder.id)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func togglePin(_ reminder: Reminder) {
        guard let idx = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            reminders[idx].isPinned.toggle()
        }
        ReminderStore.save(reminders)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Schedule

    /// Persist a schedule change (nil = clear) and re-register notifications.
    private func saveSchedule(_ schedule: ReminderSchedule?, for reminder: Reminder) {
        guard let idx = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[idx].schedule = schedule
        ReminderStore.save(reminders)
        let updated = reminders[idx]
        WidgetCenter.shared.reloadAllTimelines()

        Task {
            if schedule != nil {
                let granted = await ReminderScheduler.requestAuthIfNeeded()
                guard granted else {
                    await MainActor.run {
                        errorMessage = "请在 设置 > 提了个醒 中开启「通知」权限"
                    }
                    return
                }
            }
            do {
                try await ReminderScheduler.schedule(reminder: updated)
            } catch {
                await MainActor.run {
                    errorMessage = "设置失败：\(error.localizedDescription)"
                }
            }
        }
    }

    /// Consume a reminder ID delivered by a notification tap and prompt the
    /// user to confirm starting its Live Activity.
    private func handlePendingReminder() {
        guard let id = notifications.pendingReminderID else { return }

        let target = reminders.first(where: { $0.id == id })
            ?? ReminderStore.load().first(where: { $0.id == id })

        notifications.pendingReminderID = nil

        guard let reminder = target else { return }

        if reminders.first(where: { $0.id == reminder.id }) == nil {
            reminders = ReminderStore.load()
        }

        // Don't re-prompt if a Live Activity for this reminder is already running.
        guard activeID != reminder.id else { return }

        pendingActivityReminder = reminder
    }

    private func syncActiveActivityTitle(for reminder: Reminder) {
        guard activeID == reminder.id, let act = activity else { return }
        let trimmed = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let state = TLGXAttributes.ContentState(title: trimmed,
                                                    emoji: reminder.emoji ?? EmojiGenerator.emoji(for: trimmed))
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
        let state = TLGXAttributes.ContentState(title: reminder.title,
                                                emoji: reminder.emoji ?? EmojiGenerator.emoji(for: reminder.title))
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
        .environmentObject(NotificationDelegate.shared)
}
