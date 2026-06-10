//
//  ScheduleEditorView.swift
//  TLGX
//
//  Editor sheet for a reminder's notification schedule: time, weekdays,
//  and optional custom push text.
//

import SwiftUI

struct ScheduleEditorView: View {
    let reminderTitle: String
    let initialSchedule: ReminderSchedule?
    let onSave: (ReminderSchedule?) -> Void
    let onCancel: () -> Void

    @State private var time: Date
    @State private var weekdays: Set<Int>
    @State private var pushText: String
    @State private var confirmingClear: Bool = false

    init(reminderTitle: String,
         initialSchedule: ReminderSchedule?,
         onSave: @escaping (ReminderSchedule?) -> Void,
         onCancel: @escaping () -> Void) {
        self.reminderTitle = reminderTitle
        self.initialSchedule = initialSchedule
        self.onSave = onSave
        self.onCancel = onCancel

        let cal = Calendar.current
        let now = Date()
        let initialHour = initialSchedule?.hour ?? cal.component(.hour, from: now)
        let initialMinute = initialSchedule?.minute ?? cal.component(.minute, from: now)
        let base = cal.date(bySettingHour: initialHour, minute: initialMinute, second: 0, of: now) ?? now
        _time = State(initialValue: base)
        _weekdays = State(initialValue: initialSchedule?.weekdays ?? [])
        _pushText = State(initialValue: initialSchedule?.pushText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("时间",
                               selection: $time,
                               displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Section("重复") {
                    weekdayChips
                    presetRow
                }

                Section {
                    TextField("默认使用提醒内容：\(reminderTitle)",
                              text: $pushText,
                              axis: .vertical)
                    .lineLimit(1...3)
                } header: {
                    Text("推送文案")
                } footer: {
                    Text("到点后会收到一条本地通知，留空则使用上方提醒内容。")
                }

                if initialSchedule != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmingClear = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("清除提醒时间")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(reminderTitle)
            .navigationBarTitleDisplayMode(.inline)
            .alert("清除提醒时间？", isPresented: $confirmingClear) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    onSave(nil)
                }
            } message: {
                Text("将一并清空时间、重复周期和推送文案。")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let cal = Calendar.current
                        let h = cal.component(.hour, from: time)
                        let m = cal.component(.minute, from: time)
                        let trimmed = pushText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let schedule = ReminderSchedule(
                            hour: h,
                            minute: m,
                            weekdays: weekdays,
                            pushText: trimmed.isEmpty ? nil : trimmed
                        )
                        onSave(schedule)
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    /// Display order: Monday…Sunday (Chinese convention). Calendar's
    /// `weekday` integers are 1=Sunday…7=Saturday, so each chip's display
    /// index is mapped to the underlying Calendar value via `weekdayValues`.
    private static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private static let weekdayValues = [2, 3, 4, 5, 6, 7, 1]

    private var weekdayChips: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let weekday = Self.weekdayValues[i]
                let isOn = weekdays.contains(weekday)
                let isWeekend = (i == 5 || i == 6)
                let tint: Color = isWeekend ? .orange : .indigo
                Button {
                    if isOn {
                        weekdays.remove(weekday)
                    } else {
                        weekdays.insert(weekday)
                    }
                } label: {
                    weekdayChipLabel(text: Self.weekdayLabels[i],
                                     isOn: isOn,
                                     tint: tint)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    /// Circular day-pip chip à la system Reminders. Selected state is filled
    /// with the per-day tint (weekday = indigo, weekend = orange); on
    /// iOS 26+ that fill is rendered through Liquid Glass for depth.
    @ViewBuilder
    private func weekdayChipLabel(text: String, isOn: Bool, tint: Color) -> some View {
        let size: CGFloat = 36
        let label = Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: size, height: size)

        if isOn {
            if #available(iOS 26.0, *) {
                label.glassEffect(.regular.tint(tint), in: Circle())
            } else {
                label.background(Circle().fill(tint))
            }
        } else {
            label.background(Circle().fill(Color.secondary.opacity(0.12)))
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            preset("只一次", []) 
            preset("每天", Set(1...7))
            preset("工作日", [2, 3, 4, 5, 6])
            preset("周末", [1, 7])
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func preset(_ label: String, _ set: Set<Int>) -> some View {
        let active = (weekdays == set)
        Button {
            weekdays = set
        } label: {
            Text(label)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    active ? Color.indigo.opacity(0.15) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(active ? Color.indigo : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule display helper

extension ReminderSchedule {
    /// Formatted clock time, e.g. "08:30".
    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Recurrence summary, e.g. "工作日" / "每天" / "只一次" / "周一、三、五".
    var recurrenceText: String {
        if weekdays.isEmpty { return String(localized: "只一次") }
        if weekdays == Set(1...7) { return String(localized: "每天") }
        if weekdays == [2, 3, 4, 5, 6] { return String(localized: "工作日") }
        if weekdays == [1, 7] { return String(localized: "周末") }
        // Display order: Mon…Sun (Chinese convention).
        let displayOrder = [2, 3, 4, 5, 6, 7, 1]
        let names: [Int: String] = [2: String(localized: "一"), 3: String(localized: "二"), 4: String(localized: "三"), 5: String(localized: "四"), 6: String(localized: "五"), 7: String(localized: "六"), 1: String(localized: "日")]
        let parts = displayOrder
            .filter { weekdays.contains($0) }
            .compactMap { names[$0] }
        return String(localized: "周\(parts.joined(separator: "、"))")
    }
}
