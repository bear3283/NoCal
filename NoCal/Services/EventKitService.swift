/// EventKitService.swift
/// Phase 3: @Observable wrapper around EventKit.
/// Handles Calendar (EKEvent) and Reminders (EKReminder) read/write.
///
/// ⚠️ SETUP REQUIRED — Xcode Target › Info 탭에 아래 키 추가:
///   NSCalendarsFullAccessUsageDescription  "nocal이 캘린더를 읽고 씁니다"
///   NSRemindersFullAccessUsageDescription  "nocal이 미리알림을 읽고 씁니다"
/// macOS Sandbox › Entitlements에 추가:
///   com.apple.security.personal-information.calendars
///   com.apple.security.personal-information.reminders

import EventKit
import Foundation
import SwiftData
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EventKitService
// ─────────────────────────────────────────────────────────────────────────────
@Observable
final class EventKitService {

    static let shared = EventKitService()

    private let store = EKEventStore()

    // Auth status
    var calendarStatus:  EKAuthorizationStatus = .notDetermined
    var remindersStatus: EKAuthorizationStatus = .notDetermined

    var hasCalendarAccess:  Bool { calendarStatus  == .fullAccess }
    var hasRemindersAccess: Bool { remindersStatus == .fullAccess }
    var hasAnyAccess: Bool { hasCalendarAccess || hasRemindersAccess }

    // Cached data (updated after each fetch)
    var todayEvents:       [EKEvent]    = []
    var incompleteReminders: [EKReminder] = []

    private init() {
        calendarStatus  = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)

