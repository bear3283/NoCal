/// AppViewModel.swift
/// Phase 2: Extended with .tag(String) sidebar item and tag-based filtering.

import Foundation
import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SidebarItem
// ─────────────────────────────────────────────────────────────────────────────
enum SidebarItem: Hashable {
    case today
    case allNotes
    case favorites
    case folder(Folder)
    case tag(String)        // Phase 2: tag-based filter

    var title: String {
        switch self {
        case .today:          return "오늘"
        case .allNotes:       return "모든 노트"
        case .favorites:      return "즐겨찾기"
        case .folder(let f):  return f.name
        case .tag(let t):     return "#\(t)"
        }
    }

    var icon: String {
        switch self {
        case .today:     return "sun.max.fill"
        case .allNotes:  return "note.text"
        case .favorites: return "star.fill"
        case .folder:    return "folder.fill"
        case .tag:       return "number"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AppViewModel
// ─────────────────────────────────────────────────────────────────────────────
@Observable
final class AppViewModel {

    // ── Navigation ────────────────────────────────────────────────────────
    var selectedSidebarItem: SidebarItem = .today
    var selectedNote: Note?
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // ── Layout ────────────────────────────────────────────────────────────
    var columnVisibility: NavigationSplitViewVisibility = .all
    var showTimeline:       Bool = true
    var showTimelineSheet:  Bool = false

    // ── Search ────────────────────────────────────────────────────────────
    var searchText: String = ""

    // ── Tag Filter (chip-based quick filter in NoteListView) ─────────────
    var filterTags: Set<String> = []

    func toggleFilterTag(_ tag: String) {
        if filterTags.contains(tag) { filterTags.remove(tag) }
        else { filterTags.insert(tag) }
    }

    // ── Tag cache (updated by SidebarView via allNotes @Query) ────────────
    var allTagsSorted: [String] = []

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Daily Note
    // ─────────────────────────────────────────────────────────────────────
    func getOrCreateDailyNote(for date: Date = Date(), context: ModelContext) -> Note {
        let cal      = Calendar.current
        let target   = cal.startOfDay(for: date)
        let desc     = FetchDescriptor<Note>(predicate: #Predicate { $0.isDaily == true })

        if let notes = try? context.fetch(desc),
           let existing = notes.first(where: { n in
               guard let d = n.dailyDate else { return false }
               return cal.isDate(d, inSameDayAs: target)
           }) {
            return existing
        }

        let label = target.formatted(Date.FormatStyle().year().month(.wide).day())
        let note  = Note(
            title:     label,
            content:   "# \(label)\n\n",
            isDaily:   true,
            dailyDate: target
        )
        context.insert(note)
        try? context.save()
        return note
    }

    func navigateToToday(context: ModelContext) {
        selectedDate       = Calendar.current.startOfDay(for: Date())
        selectedSidebarItem = .today
        selectedNote       = getOrCreateDailyNote(context: context)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Note Filtering
    // ─────────────────────────────────────────────────────────────────────
    func filteredNotes(from allNotes: [Note]) -> [Note] {
        let base: [Note]
        switch selectedSidebarItem {
        case .today:
            base = allNotes.filter {
                $0.isDaily && Calendar.current.isDateInToday($0.dailyDate ?? .distantPast)
            }
        case .allNotes:
            base = allNotes
        case .favorites:
            base = allNotes.filter { $0.isFavorite }
        case .folder(let folder):
            base = allNotes.filter { $0.folder?.id == folder.id }
        case .tag(let tag):
            base = allNotes.filter { $0.tags.contains(tag) }
        }

        // Apply additional tag filter chips
        let tagFiltered: [Note] = filterTags.isEmpty
            ? base
            : base.filter { note in filterTags.allSatisfy { note.tags.contains($0) } }

        guard !searchText.isEmpty else { return sorted(tagFiltered) }
        return sorted(tagFiltered.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        })
    }

    /// Rebuild the global tag list from all notes (call when notes change).
    func refreshTags(from allNotes: [Note]) {
        let all = allNotes.flatMap { $0.tags }
        let counts = Dictionary(grouping: all, by: { $0 })
            .mapValues { $0.count }
        allTagsSorted = counts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Note Creation
    // ─────────────────────────────────────────────────────────────────────
    func createNote(in folder: Folder? = nil, context: ModelContext) -> Note {
        let note = Note(title: "", content: "", folder: folder)
        context.insert(note)
        try? context.save()
        selectedNote = note
        return note
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Private
    // ─────────────────────────────────────────────────────────────────────
    private func sorted(_ notes: [Note]) -> [Note] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.modifiedAt > $1.modifiedAt
        }
    }
}
