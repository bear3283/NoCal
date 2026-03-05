/// RootView.swift
/// Phase 4: macOS Commands 알림 수신, 키보드 단축키 처리, 템플릿 시트 추가.

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appViewModel = AppViewModel()
    @State private var showTemplates = false

    var body: some View {
        adaptiveLayout
            .environment(appViewModel)
            .tint(Color.noCalAccent)
            .onAppear {
                appViewModel.navigateToToday(context: modelContext)
                seedBuiltInTemplates()
            }
            // ── macOS menu command notifications ──────────────────────────
            .onReceive(NotificationCenter.default.publisher(for: .noCalNewNote)) { _ in
                createNote()
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalOpenToday)) { _ in
                appViewModel.navigateToToday(context: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalToggleTimeline)) { _ in
                appViewModel.showTimeline.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalGoToToday)) { _ in
                appViewModel.selectedDate = Date()
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalNextDay)) { _ in
                appViewModel.selectedDate = Calendar.current.date(
                    byAdding: .day, value: 1, to: appViewModel.selectedDate) ?? appViewModel.selectedDate
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalPreviousDay)) { _ in
                appViewModel.selectedDate = Calendar.current.date(
                    byAdding: .day, value: -1, to: appViewModel.selectedDate) ?? appViewModel.selectedDate
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalTogglePin)) { _ in
                if let note = appViewModel.selectedNote {
                    note.isPinned.toggle()
                    try? modelContext.save()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalDeleteNote)) { _ in
                if let note = appViewModel.selectedNote {
                    appViewModel.selectedNote = nil
                    modelContext.delete(note)
                    try? modelContext.save()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .noCalShowTemplates)) { _ in
                showTemplates = true
            }
            // ── Template Sheet ────────────────────────────────────────────
            .sheet(isPresented: $showTemplates) {
                TemplatePickerView { template in
                    applyTemplate(template)
                }
            }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Adaptive Layout
    // ─────────────────────────────────────────────────────────────────────

    @ViewBuilder
    private var adaptiveLayout: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: macOS — 3-column layout
    // ─────────────────────────────────────────────────────────────────────
    #if os(macOS)
    @ViewBuilder
    private var macOSLayout: some View {
        @Bindable var vm = appViewModel

        NavigationSplitView(columnVisibility: $vm.columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: NoCalTheme.sidebarMinWidth,
                    ideal: NoCalTheme.sidebarIdealWidth,
                    max: NoCalTheme.sidebarMaxWidth
                )
        } content: {
            NoteListView()
                .navigationSplitViewColumnWidth(
                    min: NoCalTheme.listMinWidth,
                    ideal: NoCalTheme.listIdealWidth,
                    max: NoCalTheme.listMaxWidth
                )
        } detail: {
            HStack(spacing: 0) {
                NoteEditorView()

                if appViewModel.showTimeline {
                    Divider()
                    TimelineView()
                        .frame(width: NoCalTheme.timelineWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    #endif

    // ─────────────────────────────────────────────────────────────────────
    // MARK: iOS — 2-column + bottom sheet
    // ─────────────────────────────────────────────────────────────────────
    #if os(iOS)
    @ViewBuilder
    private var iOSLayout: some View {
        @Bindable var vm = appViewModel

        NavigationSplitView {
            SidebarView()
        } detail: {
            NavigationStack {
                NoteListView()
                    .navigationDestination(item: $vm.selectedNote) { _ in
                        NoteEditorView()
                            .navigationBarTitleDisplayMode(.inline)
                            .sheet(isPresented: $vm.showTimelineSheet) {
                                NavigationStack {
                                    TimelineView()
                                        .navigationTitle("타임라인")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .toolbar {
                                            ToolbarItem(placement: .confirmationAction) {
                                                Button("닫기") {
                                                    vm.showTimelineSheet = false
                                                }
                                            }
                                        }
                                }
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                                .presentationCornerRadius(20)
                            }
                    }
            }
        }
    }
    #endif

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────────────────────────────

    private func seedBuiltInTemplates() {
        let desc = FetchDescriptor<NoteTemplate>(predicate: #Predicate { $0.isBuiltIn == true })
        let existing = (try? modelContext.fetch(desc)) ?? []
        guard existing.isEmpty else { return }
        NoteTemplate.builtIns.forEach { modelContext.insert($0) }
        try? modelContext.save()
    }

    private func createNote() {
        let folder: Folder?
        if case .folder(let f) = appViewModel.selectedSidebarItem { folder = f }
        else { folder = nil }
        let note = appViewModel.createNote(in: folder, context: modelContext)
        appViewModel.selectedNote = note
    }

    private func applyTemplate(_ template: NoteTemplate) {
        let folder: Folder?
        if case .folder(let f) = appViewModel.selectedSidebarItem { folder = f }
        else { folder = nil }
        let note = appViewModel.createNote(in: folder, context: modelContext)
        note.title   = template.resolvedTitle
        note.content = template.resolvedContent
        try? modelContext.save()
        appViewModel.selectedNote = note
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Note.self, Folder.self, TimedTask.self], inMemory: true)
}
