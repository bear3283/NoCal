/// NoCalIntents.swift
/// Phase 4: App Intents + Siri 지원
///   • CreateNoteIntent   — "nocal에 [내용] 메모해줘"
///   • OpenTodayIntent    — "오늘 nocal 열어줘"
///   • SearchNotesIntent  — "nocal에서 [키워드] 검색해줘"
///   • AddToTimelineIntent — "nocal에서 [제목] 타임라인에 추가해줘"
///
/// ⚠️ Xcode 설정:
///   Target › General › Supported Destinations 에 이 파일 포함
///   (별도 Extension 불필요 — 메인 앱 타겟에 직접 추가)

import AppIntents
import SwiftData
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - App Shortcuts Provider
// ─────────────────────────────────────────────────────────────────────────────

struct NoCalAppShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "\(.applicationName)에 메모 만들어줘",
                "\(.applicationName)에서 새 노트 만들기",
                "Create a note in \(.applicationName)",
                "New note in \(.applicationName)"
            ],
            shortTitle: "새 노트",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "오늘 \(.applicationName) 열어줘",
                "\(.applicationName) 오늘 일일 노트",
                "Open today's note in \(.applicationName)",
                "\(.applicationName) 오늘"
            ],
            shortTitle: "오늘 노트 열기",
            systemImageName: "sun.max"
        )

        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "\(.applicationName)에서 노트 검색하기",
                "Search notes in \(.applicationName)",
                "\(.applicationName) 노트 찾아줘"
            ],
            shortTitle: "노트 검색",
            systemImageName: "magnifyingglass"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .blue }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Create Note Intent
// ─────────────────────────────────────────────────────────────────────────────

struct CreateNoteIntent: AppIntent {

    static var title: LocalizedStringResource = "새 노트 만들기"
    static var description = IntentDescription("nocal에 새 노트를 만듭니다.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "제목", description: "새 노트의 제목")
    var title: String

    @Parameter(title: "내용", description: "노트 본문 (선택)", default: "")
    var body: String

    static var parameterSummary: some ParameterSummary {
        Summary("'\(\.$title)' 노트 만들기") {
            \.$body
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Note.self, Folder.self, TimedTask.self)
        let context = ModelContext(container)

        let note = Note(title: title, content: body.isEmpty ? "" : body)
        context.insert(note)
        try context.save()

        return .result(dialog: "'\(title)' 노트를 만들었습니다.")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Open Today Intent
// ─────────────────────────────────────────────────────────────────────────────

struct OpenTodayIntent: AppIntent {

    static var title: LocalizedStringResource = "오늘 노트 열기"
    static var description = IntentDescription("오늘의 일일 노트를 엽니다.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // App will open to today via deep link / URL
        return .result(dialog: "오늘의 노트를 열었습니다.")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Search Notes Intent
// ─────────────────────────────────────────────────────────────────────────────

struct SearchNotesIntent: AppIntent {

    static var title: LocalizedStringResource = "노트 검색"
    static var description = IntentDescription("키워드로 노트를 검색합니다.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "검색어", description: "찾을 키워드")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("'\(\.$query)' 검색하기")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteEntity]> & ProvidesDialog {
        let container = try ModelContainer(for: Note.self, Folder.self, TimedTask.self)
        let context = ModelContext(container)

        let lower = query.lowercased()
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.title.localizedStandardContains(lower) ||
                note.content.localizedStandardContains(lower)
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        let notes = (try? context.fetch(descriptor)) ?? []
        let entities = notes.prefix(5).map { NoteEntity(note: $0) }

        let dialog: IntentDialog = notes.isEmpty
            ? "'\(query)'에 대한 노트를 찾지 못했습니다."
            : "'\(query)' 검색 결과 \(notes.count)개를 찾았습니다."

        return .result(value: Array(entities), dialog: dialog)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Note Entity (for Siri results)
// ─────────────────────────────────────────────────────────────────────────────

struct NoteEntity: AppEntity {

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "노트"

    static var defaultQuery = NoteEntityQuery()

    var id: UUID
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(preview)"
        )
    }

    var title:   String
    var preview: String
    var modifiedAt: Date

    init(note: Note) {
        self.id         = note.id
        self.title      = note.displayTitle
        self.preview    = note.preview
        self.modifiedAt = note.modifiedAt
    }
}

struct NoteEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        let container = try ModelContainer(for: Note.self, Folder.self, TimedTask.self)
        let context   = ModelContext(container)
        return identifiers.compactMap { id in
            let desc = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
            return (try? context.fetch(desc).first).map { NoteEntity(note: $0) }
        }
    }

    func suggestedEntities() async throws -> [NoteEntity] {
        let container = try ModelContainer(for: Note.self, Folder.self, TimedTask.self)
        let context   = ModelContext(container)
        var desc = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)])
        desc.fetchLimit = 5
        return ((try? context.fetch(desc)) ?? []).map { NoteEntity(note: $0) }
    }
}
