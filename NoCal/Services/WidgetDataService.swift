/// WidgetDataService.swift
/// Phase 4: 위젯과 데이터를 공유하기 위해 App Group UserDefaults에 스냅샷 저장.
/// 노트/할일 변경 시 호출하면 위젯이 최신 데이터를 표시합니다.
///
/// ⚠️ App Groups 활성화 후 appGroupID를 실제 ID로 변경하세요.
/// ⚠️ WidgetKit import가 필요합니다 (메인 앱 타겟에 WidgetKit.framework 추가).

import Foundation
import WidgetKit

struct WidgetDataService {

    static let shared = WidgetDataService()

    private let appGroupID = "group.com.bear3745.nocal"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Sync
    // ─────────────────────────────────────────────────────────────────────

    /// 노트 목록을 위젯용 캐시로 저장하고 위젯 타임라인을 새로 고칩니다.
    func syncNotes(_ notes: [Note]) {
        let widgets = notes.prefix(6).map { note in
            WidgetNoteSnapshot(
                id:         note.id.uuidString,
                title:      note.displayTitle,
                preview:    note.preview,
                modifiedAt: note.modifiedAt,
                isPinned:   note.isPinned
            )
        }
        if let data = try? JSONEncoder().encode(widgets) {
            defaults?.set(data, forKey: "recentNotes")
        }
        // 오늘 일일 노트 미리보기
        let todayNote = notes.first(where: { $0.isDaily && Calendar.current.isDateInToday($0.modifiedAt) })
        defaults?.set(todayNote?.preview, forKey: "todayNotePreview")
        reloadWidgets()
    }

    /// 오늘 체크리스트 할일을 위젯용 캐시로 저장합니다.
    func syncTodos(from notes: [Note]) {
        var todos: [WidgetTodoSnapshot] = []
        for note in notes {
            let lines = note.content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- [ ]") {
                    let title = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        todos.append(WidgetTodoSnapshot(id: UUID().uuidString, title: title, isDone: false))
                    }
                } else if trimmed.lowercased().hasPrefix("- [x]") {
                    let title = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        todos.append(WidgetTodoSnapshot(id: UUID().uuidString, title: title, isDone: true))
                    }
                }
            }
        }
        if let data = try? JSONEncoder().encode(Array(todos.prefix(10))) {
            defaults?.set(data, forKey: "todayTodos")
        }
        reloadWidgets()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Widget Reload
    // ─────────────────────────────────────────────────────────────────────

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reloadTimelineWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NoCalTimelineWidget")
    }

    func reloadTodoWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NoCalTodoWidget")
    }

    func reloadNotesWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NoCalNotesWidget")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Codable Snapshots (shared with Widget target)
// ─────────────────────────────────────────────────────────────────────────────

struct WidgetNoteSnapshot: Codable {
    let id:         String
    let title:      String
    let preview:    String
    let modifiedAt: Date
    let isPinned:   Bool
}

struct WidgetTodoSnapshot: Codable {
    let id:    String
    let title: String
    let isDone: Bool
}
