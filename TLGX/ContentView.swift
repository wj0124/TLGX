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

    /// Controls the About / privacy / help sheet visibility.
    @State private var showAbout: Bool = false

    /// Controls the Settings sheet (iCloud sync + future toggles).
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleSubtitleStack
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("设置", systemImage: "gearshape")
                        }
                        Button {
                            showAbout = true
                        } label: {
                            Label("关于", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("更多")
                }
            }
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
                Text("是否将「\(reminder.title)」开启为实时活动？")
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
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
        .onReceive(NotificationCenter.default.publisher(
            for: ReminderStore.didChangeRemotelyNotification
        )) { _ in
            // iCloud delivered an update from another device; rehydrate
            // the in-memory list so the UI reflects the merged state.
            reminders = ReminderStore.load()
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
        ScrollViewReader { proxy in
            List {
                Section {
                    let items = displayReminders
                    ForEach(items, id: \.id) { reminder in
                        row(reminder)
                            .id(reminder.id)
                            .listRowBackground(rowBackground(for: reminder))
                            .listRowSeparator(.hidden)
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
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: editingID) { _, newID in
                guard let id = newID else { return }
                // Wait one tick so the keyboard's safe-area inset is applied
                // before scrolling, otherwise the target row can land under
                // the composer.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
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

    /// State-aware row background: encodes "currently live / being edited /
    /// pinned" as a quiet tinted wash so the user can scan status without
    /// extra UI affordances. Falls back to transparent for the common case.
    private func rowBackground(for reminder: Reminder) -> Color {
        if activeID == reminder.id {
            let tint = EmojiGenerator.tint(for: reminder.emoji ?? EmojiGenerator.emoji(for: reminder.title))
            return tint.opacity(0.12)
        }
        if reminder.isPinned {
            // Neutral, non-colored wash so pinned items read as "slightly
            // raised" against the plain list background, without competing
            // with the live/editing accent colors.
            return Color.primary.opacity(0.06)
        }
        return .clear
    }

    @ViewBuilder
    private func row(_ reminder: Reminder) -> some View {
        let isLive = activeID == reminder.id
        let isEditing = editingID == reminder.id

        let displayEmoji = reminder.emoji ?? EmojiGenerator.emoji(for: reminder.title)
        let tint = EmojiGenerator.tint(for: displayEmoji)

        HStack(alignment: .center, spacing: 12) {
            Text(displayEmoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.3)))

            Button {
                beginEdit(reminder)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.body)
                        .foregroundStyle(isEditing ? Color.indigo : .primary)
                        .lineLimit(2)
                        .accessibilityLabel(reminder.isPinned ? "\(reminder.title)，已置顶" : reminder.title)
                    if let schedule = reminder.schedule {
                        scheduleChip(schedule)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("实时活动", isOn: Binding(
                get: { isLive },
                set: { toggle(reminder, on: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(tint)
            .accessibilityLabel("实时活动")
        }
        .padding(.vertical, 4)
    }

    /// Compact "time · recurrence" chip rendered below a reminder's title.
    /// Uses Liquid Glass on iOS 26+, ultraThinMaterial as a fallback.
    @ViewBuilder
    private func scheduleChip(_ schedule: ReminderSchedule) -> some View {
        HStack(spacing: 4) {
            Text(schedule.timeText)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text("·")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(schedule.recurrenceText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .modifier(ScheduleChipBackground())
    }

    private struct ScheduleChipBackground: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content.glassEffect(in: Capsule())
            } else {
                content.background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Title + subtitle

    /// Custom principal toolbar content: bold title with a tappable status
    /// subtitle (active live activity). The subtitle is added/removed from
    /// the layout normally — the title's reflow is smoothed with a spring
    /// animation, and the subtitle itself fades + slides from the top.
    @ViewBuilder
    private var titleSubtitleStack: some View {
        let info = titleSubtitle
        VStack(spacing: 1) {
            Text("提了个醒")
                .font(.headline)
                .foregroundStyle(.primary)
            if let info {
                Text(info.text)
                    .font(.caption2)
                    .foregroundStyle(info.tint)
                    .lineLimit(1)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                    .onTapGesture(perform: info.tap)
            }
        }
        .animation(.smooth(duration: 0.28), value: info?.text)
    }

    /// Resolved subtitle payload: shown only while a live activity is
    /// running. Returns `nil` otherwise so the title sits alone at its
    /// normal vertical center.
    private var titleSubtitle: (text: String, tint: Color, tap: () -> Void)? {
        guard let active = reminders.first(where: { $0.id == activeID }) else { return nil }
        let tint = EmojiGenerator.tint(for: active.emoji ?? EmojiGenerator.emoji(for: active.title))
        return ("进行中:\(active.title)", tint, { beginEdit(active) })
    }

    private var composerBar: some View {
        let isEditing = editingID != nil
        let canSubmit = !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(alignment: .center, spacing: 10) {
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
                .accessibilityLabel("选择表情")
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
                        .fill(Color.fieldFill)
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
                .accessibilityLabel(trailingIconAccessibilityLabel(isEditing: isEditing,
                                                                  canSubmit: canSubmit))
                .animation(.easeInOut(duration: 0.15), value: canSubmit)
                .animation(.easeInOut(duration: 0.15), value: composerFocused)
            }
            .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(ComposerBarBackground().ignoresSafeArea(edges: .bottom))
        .animation(.smooth(duration: 0.2), value: isEditing)
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

    /// Background for the whole composer bar — Liquid Glass on iOS 26+,
    /// `ultraThinMaterial` as a fallback. No custom shadow/divider.
    private struct ComposerBarBackground: View {
        var body: some View {
            if #available(iOS 26.0, *) {
                Rectangle().fill(.clear).glassEffect(in: Rectangle())
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
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

    /// Unified 36×36 filled-circle action button. Only the SF Symbol and the
    /// fill color swap between states so the geometry stays stable.
    @ViewBuilder
    private func trailingIcon(isEditing: Bool, canSubmit: Bool) -> some View {
        let symbol: String = {
            if canSubmit { return isEditing ? "checkmark" : "arrow.up" }
            if composerFocused { return "keyboard.chevron.compact.down" }
            return "arrow.up"
        }()
        let fill: Color = canSubmit
            ? .indigo
            : Color.secondary.opacity(composerFocused ? 0.6 : 0.35)

        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(fill, in: Circle())
            .contentTransition(.symbolEffect(.replace))
    }

    private func trailingIconAccessibilityLabel(isEditing: Bool, canSubmit: Bool) -> String {
        if canSubmit { return isEditing ? "保存修改" : "新建提醒" }
        if composerFocused { return "收起键盘" }
        return "新建提醒"
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
            withAnimation(.snappy) {
                reminders.insert(new, at: 0)
            }
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
        withAnimation(.snappy) {
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
        let state = TLGXAttributes.ContentState(
            title: trimmed,
            emoji: reminder.emoji ?? EmojiGenerator.emoji(for: trimmed)
        )
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

        let attrs = TLGXAttributes(
            reminderID: reminder.id.uuidString,
            startedAt: Date()
        )
        let state = TLGXAttributes.ContentState(
            title: reminder.title,
            emoji: reminder.emoji ?? EmojiGenerator.emoji(for: reminder.title)
        )
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

// MARK: - Theme

extension Color {
    /// Background fill for text fields / picker tiles.
    /// `systemGray6` in light mode is nearly black in dark mode and visually
    /// collapses into the system background; lift to `systemGray5` in dark.
    static let fieldFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .systemGray5 : .systemGray6
    })

    /// Opaque card fill for reminder rows. Solid color (no blur / no shadow)
    /// so plain-list scrolling stays at 120fps. Pushed one step lighter in dark
    /// mode (`tertiarySystemBackground` #2C2C2E) so cards visibly float over
    /// the pure-black page background.
    static let cardFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.tertiarySystemBackground
            : UIColor.systemBackground
    })

    /// Page background sitting behind the reminder cards. Intentionally one
    /// step darker than the card so the two layers separate clearly:
    /// - light: `systemGray5` (#E5E5EA) under white cards
    /// - dark:  `systemBackground` (#000000) under #2C2C2E cards
    static let pageFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.systemBackground
            : UIColor.systemGray5
    })
}