        // Listen for external changes (Calendar / Reminders app edits)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Permissions
    // ─────────────────────────────────────────────────────────────────────
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run { calendarStatus = granted ? .fullAccess : .denied }
            return granted
        } catch {
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToReminders()
            await MainActor.run { remindersStatus = granted ? .fullAccess : .denied }
            return granted
        } catch {
            return false
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Fetch
    // ─────────────────────────────────────────────────────────────────────

    /// Fetch and cache events for a given day.
    func fetchEvents(for date: Date) {
        guard hasCalendarAccess else { todayEvents = []; return }
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        todayEvents = store.events(matching: pred)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    /// All-day events for a given day.
    func allDayEvents(for date: Date) -> [EKEvent] {
        guard hasCalendarAccess else { return [] }
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred).filter { $0.isAllDay }
    }

    /// Fetch and cache incomplete reminders.
    func fetchReminders() async {
        guard hasRemindersAccess else { incompleteReminders = []; return }
        let pred = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )
        let results: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: pred) { cont.resume(returning: $0 ?? []) }
        }
        await MainActor.run {
            incompleteReminders = results.sorted {
                let d0 = $0.dueDateComponents?.date ?? .distantFuture
                let d1 = $1.dueDateComponents?.date ?? .distantFuture
                return d0 < d1
            }
        }
    }

    /// Refresh both events and reminders.
    func refresh(for date: Date) async {
        fetchEvents(for: date)
        await fetchReminders()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Available Calendars / Lists
    // ─────────────────────────────────────────────────────────────────────

    /// 사용 가능한 캘린더(이벤트용) 또는 미리알림 목록을 반환합니다.
    func availableCalendars(for type: EKEntityType) -> [EKCalendar] {
        switch type {
        case .event:    return store.calendars(for: .event).sorted { $0.title < $1.title }
        case .reminder: return store.calendars(for: .reminder).sorted { $0.title < $1.title }
        @unknown default: return []
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Create
    // ─────────────────────────────────────────────────────────────────────
    @discardableResult
    func createEvent(
        title:    String,
        start:    Date,
        duration: TimeInterval = 3600,
        isAllDay: Bool         = false,
        calendar: EKCalendar?  = nil,
        notes:    String?      = nil
    ) throws -> EKEvent {
        guard hasCalendarAccess else { throw EKError.accessDenied }
        let event        = EKEvent(eventStore: store)
        event.title      = title
        event.startDate  = start
        event.endDate    = isAllDay ? start : start.addingTimeInterval(duration)
        event.isAllDay   = isAllDay
        event.notes      = notes
        event.calendar   = calendar ?? store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent, commit: true)
        return event
    }

    @discardableResult
    func createReminder(
        title:    String,
        dueDate:  Date?        = nil,
        priority: Int          = 0,
        calendar: EKCalendar?  = nil,
        notes:    String?      = nil
    ) throws -> EKReminder {
        guard hasRemindersAccess else { throw EKError.accessDenied }
        let reminder        = EKReminder(eventStore: store)
        reminder.title      = title
        reminder.notes      = notes
        reminder.priority   = priority
        reminder.calendar   = calendar ?? store.defaultCalendarForNewReminders()
        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current
                .dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }
        try store.save(reminder, commit: true)
        return reminder
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Update (편집)
    // ─────────────────────────────────────────────────────────────────────

    /// 기존 EKEvent를 수정합니다.
    func updateEvent(
        _ event:  EKEvent,
        title:    String,
        start:    Date,
        end:      Date,
        isAllDay: Bool        = false,
        calendar: EKCalendar? = nil,
        notes:    String?     = nil
    ) throws {
        guard hasCalendarAccess else { throw EKError.accessDenied }
        event.title     = title
        event.startDate = start
        event.endDate   = end
        event.isAllDay  = isAllDay
        event.notes     = notes
        if let cal = calendar { event.calendar = cal }
        try store.save(event, span: .thisEvent, commit: true)
        fetchEvents(for: start)
    }

    /// 기존 EKReminder를 수정합니다.
    func updateReminder(
        _ reminder: EKReminder,
        title:    String,
        dueDate:  Date?,
        priority: Int         = 0,
        calendar: EKCalendar? = nil,
        notes:    String?     = nil
    ) throws {
        guard hasRemindersAccess else { throw EKError.accessDenied }
        reminder.title    = title
        reminder.priority = priority
        reminder.notes    = notes
        if let cal = calendar { reminder.calendar = cal }
        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current
                .dateComponents([.year, .month, .day, .hour, .minute], from: due)
        } else {
            reminder.dueDateComponents = nil
        }
        try store.save(reminder, commit: true)
        Task { await fetchReminders() }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Mutate
    // ─────────────────────────────────────────────────────────────────────
    func toggleReminder(_ reminder: EKReminder) throws {
        reminder.isCompleted = !reminder.isCompleted
        try store.save(reminder, commit: true)
        Task { await fetchReminders() }
    }

    func deleteEvent(_ event: EKEvent) throws {
        try store.remove(event, span: .thisEvent, commit: true)
        todayEvents.removeAll { $0.eventIdentifier == event.eventIdentifier }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Bidirectional Sync — TimedTask ↔ EKReminder
    // ─────────────────────────────────────────────────────────────────────

    /// TimedTask 생성 시 호출 → 대응하는 EKReminder를 생성하고 identifier 반환.
    /// 권한 없거나 저장 실패 시 nil 반환.
    @discardableResult
    func registerReminder(for task: TimedTask) -> String? {
        guard hasRemindersAccess else { return nil }
        let reminder        = EKReminder(eventStore: store)
        reminder.title      = task.title
        reminder.calendar   = store.defaultCalendarForNewReminders()
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: task.startDate
        )
        if !task.notes.isEmpty { reminder.notes = task.notes }
        do {
            try store.save(reminder, commit: true)
            Task { await fetchReminders() }
            return reminder.calendarItemIdentifier
        } catch {
            return nil
        }
    }

    /// TimedTask 완료 상태 변경 시 호출 → 연결된 EKReminder 완료 상태 동기화.
    func syncCompletion(ekReminderID: String, isCompleted: Bool) {
        guard hasRemindersAccess,
              let item = store.calendarItem(withIdentifier: ekReminderID) as? EKReminder
        else { return }
        guard item.isCompleted != isCompleted else { return }
        item.isCompleted = isCompleted
        try? store.save(item, commit: true)
        Task { await fetchReminders() }
    }

    /// TimedTask 삭제 시 호출 → 연결된 EKReminder 삭제.
    func deleteReminder(ekReminderID: String) {
        guard hasRemindersAccess,
              let item = store.calendarItem(withIdentifier: ekReminderID) as? EKReminder
        else { return }
        try? store.remove(item, commit: true)
        Task { await fetchReminders() }
    }

    /// EKEventStore 변경 감지 후 호출 → EKReminder 완료 상태를 TimedTask에 반영.
    /// TimedTask 목록과 ModelContext를 받아 SwiftData 업데이트.
    func syncRemindersToTimedTasks(_ tasks: [TimedTask], context: ModelContext) {
        guard hasRemindersAccess else { return }
        var changed = false
        for task in tasks {
            guard let id   = task.ekReminderID,
                  let item = store.calendarItem(withIdentifier: id) as? EKReminder
            else { continue }
            if task.isCompleted != item.isCompleted {
                task.isCompleted = item.isCompleted
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: External Change
    // ─────────────────────────────────────────────────────────────────────
    @objc private func storeChanged(_ notification: Notification) {
        // EKEventStore 외부 변경 (캘린더/미리알림 앱 편집 등)
        // → noCalEKStoreChanged 알림 발송 → TimelineView가 수신 후 동기화
        NotificationCenter.default.post(name: .noCalEKStoreChanged, object: nil)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Notification Name
// ─────────────────────────────────────────────────────────────────────────────
extension Notification.Name {
    static let noCalEKStoreChanged = Notification.Name("noCalEKStoreChanged")
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EKError shim
// ─────────────────────────────────────────────────────────────────────────────
enum EKError: LocalizedError {
    case accessDenied
    var errorDescription: String? {
        "캘린더 또는 미리알림 접근 권한이 없습니다. 설정 앱에서 권한을 허용해주세요."
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EKEvent Helpers
// ─────────────────────────────────────────────────────────────────────────────
extension EKEvent {
    /// SwiftUI Color from the EKCalendar's CGColor.
    var calendarColor: Color { Color(cgColor: calendar.cgColor) }

    /// Duration in minutes (clamped to 1 min minimum).
    var durationMinutes: CGFloat {
        max(1, CGFloat(endDate.timeIntervalSince(startDate) / 60))
    }

    /// Minutes elapsed from midnight on the start day.
    var startMinuteOfDay: CGFloat {
        let c = Calendar.current
        return CGFloat(c.component(.hour, from: startDate) * 60
                     + c.component(.minute, from: startDate))
    }

    var timeRangeString: String {
        "\(Self.timeFmt.string(from: startDate))–\(Self.timeFmt.string(from: endDate))"
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EKReminder Helpers
// ─────────────────────────────────────────────────────────────────────────────
extension EKReminder {
    var dueDate: Date? { dueDateComponents?.date }

    var isOverdue: Bool {
        guard let d = dueDate else { return false }
        return d < Date() && !isCompleted
    }
}

// DateComponents → Date helper
private extension DateComponents {
    var date: Date? { Calendar.current.date(from: self) }
}
