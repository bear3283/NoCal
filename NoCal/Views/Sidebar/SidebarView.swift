/// SidebarView.swift
/// Phase 2: Added Tags section with #tag filtering.
/// Phase 5: Fixed date-tap auto-creation, added reminder dots, split pin/favorites badges.

import SwiftUI
import SwiftData
import EventKit

struct SidebarView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appViewModel

    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]

    @State private var showAddFolder  = false
    @State private var newFolderName  = ""
    @State private var expandedTags   = true

    // ── Derived ───────────────────────────────────────────────────────────
    var noteDates: Set<Date> {
        Set(allNotes.compactMap { $0.dailyDate })
    }

    var topTags: [String] { Array(appViewModel.allTagsSorted.prefix(12)) }

    private var allNotesBadge: String? {
        allNotes.count > 0 ? "\(allNotes.count)" : nil
    }
    private var pinnedBadge: String? {
        let c = allNotes.filter(\.isPinned).count
        return c > 0 ? "\(c)" : nil
    }
    private var favoritesBadge: String? {
        let c = allNotes.filter(\.isFavorite).count
        return c > 0 ? "\(c)" : nil
    }

    var reminderDates: Set<Date> {
        Set(EventKitService.shared.incompleteReminders.compactMap { $0.dueDate })
    }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        let selection = Binding<SidebarItem?>(
            get: { appViewModel.selectedSidebarItem },
            set: { if let v = $0 { appViewModel.selectedSidebarItem = v } }
        )
        List(selection: selection) {
            quickAccessSection
            foldersSection
            tagsSection
            calendarSection
            remindersSection
        }
        .listStyle(.sidebar)
        .navigationTitle("nocal")
        .toolbar { sidebarToolbar }
        .alert("새 폴더", isPresented: $showAddFolder) {
            TextField("폴더 이름", text: $newFolderName)
            Button("만들기", action: addFolder)
            Button("취소", role: .cancel) { newFolderName = "" }
        }
        .onChange(of: allNotes) { _, notes in appViewModel.refreshTags(from: notes) }
        .onReceive(NotificationCenter.default.publisher(for: .noCalNewFolder)) { _ in
            showAddFolder = true
        }
        .onAppear {
            appViewModel.refreshTags(from: allNotes)
            if appViewModel.selectedNote == nil { appViewModel.navigateToToday(context: modelContext) }
        }
        .onChange(of: appViewModel.selectedSidebarItem) { _, item in
            if case .today = item {
                appViewModel.selectedNote = appViewModel.getOrCreateDailyNote(context: modelContext)
            }
        }
    }

    @ViewBuilder private var quickAccessSection: some View {
        Section {
            SidebarRow(icon: "sun.max.fill", label: "오늘",      color: .orange, iconBadge: true).tag(SidebarItem.today)
            SidebarRow(icon: "note.text",    label: "모든 노트", color: .blue,   iconBadge: true, badge: allNotesBadge).tag(SidebarItem.allNotes)
            SidebarRow(icon: "star.fill",    label: "즐겨찾기",  color: .yellow, iconBadge: true, badge: favoritesBadge).tag(SidebarItem.favorites)
        } header: { Text("빠른 접근").sidebarHeader() }
    }

    @ViewBuilder private var foldersSection: some View {
        Section {
            ForEach(folders) { folder in
                let badge: String? = folder.notes.count > 0 ? "\(folder.notes.count)" : nil
                SidebarRow(icon: folder.icon, label: folder.name, color: folder.accentColor, iconBadge: true, badge: badge)
                    .tag(SidebarItem.folder(folder))
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(folder); try? modelContext.save()
                        } label: { Label("폴더 삭제", systemImage: "trash") }
                    }
            }
            .onDelete(perform: deleteFolders)
        } header: {
            HStack {
                Text("폴더").sidebarHeader()
                Spacer()
                Button { showAddFolder = true } label: {
                    Image(systemName: "plus").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var tagsSection: some View {
        if !topTags.isEmpty {
            Section {
                if expandedTags {
                    ForEach(topTags, id: \.self) { tag in
                        SidebarRow(icon: "number", label: tag, color: Color.noCalAccent, badge: badgeCount(tag: tag))
                            .tag(SidebarItem.tag(tag))
                    }
                }
            } header: {
                HStack {
                    Text("태그").sidebarHeader()
                    Spacer()
                    Button { withAnimation(NoCalTheme.springFast) { expandedTags.toggle() } } label: {
                        Image(systemName: expandedTags ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var remindersSection: some View {
        let reminders = EventKitService.shared.incompleteReminders
        if EventKitService.shared.hasRemindersAccess && !reminders.isEmpty {
            Section {
                ForEach(reminders.prefix(8), id: \.calendarItemIdentifier) { reminder in
                    SidebarReminderRow(reminder: reminder)
                }
                if reminders.count > 8 {
                    Text("+ \(reminders.count - 8)개 더")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            } header: { Text("미리알림").sidebarHeader() }
        }
    }

    @ViewBuilder private var calendarSection: some View {
        Section {
            MiniCalendarView(
                selectedDate: Binding(
                    get: { appViewModel.selectedDate },
                    set: { date in
                        appViewModel.selectedDate = date
                        if let existing = allNotes.first(where: {
                            $0.isDaily && Calendar.current.isDate(
                                $0.dailyDate ?? .distantPast, inSameDayAs: date)
                        }) {
                            appViewModel.selectedNote = existing
                            appViewModel.selectedSidebarItem = .today
                        } else {
                            appViewModel.selectedSidebarItem = .allNotes
                        }
                    }
                ),
                noteDates: noteDates,
                reminderDates: reminderDates
            )
            .padding(.vertical, 4)

            // ── 선택한 날의 캘린더 일정 ─────────────────────────────────
            if EventKitService.shared.hasCalendarAccess {
                let dayEvents = EventKitService.shared.todayEvents
                if dayEvents.isEmpty {
                    Text("일정 없음")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 2)
                } else {
                    ForEach(dayEvents.prefix(5), id: \.eventIdentifier) { event in
                        SidebarEventRow(event: event)
                    }
                    if dayEvents.count > 5 {
                        Text("+ \(dayEvents.count - 5)개 더")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                }
            }
        } header: { Text("캘린더").sidebarHeader() }
        .onChange(of: appViewModel.selectedDate) { _, date in
            Task { await EventKitService.shared.refresh(for: date) }
        }
        .task { await EventKitService.shared.refresh(for: appViewModel.selectedDate) }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Toolbar
    // ─────────────────────────────────────────────────────────────────────
    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .primaryAction) {
            Button { showAddFolder = true } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("새 폴더")
        }
        #else
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showAddFolder = true } label: {
                Image(systemName: "folder.badge.plus")
            }
        }
        #endif
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────────────────────────────
    private func badgeCount(tag: String) -> String? {
        let count = allNotes.filter { $0.tags.contains(tag) }.count
        return count > 0 ? "\(count)" : nil
    }

    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let folder = Folder(name: name, sortOrder: folders.count)
        modelContext.insert(folder)
        try? modelContext.save()
        newFolderName = ""
    }

    private func deleteFolders(at offsets: IndexSet) {
        offsets.map { folders[$0] }.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SidebarEventRow
// ─────────────────────────────────────────────────────────────────────────────
private struct SidebarEventRow: View {
    let event: EKEvent

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.calendarColor)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "일정")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(timeFmt.string(from: event.startDate)) – \(timeFmt.string(from: event.endDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SidebarReminderRow
// ─────────────────────────────────────────────────────────────────────────────
private struct SidebarReminderRow: View {
    let reminder: EKReminder

    var body: some View {
        Button {
            try? EventKitService.shared.toggleReminder(reminder)
        } label: {
            HStack(spacing: NoCalTheme.sp8) {
                Image(systemName: "circle")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.noCalReminder)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(reminder.title ?? "미리알림")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let due = reminder.dueDate {
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundStyle(
                                reminder.isOverdue ? Color.red.opacity(0.8) : .secondary
                            )
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SidebarRow
// ─────────────────────────────────────────────────────────────────────────────
struct SidebarRow: View {
    let icon:      String
    let label:     String
    let color:     Color
    var iconBadge: Bool    = false   // iOS Notes style: colored rounded-rect background
    var badge:     String? = nil

    var body: some View {
        HStack(spacing: NoCalTheme.sp8) {
            iconView
            Text(label)
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if iconBadge {
            ZStack {
                RoundedRectangle(cornerRadius: NoCalTheme.sidebarIconBadgeRadius)
                    .fill(color)
                    .frame(
                        width:  NoCalTheme.sidebarIconBadgeSize,
                        height: NoCalTheme.sidebarIconBadgeSize
                    )
                Image(systemName: icon)
                    .font(.system(size: NoCalTheme.sidebarIconBadgeFont, weight: .medium))
                    .foregroundStyle(.white)
            }
        } else {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: NoCalTheme.iconMD))
                .frame(width: NoCalTheme.sidebarIconBadgeSize)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Section Header Helper
// ─────────────────────────────────────────────────────────────────────────────
private extension Text {
    func sidebarHeader() -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
