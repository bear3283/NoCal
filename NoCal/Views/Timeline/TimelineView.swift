/// TimelineView.swift
/// Phase 3: Full timeline implementation.
///   • 24h scrollable canvas with pixel-accurate event positioning
///   • Solid blocks  → Apple Calendar EKEvents
///   • Outline blocks → nocal TimedTasks
///   • Current-time red indicator line
///   • Reminders panel (swipe to complete)
///   • All-day event chips
///   • Tap empty hour → NewEventSheet
///   • macOS: Drop note onto hour → creates TimedTask
///   • iOS: Swipe "Add to Timeline" on note to schedule

import SwiftUI
import SwiftData
import EventKit
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Layout Constants
// ─────────────────────────────────────────────────────────────────────────────
private enum TL {
    static let timeColW:  CGFloat = 50    // left time label column
    static let pph:       CGFloat = 64    // points per hour
    static let ppm:       CGFloat = pph / 60
    static let totalH:    CGFloat = 24 * pph
    static let minBlockH: CGFloat = 28    // minimum event block height
    static let eventFrac: CGFloat = 0.55  // fraction of available width for EKEvents
    static let taskFrac:  CGFloat = 0.40  // fraction for TimedTasks
    static let gap:       CGFloat = 6
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - TimelineView
// ─────────────────────────────────────────────────────────────────────────────
struct TimelineView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appViewModel

    @Query(sort: \TimedTask.startDate) private var allTimedTasks: [TimedTask]

    private let eventKit = EventKitService.shared

    // Sheet & interaction state
    @State private var showNewEvent  = false
    @State private var showReminders = false
    @State private var tappedHour   = 9
    @State private var currentTime  = Date()
    @State private var dropTargetHour: Int? = nil

