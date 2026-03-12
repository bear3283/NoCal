/// EditReminderSheet.swift
/// iOS Reminders 앱 스타일의 EKReminder 편집 시트.
/// - 제목 / 메모 / 날짜 토글 + DatePicker / 우선순위 / 목록 선택

import SwiftUI
import EventKit

struct EditReminderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let reminder: EKReminder

    @State private var title:        String
    @State private var notes:        String
    @State private var hasDueDate:   Bool
    @State private var dueDate:      Date
    @State private var priority:     Int
    @State private var selectedList: EKCalendar?
    @State private var error:        String?
    @State private var isSaving:     Bool = false

    private let eventKit = EventKitService.shared

    // iOS Reminders 앱 우선순위 레이블
    private let priorityOptions: [(label: String, value: Int)] = [
        ("없음", 0), ("낮음", 9), ("보통", 5), ("높음", 1)
    ]

    init(reminder: EKReminder) {
        self.reminder = reminder
        _title        = State(initialValue: reminder.title ?? "")
        _notes        = State(initialValue: reminder.notes ?? "")
        _hasDueDate   = State(initialValue: reminder.dueDateComponents != nil)
        _dueDate      = State(initialValue: reminder.dueDateComponents?.date ?? Date())
        _priority     = State(initialValue: reminder.priority)
        _selectedList = State(initialValue: reminder.calendar)
    }

    private var lists: [EKCalendar] {
        eventKit.availableCalendars(for: .reminder)
    }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            Form {

                // ── 제목 + 메모 ───────────────────────────────────────────
                Section {
                    TextField("미리알림", text: $title)
                        .font(.headline)

                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .foregroundStyle(.secondary)
                }

                // ── 날짜 ─────────────────────────────────────────────────
                Section {
                    Toggle("날짜 및 시간", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker(
                            "마감일",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // ── 우선순위 ─────────────────────────────────────────────
                Section {
                    Picker("우선순위", selection: $priority) {
                        ForEach(priorityOptions, id: \.value) { opt in
                            HStack(spacing: 6) {
                                priorityIcon(opt.value)
                                Text(opt.label)
                            }
                            .tag(opt.value)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // ── 목록 선택 ─────────────────────────────────────────────
                if !lists.isEmpty {
                    Section("목록") {
                        Picker("목록", selection: $selectedList) {
                            ForEach(lists, id: \.calendarIdentifier) { list in
                                Label {
                                    Text(list.title)
                                } icon: {
                                    Circle()
                                        .fill(Color(cgColor: list.cgColor))
                                        .frame(width: 10, height: 10)
                                }
                                .tag(Optional(list))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // ── 에러 ─────────────────────────────────────────────────
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("미리알림 편집")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 360)
        #endif
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Priority Icon (iOS Reminders 스타일 느낌표)
    // ─────────────────────────────────────────────────────────────────────
    @ViewBuilder
    private func priorityIcon(_ value: Int) -> some View {
        switch value {
        case 1:  Text("!!!").font(.caption.weight(.bold)).foregroundStyle(.red)
        case 5:  Text("!!").font(.caption.weight(.bold)).foregroundStyle(.orange)
        case 9:  Text("!").font(.caption.weight(.bold)).foregroundStyle(.yellow)
        default: Image(systemName: "minus").font(.caption).foregroundStyle(.secondary)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Save
    // ─────────────────────────────────────────────────────────────────────
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        error    = nil

        do {
            try eventKit.updateReminder(
                reminder,
                title:    trimmed,
                dueDate:  hasDueDate ? dueDate : nil,
                priority: priority,
                calendar: selectedList,
                notes:    notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving   = false
        }
    }
}
