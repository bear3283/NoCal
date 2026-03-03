/// NoteListView.swift
/// Phase 3: iOS "타임라인에 추가" swipe action + schedule time picker.

import SwiftUI
import SwiftData

struct NoteListView: View {

    @Environment(\.modelContext)   private var modelContext
    @Environment(AppViewModel.self) private var appViewModel

    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]

    @State private var scheduleNote:  Note? = nil
    @State private var scheduleDate:  Date  = Date()
    @State private var showScheduler: Bool  = false

    var displayedNotes: [Note] { appViewModel.filteredNotes(from: allNotes) }

    var navigationTitle: String { appViewModel.selectedSidebarItem.title }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        @Bindable var vm = appViewModel

        VStack(spacing: 0) {
            if !appViewModel.allTagsSorted.isEmpty {
                tagFilterBar
                Divider()
            }
            if displayedNotes.isEmpty {
                emptyState
            } else {
                List(selection: $vm.selectedNote) {
                    ForEach(displayedNotes) { note in
                        NoteRowView(note: note)
                            .tag(note)
                            .swipeActions(edge: .leading) {
                                Button {
                                    note.isPinned.toggle()
                                    try? modelContext.save()
                                } label: {
                                    Label(
                                        note.isPinned ? "고정 해제" : "고정",
                                        systemImage: note.isPinned ? "pin.slash" : "pin"
                                    )
                                }
                                .tint(Color.noCalAccent)

                                // Phase 3: iOS schedule button
                                Button {
                                    scheduleNote = note
                                    scheduleDate = appViewModel.selectedDate
                                    showScheduler = true
                                } label: {
                                    Label("일정 추가", systemImage: "clock.badge.plus")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleteNote(note) } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                            .contextMenu { contextMenu(for: note) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(navigationTitle)
        .searchable(text: $vm.searchText, prompt: "노트 검색")
        .toolbar { listToolbar }
        // iOS: Schedule sheet
        .sheet(isPresented: $showScheduler) {
            scheduleSheet
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Tag Filter Bar
    // ─────────────────────────────────────────────────────────────────────
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !appViewModel.filterTags.isEmpty {
                    Button {
                        appViewModel.filterTags.removeAll()
                    } label: {
                        Label("초기화", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(appViewModel.allTagsSorted.prefix(20), id: \.self) { tag in
                    let selected = appViewModel.filterTags.contains(tag)
                    Button {
                        appViewModel.toggleFilterTag(tag)
                    } label: {
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                selected ? Color.noCalAccent : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25), value: selected)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.background)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: iOS Schedule Sheet
    // ─────────────────────────────────────────────────────────────────────
    private var scheduleSheet: some View {
        NavigationStack {
            Form {
                Section("노트") {
                    if let note = scheduleNote {
                        Label(note.displayTitle, systemImage: "note.text")
                            .foregroundStyle(.primary)
                    }
                }
                Section("시간") {
                    DatePicker("시작 시각", selection: $scheduleDate,
                               displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("타임라인에 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showScheduler = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        if let note = scheduleNote {
                            let task = TimedTask(
                                title:      note.displayTitle,
                                startDate:  scheduleDate,
                                duration:   3600,
                                sourceNote: note
                            )
                            modelContext.insert(task)
                            try? modelContext.save()
                            // EKReminder 자동 생성 → ID 저장 (양방향 동기화)
                            if let reminderID = EventKitService.shared.registerReminder(for: task) {
                                task.ekReminderID = reminderID
                                try? modelContext.save()
                            }
                        }
                        showScheduler = false
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Context Menu
    // ─────────────────────────────────────────────────────────────────────
    @ViewBuilder
    private func contextMenu(for note: Note) -> some View {
        Button {
            note.isPinned.toggle()
            try? modelContext.save()
        } label: {
            Label(note.isPinned ? "고정 해제" : "고정", systemImage: note.isPinned ? "pin.slash.fill" : "pin.fill")
        }

        // Move to folder submenu
        if !folders.isEmpty {
            Menu("폴더로 이동") {
                Button("폴더 없음") {
                    note.folder = nil
                    try? modelContext.save()
                }
                Divider()
                ForEach(folders) { folder in
                    Button(folder.name) {
                        note.folder = folder
                        try? modelContext.save()
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive) { deleteNote(note) } label: {
            Label("삭제", systemImage: "trash")
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Toolbar
    // ─────────────────────────────────────────────────────────────────────
    @ToolbarContentBuilder
    private var listToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: addNote) {
                Image(systemName: "square.and.pencil")
            }
            .help("새 노트 (⌘N)")
            #if os(macOS)
            .keyboardShortcut("n", modifiers: .command)
            #endif
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Empty State
    // ─────────────────────────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: NoCalTheme.spacing16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            VStack(spacing: NoCalTheme.spacing4) {
                Text(emptyTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(emptySubtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button(action: addNote) {
                Label("새 노트 만들기", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.noCalAccent, in: RoundedRectangle(cornerRadius: NoCalTheme.radiusMed))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyIcon: String {
        switch appViewModel.selectedSidebarItem {
        case .today:     return "sun.max"
        case .favorites: return "star"
        case .tag:       return "number"
        default:         return "note.text"
        }
    }

    private var emptyTitle: String {
        switch appViewModel.selectedSidebarItem {
        case .today:          return "오늘의 노트가 없습니다"
        case .favorites:      return "즐겨찾기가 없습니다"
        case .tag(let t):     return "#\(t) 태그 노트 없음"
        default:              return "노트가 없습니다"
        }
    }

    private var emptySubtitle: String {
        switch appViewModel.selectedSidebarItem {
        case .today:      return "오늘 하루를 기록해보세요"
        case .favorites:  return "노트를 고정하면 여기에 나타납니다"
        case .tag(let t): return "본문에 #\(t) 를 입력하면\n이 태그로 분류됩니다"
        default:          return "새 노트를 만들어 시작하세요"
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Actions
    // ─────────────────────────────────────────────────────────────────────
    private func addNote() {
        let folder: Folder?
        if case .folder(let f) = appViewModel.selectedSidebarItem { folder = f }
        else { folder = nil }
        let note = appViewModel.createNote(in: folder, context: modelContext)
        appViewModel.selectedNote = note
    }

    private func deleteNote(_ note: Note) {
        if appViewModel.selectedNote?.id == note.id {
            appViewModel.selectedNote = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
    }
}
