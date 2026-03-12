/// CalendarPanelView.swift
/// 대시보드 좌측 상단 패널: 미니 캘린더 + 선택한 날의 일정

import SwiftUI
import SwiftData
import EventKit

struct CalendarPanelView: View {

    @Environment(AppViewModel.self) private var appViewModel
    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]

    @State private var showNewEvent     = false
    @State private var editableEvent:   IdentifiableEvent?
    @State private var headerFlash      = false

    private var noteDates: Set<Date> {
        Set(allNotes.compactMap { $0.dailyDate })
    }
    private var reminderDates: Set<Date> {
        Set(EventKitService.shared.incompleteReminders.compactMap { $0.dueDate })
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    MiniCalendarView(
                        selectedDate: Binding(
                            get: { appViewModel.selectedDate },
                            set: { appViewModel.selectedDate = $0 }
                        ),
                        noteDates: noteDates,
                        reminderDates: reminderDates
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                    if EventKitService.shared.hasCalendarAccess {
                        Divider().padding(.horizontal, 12)
                        dayEventsSection
                    }
                }
            }
        }
        .sheet(isPresented: $showNewEvent, onDismiss: {
            EventKitService.shared.fetchEvents(for: appViewModel.selectedDate)
        }) {
            NewEventSheet(
                presetHour: Calendar.current.component(.hour, from: Date()),
                presetDate: appViewModel.selectedDate
            )
        }
        .sheet(item: $editableEvent, onDismiss: {
            EventKitService.shared.fetchEvents(for: appViewModel.selectedDate)
        }) { wrapper in
            EditEventSheet(event: wrapper.event)
        }
        .onChange(of: appViewModel.selectedDate) { _, date in
            Task { await EventKitService.shared.refresh(for: date) }
        }
        .task { await EventKitService.shared.refresh(for: appViewModel.selectedDate) }
        .onReceive(NotificationCenter.default.publisher(for: .noCalItemAdded)) { notif in
            guard notif.object as? String == "event" else { return }
            flashHeader()
        }
    }

    private func flashHeader() {
        withAnimation(.easeIn(duration: 0.15)) { headerFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) { headerFlash = false }
        }
    }

    // MARK: - Header
    private var panelHeader: some View {
        HStack {
            Text("캘린더")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button { showNewEvent = true } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("새 일정 추가")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            headerFlash
                ? Color.green.opacity(0.18)
                : Color.clear
        )
        .background(.ultraThinMaterial)
    }

    // MARK: - Day Events
    @ViewBuilder
    private var dayEventsSection: some View {
        let events = EventKitService.shared.todayEvents
        if events.isEmpty {
            Text("일정 없음")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(events, id: \.eventIdentifier) { event in
                    CalendarPanelEventRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture { editableEvent = IdentifiableEvent(event) }
                    Divider().padding(.leading, 24)
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Event Row

private struct CalendarPanelEventRow: View {
    let event: EKEvent

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 3)
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "일정")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if event.isAllDay {
                    Text("종일")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Self.timeFmt.string(from: event.startDate)) – \(Self.timeFmt.string(from: event.endDate))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
