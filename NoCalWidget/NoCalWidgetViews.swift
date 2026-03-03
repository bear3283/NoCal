/// NoCalWidgetViews.swift
/// Phase 4: 위젯 UI — 타임라인 / 할일 / 노트 3종 SwiftUI 뷰.

import WidgetKit
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Brand Color
// ─────────────────────────────────────────────────────────────────────────────

private let accent = Color.indigo

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 1. Timeline Widget Views
// ─────────────────────────────────────────────────────────────────────────────

struct TimelineWidgetView: View {
    var entry: NoCalTimelineEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:      timelineInline
        case .accessoryRectangular: timelineRectangular
        case .systemSmall:          timelineSmall
        default:                    timelineMedium
        }
    }

    // ── Accessory Inline ─────────────────────────────────────────────────
    private var timelineInline: some View {
        if let next = entry.events.filter({ $0.startDate > Date() }).first {
            Label("\(next.title) \(next.timeString)", systemImage: "calendar")
        } else {
            Label("일정 없음", systemImage: "calendar")
        }
    }

    // ── Accessory Rectangular ────────────────────────────────────────────
    private var timelineRectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("오늘 일정", systemImage: "calendar")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)

            ForEach(entry.events.prefix(3)) { ev in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: ev.colorHex))
                        .frame(width: 6, height: 6)
                    Text(ev.title)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Text(DateFormatter.hourMin.string(from: ev.startDate))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            if entry.events.isEmpty {
                Text("오늘 일정이 없습니다")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ── System Small ─────────────────────────────────────────────────────
    private var timelineSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text(Date(), format: .dateTime.month().day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(Date(), format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if entry.events.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                    Text("일정 없음")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(entry.events.prefix(3)) { ev in
                    EventRow(event: ev, compact: true)
                }
            }
        }
        .padding(12)
    }

    // ── System Medium / Large ─────────────────────────────────────────────
    private var timelineMedium: some View {
        HStack(spacing: 0) {
            // Left: date + event count
            VStack(spacing: 4) {
                Text(Date(), format: .dateTime.day())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                Text(Date(), format: .dateTime.month(.abbreviated))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.events.count)개")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 54)
            .padding(.vertical, 12)

            Divider().padding(.vertical, 8)

            // Right: event list
            VStack(alignment: .leading, spacing: 6) {
                if entry.events.isEmpty {
                    HStack {
                        Spacer()
                        Text("오늘 일정이 없습니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    ForEach(entry.events.prefix(4)) { ev in
                        EventRow(event: ev, compact: false)
                    }
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

// ── Event Row ────────────────────────────────────────────────────────────────
private struct EventRow: View {
    let event:   WidgetEvent
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.colorHex))
                .frame(width: 3, height: compact ? 28 : 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(event.isNow ? .primary : .secondary)
                if !compact {
                    Text(event.timeString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if event.isNow {
                Spacer()
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 2. Todo Widget Views
// ─────────────────────────────────────────────────────────────────────────────

struct TodoWidgetView: View {
    var entry: TodoEntry
    @Environment(\.widgetFamily) var family

    private var progress: Double {
        entry.total > 0 ? Double(entry.done) / Double(entry.total) : 0
    }

    var body: some View {
        switch family {
        case .accessoryCircular:    todoCircular
        case .accessoryRectangular: todoRectangular
        case .systemSmall:          todoSmall
        default:                    todoMedium
        }
    }

    // ── Accessory Circular ───────────────────────────────────────────────
    private var todoCircular: some View {
        Gauge(value: progress) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text("\(entry.done)")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(accent)
    }

    // ── Accessory Rectangular ────────────────────────────────────────────
    private var todoRectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("할 일 \(entry.done)/\(entry.total)", systemImage: "checklist")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)

            ProgressView(value: progress)
                .tint(accent)

            ForEach(entry.todos.filter { !$0.isDone }.prefix(2)) { todo in
                Label(todo.title, systemImage: "circle")
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }

    // ── System Small ─────────────────────────────────────────────────────
    private var todoSmall: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(accent)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(entry.done)/\(entry.total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
            }

            ProgressView(value: progress)
                .tint(accent)

            Spacer()

            ForEach(entry.todos.prefix(4)) { todo in
                TodoRow(todo: todo)
            }
        }
        .padding(12)
    }

    // ── System Medium ────────────────────────────────────────────────────
    private var todoMedium: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: progress ring
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                    }
                }
                .frame(width: 54, height: 54)

                Text("\(entry.done)/\(entry.total) 완료")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider().padding(.vertical, 8)

            // Right: todo list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.todos.prefix(5)) { todo in
                    TodoRow(todo: todo)
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

private struct TodoRow: View {
    let todo: WidgetTodo

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundStyle(todo.isDone ? Color.green : Color.secondary)
            Text(todo.title)
                .font(.caption)
                .foregroundStyle(todo.isDone ? .tertiary : .primary)
                .strikethrough(todo.isDone, color: Color.secondary)
                .lineLimit(1)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Notes Widget Views
// ─────────────────────────────────────────────────────────────────────────────

struct NotesWidgetView: View {
    var entry: NotesEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  notesSmall
        case .systemLarge:  notesLarge
        default:            notesMedium
        }
    }

    // ── System Small ─────────────────────────────────────────────────────
    private var notesSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("최근 노트", systemImage: "note.text")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)

            Divider()

            ForEach(entry.notes.prefix(3)) { note in
                NoteSnippet(note: note)
            }
            Spacer()
        }
        .padding(12)
    }

    // ── System Medium ────────────────────────────────────────────────────
    private var notesMedium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("최근 노트", systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(Date(), format: .dateTime.month().day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Divider()
            ForEach(entry.notes.prefix(3)) { note in
                NoteSnippet(note: note)
            }
        }
        .padding(12)
    }

    // ── System Large ─────────────────────────────────────────────────────
    private var notesLarge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("최근 노트", systemImage: "note.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(Date(), format: .dateTime.month().day().weekday())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            ForEach(entry.notes.prefix(6)) { note in
                NoteSnippet(note: note, showPreview: true)
                if note.id != entry.notes.prefix(6).last?.id { Divider() }
            }
            Spacer()
        }
        .padding(14)
    }
}

private struct NoteSnippet: View {
    let note:        WidgetNote
    var showPreview: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(accent)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                if showPreview {
                    Text(note.preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(note.modifiedAt, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Helpers
// ─────────────────────────────────────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int   = UInt64(0)
        Scanner(string: clean).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >>  8) / 255
        let b = Double( int & 0x0000FF       ) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

extension DateFormatter {
    static let hourMin: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Previews
// ─────────────────────────────────────────────────────────────────────────────

#Preview("Timeline Small", as: .systemSmall) {
    NoCalTimelineWidget()
} timeline: {
    NoCalTimelineEntry(date: .now, events: WidgetEvent.samples, todayNote: "오늘도 화이팅!")
}

#Preview("Todo Medium", as: .systemMedium) {
    NoCalTodoWidget()
} timeline: {
    TodoEntry(date: .now, todos: WidgetTodo.samples)
}

#Preview("Notes Large", as: .systemLarge) {
    NoCalNotesWidget()
} timeline: {
    NotesEntry(date: .now, notes: WidgetNote.samples)
}
