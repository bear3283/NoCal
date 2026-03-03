/// NewEventSheet.swift
/// Phase 3: Sheet for creating a new Calendar event or Reminder from within nocal.

import SwiftUI

struct NewEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Preset values passed from timeline tap
    var presetHour: Int  = 9
    var presetDate: Date = Date()

    enum ItemType { case event, reminder }

    @State private var title:     String   = ""
    @State private var itemType:  ItemType = .event
    @State private var startDate: Date     = Date()
    @State private var duration:  TimeInterval = 3600
    @State private var notes:     String   = ""
    @State private var error:     String?  = nil
    @State private var isSaving:  Bool     = false

    private let eventKit = EventKitService.shared

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
                        displayedComponents: itemType == .event
                            ? [.date, .hourAndMinute]
                            : [.date, .hourAndMinute]
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
        var comps    = Calendar.current.dateComponents([.year, .month, .day], from: presetDate)
        comps.hour   = presetHour
        comps.minute = 0
        startDate    = Calendar.current.date(from: comps) ?? presetDate
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
                    notes:    notes.isEmpty ? nil : notes
                )
            } else {
                try eventKit.createReminder(
                    title:   trimmed,
                    dueDate: startDate,
                    notes:   notes.isEmpty ? nil : notes
                )
            }
            // Refresh cache
            eventKit.fetchEvents(for: startDate)
            Task { await eventKit.fetchReminders() }
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving   = false
        }
    }
}