    // 편집 시트 — EKEvent / EKReminder는 Identifiable이 아니므로 래퍼 사용
    @State private var editableEvent:    IdentifiableEvent?
    @State private var editableReminder: IdentifiableReminder?

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Filter TimedTasks for the selected date
    var dayTimedTasks: [TimedTask] {
        let cal = Calendar.current
        return allTimedTasks.filter {
            cal.isDate($0.startDate, inSameDayAs: appViewModel.selectedDate)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        Group {
            if !eventKit.hasAnyAccess {
                EventPermissionView()
            } else {
                timelineBody
            }
        }
        // Refresh when date changes
        .onChange(of: appViewModel.selectedDate) { _, date in
            Task { await eventKit.refresh(for: date) }
        }
        .task { await eventKit.refresh(for: appViewModel.selectedDate) }
        .onReceive(refreshTimer) { t in
            currentTime = t
            eventKit.fetchEvents(for: appViewModel.selectedDate)
        }
        // 외부 변경 감지 (캘린더/미리알림 앱에서 편집 시) → EKReminder → TimedTask 완료 상태 동기화
        .onReceive(NotificationCenter.default.publisher(for: .noCalEKStoreChanged)) { _ in
            Task {
                await eventKit.refresh(for: appViewModel.selectedDate)
                await MainActor.run {
                    eventKit.syncRemindersToTimedTasks(dayTimedTasks, context: modelContext)
                }
            }
        }
        .sheet(isPresented: $showNewEvent, onDismiss: {
            eventKit.fetchEvents(for: appViewModel.selectedDate)
        }) {
            NewEventSheet(
                presetHour: tappedHour,
                presetDate: appViewModel.selectedDate
            )
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        // 일정 편집 시트
        .sheet(item: $editableEvent, onDismiss: {
            eventKit.fetchEvents(for: appViewModel.selectedDate)
        }) { wrapper in
            EditEventSheet(event: wrapper.event)
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        // 미리알림 편집 시트
        .sheet(item: $editableReminder, onDismiss: {
            Task { await eventKit.fetchReminders() }
        }) { wrapper in
            EditReminderSheet(reminder: wrapper.reminder)
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Main Layout
    // ─────────────────────────────────────────────────────────────────────
    private var timelineBody: some View {
        VStack(spacing: 0) {

            // ── Date header ─────────────────────────────────────────────
            dateHeader

            // ── All-day events strip ────────────────────────────────────
            let allDay = eventKit.allDayEvents(for: appViewModel.selectedDate)
            if !allDay.isEmpty {
                allDayStrip(allDay)
            }

            // ── Reminders panel (collapsible) ───────────────────────────
            if !eventKit.incompleteReminders.isEmpty {
                remindersPanel
            }

            Divider()

            // ── 24h scrollable canvas ───────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    timelineCanvas
                }
                .onAppear { scrollToNow(proxy) }
                .onChange(of: appViewModel.selectedDate) { _, _ in scrollToNow(proxy) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Date Header
    // ─────────────────────────────────────────────────────────────────────
    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(appViewModel.selectedDate, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline.weight(.semibold))
                if Calendar.current.isDateInToday(appViewModel.selectedDate) {
                    Text("오늘")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.noCalAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.noCalAccent.opacity(0.12), in: Capsule())
                }
            }

            Spacer()

            // New event / reminder button
            Button {
                tappedHour = Calendar.current.component(.hour, from: Date())
                showNewEvent = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.noCalAccent)
            }
            .buttonStyle(.plain)
            .help("새 일정 추가")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: All-Day Strip
    // ─────────────────────────────────────────────────────────────────────
    private func allDayStrip(_ events: [EKEvent]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(events, id: \.eventIdentifier) { AllDayEventChip(event: $0) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Reminders Panel
    // ─────────────────────────────────────────────────────────────────────
    private var remindersPanel: some View {
        DisclosureGroup(
            isExpanded: $showReminders,
            content: {
                VStack(spacing: 0) {
                    ForEach(eventKit.incompleteReminders.prefix(5), id: \.calendarItemIdentifier) { reminder in
                        ReminderRow(
                            reminder: reminder,
                            onToggle: { try? eventKit.toggleReminder(reminder) },
                            onEdit:   { editableReminder = IdentifiableReminder(reminder) }
                        )
                        Divider().padding(.leading, 36)
                    }
                    if eventKit.incompleteReminders.count > 5 {
                        Text("+ \(eventKit.incompleteReminders.count - 5)개 더")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 12)
            },
            label: {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.noCalAccent)
                    Text("미완료 미리알림 \(eventKit.incompleteReminders.count)개")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        )
        .background(.ultraThinMaterial)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: 24h Canvas
    // ─────────────────────────────────────────────────────────────────────
    private var timelineCanvas: some View {
        GeometryReader { geo in
            let availW     = geo.size.width - TL.timeColW - TL.gap * 2
            let eventW     = availW * TL.eventFrac
            let taskW      = availW * TL.taskFrac

            ZStack(alignment: .topLeading) {

                // ── Hour grid ────────────────────────────────────────────
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        hourRow(hour: hour, fullWidth: geo.size.width)
                    }
                }

                // ── Apple Calendar events (solid) ────────────────────────
                ForEach(eventKit.todayEvents, id: \.eventIdentifier) { event in
                    let top  = event.startMinuteOfDay * TL.ppm
                    let h    = max(TL.minBlockH, event.durationMinutes * TL.ppm)

                    EKEventBlock(
                        event:    event,
                        onEdit:   { editableEvent = IdentifiableEvent(event) },
                        onDelete: { try? eventKit.deleteEvent(event) }
                    )
                    .frame(width: eventW, height: h)
                    .offset(x: TL.timeColW + TL.gap, y: top)
                }

                // ── nocal TimedTasks (outline) ───────────────────────────
                ForEach(dayTimedTasks) { task in
                    let top = task.startMinuteOfDay * TL.ppm
                    let h   = max(TL.minBlockH, task.durationMinutes * TL.ppm)

                    TimedTaskBlock(task: task, modelContext: modelContext)
                        .frame(width: taskW, height: h)
                        .offset(x: TL.timeColW + TL.gap + eventW + TL.gap, y: top)
                }

                // ── Current time indicator ───────────────────────────────
                if Calendar.current.isDateInToday(appViewModel.selectedDate) {
                    currentTimeIndicator(fullWidth: geo.size.width)
                }
            }
            .frame(height: TL.totalH)
            .frame(maxWidth: .infinity)
        }
        .frame(height: TL.totalH)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Hour Row
    // ─────────────────────────────────────────────────────────────────────
    private func hourRow(hour: Int, fullWidth: CGFloat) -> some View {
        let isCurrent = Calendar.current.isDateInToday(appViewModel.selectedDate)
                     && Calendar.current.component(.hour, from: currentTime) == hour
        let isTarget  = dropTargetHour == hour

        return HStack(spacing: 0) {
            // Time label
            Text(hourLabel(hour))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(isCurrent ? Color.noCalAccent : Color.secondary)
                .frame(width: TL.timeColW, alignment: .trailing)
                .padding(.trailing, TL.gap)

            // Divider line
            Rectangle()
                .fill(isCurrent
                      ? Color.noCalAccent.opacity(0.3)
                      : Color.secondary.opacity(0.12))
                .frame(height: 1)
        }
        .frame(height: TL.pph)
        .background(
            isTarget
                ? Color.noCalAccent.opacity(0.08)
                : (isCurrent ? Color.noCalAccent.opacity(0.04) : .clear)
        )
        .id(hour)
        // Tap → new event sheet
        .contentShape(Rectangle())
        .onTapGesture {
            tappedHour = hour
            showNewEvent = true
        }
        // macOS: drag note → create TimedTask
        .dropDestination(for: String.self) { items, _ in
            guard let uuidStr = items.first,
                  let noteID  = UUID(uuidString: uuidStr)
            else { return false }
            dropNote(noteID: noteID, hour: hour)
            return true
        } isTargeted: { targeted in
            dropTargetHour = targeted ? hour : nil
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Current Time Indicator
    // ─────────────────────────────────────────────────────────────────────
    private func currentTimeIndicator(fullWidth: CGFloat) -> some View {
        let cal    = Calendar.current
        let h      = CGFloat(cal.component(.hour,   from: currentTime))
        let m      = CGFloat(cal.component(.minute, from: currentTime))
        let yPos   = (h * 60 + m) * TL.ppm

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.red)
                .frame(width: fullWidth - TL.timeColW, height: 1.5)
                .offset(x: TL.timeColW)

            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: TL.timeColW - 4)
        }
        .offset(y: yPos)
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────────────────────────────
    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0:  return "자정"
        case 12: return "정오"
        default:
            let h   = hour % 12 == 0 ? 12 : hour % 12
            let sfx = hour < 12 ? "AM" : "PM"
            return "\(h) \(sfx)"
        }
    }

    private func scrollToNow(_ proxy: ScrollViewProxy) {
        let hour = max(0, Calendar.current.component(.hour, from: currentTime) - 2)
        withAnimation(.easeOut(duration: 0.5)) { proxy.scrollTo(hour, anchor: .top) }
    }

    /// Drop handler: create a TimedTask for a note at the specified hour.
    /// EKReminder도 함께 생성하여 양방향 동기화 연결.
    private func dropNote(noteID: UUID, hour: Int) {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == noteID }
        )
        guard let note = try? modelContext.fetch(descriptor).first else { return }

        var comps    = Calendar.current.dateComponents([.year, .month, .day], from: appViewModel.selectedDate)
        comps.hour   = hour
        comps.minute = 0
        let startDate = Calendar.current.date(from: comps) ?? appViewModel.selectedDate

        let task = TimedTask(
            title:      note.displayTitle,
            startDate:  startDate,
            duration:   3600,
            sourceNote: note
        )
        modelContext.insert(task)
        try? modelContext.save()

        // EKReminder 자동 생성 → ID 저장 (양방향 동기화)
        if let reminderID = eventKit.registerReminder(for: task) {
            task.ekReminderID = reminderID
            try? modelContext.save()
        }
    }
}

// IdentifiableEvent / IdentifiableReminder → Views/IdentifiableWrappers.swift
