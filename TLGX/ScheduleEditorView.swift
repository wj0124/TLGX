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
        let initialMinute = initialSchedule?.minute ?? 0
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
                    .frame(maxHeight: 160)
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
                            onSave(nil)
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
            .navigationTitle("提醒时间")
            .navigationBarTitleDisplayMode(.inline)
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

    private static let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    private var weekdayChips: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                let weekday = i + 1
                let isOn = weekdays.contains(weekday)
                Button {
                    if isOn {
                        weekdays.remove(weekday)
                    } else {
                        weekdays.insert(weekday)
                    }
                } label: {
                    Text(Self.weekdayLabels[i])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            isOn ? Color.indigo : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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
    /// Human-readable summary like "每天 19:00" or "周一、三、五 08:30".
    var displayText: String {
        let time = String(format: "%02d:%02d", hour, minute)
        let prefix: String
        if weekdays.isEmpty {
            prefix = "只一次"
        } else if weekdays == Set(1...7) {
            prefix = "每天"
        } else if weekdays == [2, 3, 4, 5, 6] {
            prefix = "工作日"
        } else if weekdays == [1, 7] {
            prefix = "周末"
        } else {
            let names = ["日", "一", "二", "三", "四", "五", "六"]
            let parts = weekdays.sorted().map { names[$0 - 1] }
            prefix = "周" + parts.joined(separator: "、")
        }
        return "\(prefix) \(time)"
    }
}
