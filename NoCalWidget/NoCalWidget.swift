/// NoCalWidget.swift
/// Phase 4: nocal 위젯 3종 — 타임라인 / 할일 / 최근 노트.
///
/// NoCalWidgetBundle.swift에서 등록됩니다.
/// NoCalWidgetViews.swift에 각 위젯의 View가 정의됩니다.

import WidgetKit
import SwiftUI
import EventKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - App Group
// ─────────────────────────────────────────────────────────────────────────────

let noCalAppGroup = "group.com.bear3745.nocal"

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared Data Types
// ─────────────────────────────────────────────────────────────────────────────

struct WidgetEvent: Identifiable, Codable {
    let id:        String
    let title:     String
    let startDate: Date
    let endDate:   Date
    let colorHex:  String

    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: startDate)) ~ \(fmt.string(from: endDate))"
    }

    var isNow: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }
}

struct WidgetTodo: Identifiable, Codable {
    let id:     String
    let title:  String
    var isDone: Bool
}

struct WidgetNote: Identifiable, Codable {
    let id:         String
    let title:      String
    let preview:    String
    let modifiedAt: Date
    let isPinned:   Bool
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 1. Timeline Widget
// ─────────────────────────────────────────────────────────────────────────────

struct NoCalTimelineEntry: WidgetKit.TimelineEntry {
    let date:      Date
    let events:    [WidgetEvent]
    let todayNote: String?
}

struct NoCalTimelineProvider: WidgetKit.TimelineProvider {
    typealias Entry = NoCalTimelineEntry

    func placeholder(in context: Context) -> NoCalTimelineEntry {
        NoCalTimelineEntry(date: Date(), events: WidgetEvent.samples, todayNote: "오늘 하루 화이팅!")
    }

    func getSnapshot(in context: Context, completion: @escaping (NoCalTimelineEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoCalTimelineEntry>) -> Void) {
        let events   = fetchTodayEKEvents()
        let preview  = UserDefaults(suiteName: noCalAppGroup)?.string(forKey: "todayNotePreview")
        let entry    = NoCalTimelineEntry(date: Date(), events: events, todayNote: preview)
        let nextDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextDate)))
    }

    private func fetchTodayEKEvents() -> [WidgetEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let store = EKEventStore()
        let cal   = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: pred).prefix(5).map { ev in
            WidgetEvent(
                id:        ev.eventIdentifier ?? UUID().uuidString,
                title:     ev.title ?? "(제목 없음)",
                startDate: ev.startDate,
                endDate:   ev.endDate,
                colorHex:  cgColorToHex(ev.calendar.cgColor)
            )
        }
    }

    private func cgColorToHex(_ cgColor: CGColor?) -> String {
        guard let c = cgColor?.components, c.count >= 3 else { return "#5856D6" }
        return String(format: "#%02X%02X%02X", Int(c[0]*255), Int(c[1]*255), Int(c[2]*255))
    }
}

struct NoCalTimelineWidget: Widget {
    let kind = "NoCalTimelineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoCalTimelineProvider()) { entry in
            TimelineWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("오늘 일정")
        .description("오늘의 캘린더 일정을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryInline, .accessoryRectangular])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 2. Todo Widget
// ─────────────────────────────────────────────────────────────────────────────

struct TodoEntry: TimelineEntry {
    let date:  Date
    let todos: [WidgetTodo]
    var total: Int { todos.count }
    var done:  Int { todos.filter(\.isDone).count }
}

struct TodoProvider: TimelineProvider {
    typealias Entry = TodoEntry

    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), todos: WidgetTodo.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let data  = UserDefaults(suiteName: noCalAppGroup)?.data(forKey: "todayTodos") ?? Data()
        let todos = (try? JSONDecoder().decode([WidgetTodo].self, from: data)) ?? []
        let entry = TodoEntry(date: Date(), todos: todos)
        let next  = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct NoCalTodoWidget: Widget {
    let kind = "NoCalTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("오늘 할 일")
        .description("체크리스트 진행률을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Notes Widget
// ─────────────────────────────────────────────────────────────────────────────

struct NotesEntry: TimelineEntry {
    let date:  Date
    let notes: [WidgetNote]
}

struct NotesProvider: TimelineProvider {
    typealias Entry = NotesEntry

    func placeholder(in context: Context) -> NotesEntry {
        NotesEntry(date: Date(), notes: WidgetNote.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
        let data  = UserDefaults(suiteName: noCalAppGroup)?.data(forKey: "recentNotes") ?? Data()
        let notes = (try? JSONDecoder().decode([WidgetNote].self, from: data)) ?? []
        let entry = NotesEntry(date: Date(), notes: notes)
        let next  = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct NoCalNotesWidget: Widget {
    let kind = "NoCalNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotesProvider()) { entry in
            NotesWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("최근 노트")
        .description("최근에 수정한 노트를 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sample Data
// ─────────────────────────────────────────────────────────────────────────────

extension WidgetEvent {
    static var samples: [WidgetEvent] {
        let cal = Calendar.current
        return [
            WidgetEvent(id: "1", title: "팀 스탠드업",
                        startDate: cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!,
                        endDate:   cal.date(bySettingHour: 10, minute: 30, second: 0, of: Date())!,
                        colorHex: "#5856D6"),
            WidgetEvent(id: "2", title: "점심 약속",
                        startDate: cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!,
                        endDate:   cal.date(bySettingHour: 13, minute: 0, second: 0, of: Date())!,
                        colorHex: "#FF9500"),
            WidgetEvent(id: "3", title: "주간 리뷰",
                        startDate: cal.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                        endDate:   cal.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!,
                        colorHex: "#34C759"),
        ]
    }
}

extension WidgetTodo {
    static var samples: [WidgetTodo] {[
        WidgetTodo(id: "1", title: "Xcode 프로젝트 빌드", isDone: true),
        WidgetTodo(id: "2", title: "UI 디자인 검토",      isDone: true),
        WidgetTodo(id: "3", title: "API 연동 테스트",     isDone: false),
        WidgetTodo(id: "4", title: "코드 리뷰",           isDone: false),
        WidgetTodo(id: "5", title: "배포 준비",            isDone: false),
    ]}
}

extension WidgetNote {
    static var samples: [WidgetNote] {[
        WidgetNote(id: "1", title: "오늘의 아이디어",  preview: "SwiftUI 애니메이션 개선 방향...", modifiedAt: Date(), isPinned: true),
        WidgetNote(id: "2", title: "주간 목표",        preview: "이번 주 핵심 목표 3가지",         modifiedAt: Date().addingTimeInterval(-3600), isPinned: false),
        WidgetNote(id: "3", title: "회의록 2026-03", preview: "팀 스탠드업 내용 정리",            modifiedAt: Date().addingTimeInterval(-7200), isPinned: false),
    ]}
}
