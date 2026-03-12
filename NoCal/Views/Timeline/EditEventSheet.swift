/// EditEventSheet.swift
/// iOS Calendar 앱 스타일의 EKEvent 편집 시트.
/// - 제목 / 하루 종일 토글 / 시작·종료 DatePicker / 캘린더 선택 / 메모

import SwiftUI
import EventKit

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    let event: EKEvent

    @State private var title:             String
    @State private var isAllDay:          Bool
    @State private var startDate:         Date
    @State private var endDate:           Date
    @State private var notes:             String
    @State private var selectedCalendar:  EKCalendar?
    @State private var error:             String?
    @State private var isSaving:          Bool = false

    private let eventKit = EventKitService.shared

    init(event: EKEvent) {
        self.event = event
        _title            = State(initialValue: event.title ?? "")
        _isAllDay         = State(initialValue: event.isAllDay)
        _startDate        = State(initialValue: event.startDate)
        _endDate          = State(initialValue: event.endDate)
        _notes            = State(initialValue: event.notes ?? "")
        _selectedCalendar = State(initialValue: event.calendar)
    }

    private var calendars: [EKCalendar] {
        eventKit.availableCalendars(for: .event)
    }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            Form {

                // ── 제목 ─────────────────────────────────────────────────
                Section {
                    TextField("제목", text: $title)
                        .font(.headline)
                }

                // ── 시간 ─────────────────────────────────────────────────
                Section("시간") {
                    Toggle("하루 종일", isOn: $isAllDay)
                        .onChange(of: isAllDay) { _, allDay in
                            if allDay {
                                startDate = Calendar.current.startOfDay(for: startDate)
                                endDate   = Calendar.current.startOfDay(for: endDate)
                            }
                        }

                    DatePicker(
                        "시작",
                        selection: $startDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .onChange(of: startDate) { _, newStart in
                        if endDate < newStart {
                            endDate = newStart.addingTimeInterval(3600)
                        }
                    }

                    DatePicker(
                        "종료",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                }

                // ── 캘린더 선택 ───────────────────────────────────────────
                if !calendars.isEmpty {
                    Section("캘린더") {
                        Picker("캘린더", selection: $selectedCalendar) {
                            ForEach(calendars, id: \.calendarIdentifier) { cal in
                                Label {
                                    Text(cal.title)
                                } icon: {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor))
                                        .frame(width: 10, height: 10)
                                }
                                .tag(Optional(cal))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // ── 메모 ─────────────────────────────────────────────────
                Section("메모") {
                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
            .navigationTitle("일정 편집")
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
        .frame(minWidth: 380, minHeight: 380)
        #endif
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
            try eventKit.updateEvent(
                event,
                title:    trimmed,
                start:    startDate,
                end:      endDate,
                isAllDay: isAllDay,
                calendar: selectedCalendar,
                notes:    notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving   = false
        }
    }
}
