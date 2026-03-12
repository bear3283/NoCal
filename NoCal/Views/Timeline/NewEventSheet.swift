/// NewEventSheet.swift
/// Phase 3: Sheet for creating a new Calendar event or Reminder from within nocal.

import SwiftUI
import EventKit

struct NewEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Preset values passed from timeline tap
    var presetHour:       Int      = 9
    var presetDate:       Date     = Date()
    var defaultItemType:  ItemType = .event

    enum ItemType { case event, reminder }

    @State private var title:    String   = ""
    @State private var itemType: ItemType
    @State private var startDate:        Date        = Date()
    @State private var duration:         TimeInterval = 3600
    @State private var notes:            String      = ""
    @State private var selectedCalendar: EKCalendar? = nil
    @State private var error:            String?     = nil
    @State private var isSaving:         Bool        = false

    init(presetHour: Int = 9, presetDate: Date = Date(), defaultItemType: ItemType = .event, presetTitle: String = "") {
        self.presetHour      = presetHour
        self.presetDate      = presetDate
        self.defaultItemType = defaultItemType
        self._itemType       = State(initialValue: defaultItemType)
        self._title          = State(initialValue: presetTitle)
    }

    private let eventKit = EventKitService.shared

    private var availableCalendars: [EKCalendar] {
        eventKit.availableCalendars(for: itemType == .event ? .event : .reminder)
    }

    // Duration options
    private let durations: [(String, TimeInterval)] = [
        ("15분", 900), ("30분", 1800), ("1시간", 3600),
        ("1.5시간", 5400), ("2시간", 7200), ("3시간", 10800)
    ]

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            Form {
                // ── Type selector ──────────────────────────────────────
                Section {
                    Picker("유형", selection: $itemType) {
                        Label("캘린더 일정", systemImage: "calendar").tag(ItemType.event)
                        Label("미리알림",   systemImage: "checklist").tag(ItemType.reminder)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                    .padding(.vertical, 2)
                }

                // ── Title ──────────────────────────────────────────────
                Section("내용") {
                    TextField("제목을 입력하세요", text: $title)
                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // ── Time ───────────────────────────────────────────────
                Section("시간") {
                    DatePicker(
                        "시작",
                        selection: $startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    if itemType == .event {
                        Picker("기간", selection: $duration) {
                            ForEach(durations, id: \.0) { label, val in
                                Text(label).tag(val)
                            }
                        }
                        .pickerStyle(.menu)

                        // End time preview
                        let endDate = startDate.addingTimeInterval(duration)
                        LabeledContent("종료") {
                            Text(endDate.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // ── 캘린더 / 목록 선택 ─────────────────────────────────
                if !availableCalendars.isEmpty {
                    Section(itemType == .event ? "캘린더" : "목록") {
                        Picker(
                            itemType == .event ? "캘린더" : "목록",
                            selection: $selectedCalendar
                        ) {
                            Text("기본").tag(Optional<EKCalendar>.none)
                            ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
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

                // ── Error ──────────────────────────────────────────────
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(itemType == .event ? "새 일정" : "새 미리알림")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { save() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .onAppear { configureDefaults() }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 340)
        #endif
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────────────────────────────
    private func configureDefaults() {
        let cal  = Calendar.current
        let hour = cal.component(.hour, from: presetDate)
        let min  = cal.component(.minute, from: presetDate)
        if hour != 0 || min != 0 {
            // presetDate already carries a specific time (e.g. parsed from note text)
            startDate = presetDate
        } else {
            var comps  = cal.dateComponents([.year, .month, .day], from: presetDate)
            comps.hour = presetHour
            comps.minute = 0
            startDate = cal.date(from: comps) ?? presetDate
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        error    = nil

        do {
            if itemType == .event {
                try eventKit.createEvent(
                    title:    trimmed,
                    start:    startDate,
                    duration: duration,
                    calendar: selectedCalendar,
                    notes:    notes.isEmpty ? nil : notes
                )
            } else {
                try eventKit.createReminder(
                    title:    trimmed,
                    dueDate:  startDate,
                    calendar: selectedCalendar,
                    notes:    notes.isEmpty ? nil : notes
                )
            }
            // Refresh cache
            eventKit.fetchEvents(for: startDate)
            Task { await eventKit.fetchReminders() }
            // 패널 플래시 피드백 알림
            NotificationCenter.default.post(
                name: .noCalItemAdded,
                object: itemType == .event ? "event" : "reminder"
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving   = false
        }
    }
}
