/// NoteEditorView.swift
/// Phase 4: Template sheet, macOS Commands format notification.

import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NoteEditorView
// ─────────────────────────────────────────────────────────────────────────────
struct NoteEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self)  private var appViewModel

    // Settings (wired to GeneralSettingsTab)
    @AppStorage("editorFontSize") private var editorFontSize: Double = 15
    @AppStorage("autoSaveDelay")  private var autoSaveDelay:  Double = 0.8
    @AppStorage("showWordCount")  private var showWordCount:   Bool   = true

    // Local edit state
    @State private var title:         String = ""
    @State private var content:       String = ""
    @State private var loadedID:      UUID?
    @State private var saveTask:      Task<Void, Never>?
    @State private var showTemplates:    Bool   = false
    @State private var parsedEvents:     [ParsedEvent] = []
    @State private var showEventBanner:  Bool   = false

    var note: Note? { appViewModel.selectedNote }

    // ── Body ──────────────────────────────────────────────────────────────
    var body: some View {
        Group {
            if note != nil {
                editorBody
            } else {
                emptyState
            }
        }
        .onChange(of: note?.id) { _, _ in loadNote() }
        .onAppear { loadNote() }
        .onDisappear { saveTask?.cancel(); saveNote() }
        // macOS Commands → format notification
        .onReceive(NotificationCenter.default.publisher(for: .noCalFormat)) { notif in
            if let action = notif.object as? MarkdownAction {
                insert(action.snippet)
            }
        }
        // Show templates sheet (triggered from menu or toolbar)
        .onReceive(NotificationCenter.default.publisher(for: .noCalShowTemplates)) { _ in
            showTemplates = true
        }
        .sheet(isPresented: $showTemplates) {
            TemplatePickerView { template in
                content = template.resolvedContent
                if title.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = template.resolvedTitle
                }
                scheduleSave()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Editor Body
    // ─────────────────────────────────────────────────────────────────────
    private var editorBody: some View {
        VStack(spacing: 0) {

            // ── Title ───────────────────────────────────────────────────
            TextField("제목", text: $title, axis: .vertical)
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal, NoCalTheme.spacing20)
                .padding(.top, NoCalTheme.spacing20)
                .padding(.bottom, 6)
                .onChange(of: title) { _, _ in scheduleSave() }

            // ── Metadata strip ──────────────────────────────────────────
            metadataStrip

            Divider()
                .padding(.horizontal, NoCalTheme.spacing16)
                .padding(.bottom, NoCalTheme.spacing8)

            // ── Markdown editor ─────────────────────────────────────────
            MarkdownTextEditor(
                text: $content,
                baseFont: editorBaseFont
            )
            .onChange(of: content) { _, _ in scheduleSave() }

            // ── Event Banner ────────────────────────────────────────────
            if showEventBanner && !parsedEvents.isEmpty {
                eventBanner
            }

            // ── Toolbar ─────────────────────────────────────────────────
            markdownToolbar
        }
        .toolbar { editorToolbarItems }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Metadata Strip
    // ─────────────────────────────────────────────────────────────────────
    private var metadataStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NoCalTheme.spacing12) {

                // Modified date
                Label(
                    (note?.modifiedAt ?? Date()).formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                // Folder badge
                if let folder = note?.folder {
                    Divider().frame(height: 12)
                    Label(folder.name, systemImage: folder.icon)
                        .font(.caption)
                        .foregroundStyle(folder.accentColor)
                }

                // Extracted tags
                let tags = MarkdownTag.extract(from: content)
                if !tags.isEmpty {
                    Divider().frame(height: 12)
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundStyle(Color.noCalAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.noCalAccent.opacity(0.1), in: Capsule())
                        }
                    }
                }

                // Char count
                if showWordCount {
                    Spacer()
                    Text("\(content.count) 자")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, NoCalTheme.spacing20)
                }
            }
            .padding(.leading, NoCalTheme.spacing20)
            .padding(.vertical, NoCalTheme.spacing4)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Markdown Quick-Toolbar
    // ─────────────────────────────────────────────────────────────────────
    private var markdownToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Group 1: Inline formatting
                toolbarButton(.bold)
                toolbarButton(.italic)
                toolbarButton(.strikethrough)
                toolbarButton(.highlight)
                toolbarDivider()

                // Group 2: Headings
                toolbarButton(.h1)
                toolbarButton(.h2)
                toolbarButton(.h3)
                toolbarDivider()

                // Group 3: Lists & Structure
                toolbarButton(.checkbox)
                toolbarButton(.bullet)
                toolbarButton(.numbered)
                toolbarButton(.quote)
                toolbarDivider()

                // Group 4: Code
                toolbarButton(.inlineCode)
                toolbarButton(.codeBlock)
                toolbarDivider()

                // Group 5: Extras
                toolbarButton(.link)
                toolbarButton(.divider)
                toolbarButton(.dateInsert)
            }
            .padding(.horizontal, NoCalTheme.spacing8)
        }
        .frame(height: 48)
        .background(.ultraThinMaterial)
    }

    private func toolbarButton(_ action: MarkdownAction) -> some View {
        Button { insert(action.snippet) } label: {
            Image(systemName: action.icon)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 40, height: 40)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toolbarDivider() -> some View {
        Divider()
            .frame(height: 20)
            .padding(.horizontal, 4)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Toolbar Items
    // ─────────────────────────────────────────────────────────────────────
    @ToolbarContentBuilder
    private var editorToolbarItems: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            // Timeline toggle
            Button {
                withAnimation(NoCalTheme.springFast) {
                    appViewModel.showTimeline.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .symbolRenderingMode(.hierarchical)
            }
            .help("타임라인 보기 토글 (⌥⌘T)")
            .keyboardShortcut("t", modifiers: [.command, .option])

            // Favorite toggle
            Button {
                if let note { note.isFavorite.toggle(); saveNote() }
            } label: {
                Image(systemName: note?.isFavorite == true ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(note?.isFavorite == true ? Color.yellow : .secondary)
            }
            .help("즐겨찾기 토글")

            // Pin note
            Button {
                if let note { note.isPinned.toggle(); saveNote() }
            } label: {
                Image(systemName: note?.isPinned == true ? "pin.fill" : "pin")
            }
            .help("노트 고정 (⇧⌘P)")

            // Template picker
            Button {
                showTemplates = true
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .help("템플릿 적용 (⇧⌘T)")
        }
        #else
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showTemplates = true
                } label: {
                    Label("템플릿 적용", systemImage: "doc.badge.plus")
                }

                Button {
                    if let note { note.isFavorite.toggle(); saveNote() }
                } label: {
                    Label(note?.isFavorite == true ? "즐겨찾기 해제" : "즐겨찾기",
                          systemImage: note?.isFavorite == true ? "bookmark.fill" : "bookmark")
                }

                Button {
                    if let note { note.isPinned.toggle(); saveNote() }
                } label: {
                    Label(note?.isPinned == true ? "고정 해제" : "고정",
                          systemImage: note?.isPinned == true ? "pin.slash" : "pin")
                }

                Divider()

                Button {
                    appViewModel.showTimelineSheet = true
                } label: {
                    Label("타임라인 열기", systemImage: "clock")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        #endif
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Event Banner
    // ─────────────────────────────────────────────────────────────────────
    private var eventBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(Color.noCalAccent)
                Text("감지된 일정/미리알림")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.noCalAccent)
                Spacer()
                Button {
                    showEventBanner = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(parsedEvents) { ev in
                HStack(spacing: 8) {
                    Image(systemName: ev.type == .calendar ? "calendar" : "bell")
                        .font(.caption)
                        .foregroundStyle(ev.type == .calendar ? Color.noCalEvent : Color.noCalReminder)
                        .frame(width: 16)
                    Text(ev.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(ev.date.formatted(date: .abbreviated, time: ev.hasTime ? .shortened : .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("추가") {
                        addEventToCalendar(ev)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.noCalAccent)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color.noCalAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, NoCalTheme.spacing16)
        .padding(.bottom, 4)
    }

    private func addEventToCalendar(_ event: ParsedEvent) {
        let service = EventKitService.shared
        do {
            switch event.type {
            case .calendar:
                try service.createEvent(title: event.title, start: event.date)
            case .reminder:
                try service.createReminder(title: event.title, dueDate: event.date)
            }
            parsedEvents.removeAll { $0.id == event.id }
            if parsedEvents.isEmpty { showEventBanner = false }
        } catch {
            // 권한 없음 — 배너 유지
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Empty State
    // ─────────────────────────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: NoCalTheme.spacing16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text("노트를 선택하거나 새로 만드세요")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("← 왼쪽에서 노트를 선택하거나\n+ 버튼으로 새 노트를 만드세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────────────────────────────
    private var editorBaseFont: PlatformFont {
        #if os(iOS)
        return UIFont.systemFont(ofSize: editorFontSize)
        #else
        return NSFont.systemFont(ofSize: editorFontSize)
        #endif
    }

    private func insert(_ snippet: String) {
        NotificationCenter.default.post(name: .noCalInsertSnippet, object: snippet)
    }

    private func loadNote() {
        guard let note, note.id != loadedID else { return }
        title         = note.title
        content       = note.content
        loadedID      = note.id
        parsedEvents  = []
        showEventBanner = false
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(autoSaveDelay * 1000)))
            guard !Task.isCancelled else { return }
            await MainActor.run { saveNote() }
        }
    }

    private func saveNote() {
        guard let note else { return }
        note.title      = title
        note.content    = content
        note.modifiedAt = Date()
        note.tags       = MarkdownTag.extract(from: content)
        try? modelContext.save()
        // 위젯 데이터 동기화
        let allNotes = (try? modelContext.fetch(FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        ))) ?? []
        WidgetDataService.shared.syncNotes(allNotes)
        WidgetDataService.shared.syncTodos(from: allNotes.filter {
            Calendar.current.isDateInToday($0.modifiedAt)
        })
        // 이벤트 패턴 파싱 (중복 제외)
        let detected = EventParserService.shared.parse(from: content)
        let newEvents = detected.filter { new in
            !parsedEvents.contains {
                $0.title == new.title &&
                Calendar.current.isDate($0.date, inSameDayAs: new.date) &&
                $0.type == new.type
            }
        }
        if !newEvents.isEmpty {
            parsedEvents.append(contentsOf: newEvents)
            showEventBanner = true
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Platform Font Alias
// ─────────────────────────────────────────────────────────────────────────────
#if os(iOS)
typealias PlatformFont = UIFont
#else
typealias PlatformFont = NSFont
#endif

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MarkdownTag Helper
// ─────────────────────────────────────────────────────────────────────────────
enum MarkdownTag {
    /// Extract unique #tags from markdown text (Korean + alphanumeric).
    static func extract(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![/\w])#([가-힣\w]+)"#) else { return [] }
        let nsText  = text as NSString
        let range   = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: range)
        let tags    = matches.compactMap { m -> String? in
            guard let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
        return Array(NSOrderedSet(array: tags)) as? [String] ?? tags
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Markdown Action Enum
// ─────────────────────────────────────────────────────────────────────────────
enum MarkdownAction: String, CaseIterable, Identifiable {
    case h1, h2, h3
    case bold, italic, strikethrough, highlight
    case checkbox, bullet, numbered
    case quote, inlineCode, codeBlock
    case link, divider, dateInsert

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .h1:           return "textformat.size.larger"
        case .h2:           return "textformat.size"
        case .h3:           return "textformat.size.smaller"
        case .bold:         return "bold"
        case .italic:       return "italic"
        case .strikethrough:return "strikethrough"
        case .highlight:    return "highlighter"
        case .checkbox:     return "checkmark.square"
        case .bullet:       return "list.bullet"
        case .numbered:     return "list.number"
        case .quote:        return "text.quote"
        case .inlineCode:   return "chevron.left.forwardslash.chevron.right"
        case .codeBlock:    return "terminal"
        case .link:         return "link"
        case .divider:      return "minus"
        case .dateInsert:   return "calendar"
        }
    }

    var label: String {
        switch self {
        case .h1:           return "H1"
        case .h2:           return "H2"
        case .h3:           return "H3"
        case .bold:         return "굵게"
        case .italic:       return "기울임"
        case .strikethrough:return "취소선"
        case .highlight:    return "형광펜"
        case .checkbox:     return "할일"
        case .bullet:       return "목록"
        case .numbered:     return "번호"
        case .quote:        return "인용"
        case .inlineCode:   return "코드"
        case .codeBlock:    return "블록"
        case .link:         return "링크"
        case .divider:      return "구분선"
        case .dateInsert:   return "날짜"
        }
    }

    /// The raw snippet string sent via NotificationCenter to MarkdownTextEditor.
    /// Wrap snippets ("****", "__", etc.) are processed by processMarkdownSnippet().
    var snippet: String {
        switch self {
        case .h1:           return "\n# "
        case .h2:           return "\n## "
        case .h3:           return "\n### "
        case .bold:         return "****"
        case .italic:       return "__"
        case .strikethrough:return "~~~~"
        case .highlight:    return "===="
        case .checkbox:     return "\n- [ ] "
        case .bullet:       return "\n- "
        case .numbered:     return "\n1. "
        case .quote:        return "\n> "
        case .inlineCode:   return "``"
        case .codeBlock:    return "\n```\n\n```"
        case .link:         return "[]()"
        case .divider:      return "\n---\n"
        case .dateInsert:
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: Date())
        }
    }
}
