/// TemplatePickerView.swift
/// Phase 4: 노트 템플릿 선택 Sheet.
/// 내장 템플릿 + 사용자 커스텀 템플릿 표시.

import SwiftUI
import SwiftData

struct TemplatePickerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @Query(sort: \NoteTemplate.sortOrder) private var customTemplates: [NoteTemplate]

    var onSelect: (NoteTemplate) -> Void

    @State private var showEditor = false
    @State private var editingTemplate: NoteTemplate? = nil
    @State private var selectedCategory: TemplateCategory = .all

    enum TemplateCategory: String, CaseIterable {
        case all     = "전체"
        case builtIn = "기본"
        case custom  = "나만의"
    }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Category Picker ──────────────────────────────────────
                Picker("카테고리", selection: $selectedCategory) {
                    ForEach(TemplateCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // ── Template Grid ────────────────────────────────────────
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ], spacing: 12) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(template: template) {
                                onSelect(template)
                                dismiss()
                            }
                            .contextMenu {
                                if !template.isBuiltIn {
                                    Button {
                                        editingTemplate = template
                                        showEditor = true
                                    } label: {
                                        Label("편집", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(template)
                                        try? modelContext.save()
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        // ── 새 템플릿 만들기 버튼 ────────────────────────
                        if selectedCategory != .builtIn {
                            Button {
                                editingTemplate = nil
                                showEditor = true
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: "plus.circle.dashed")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.noCalAccent)
                                    Text("새 템플릿")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.noCalAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                                .background(
                                    Color.noCalAccent.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: NoCalTheme.radiusMed)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: NoCalTheme.radiusMed)
                                        .stroke(Color.noCalAccent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("템플릿 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showEditor) {
            TemplateEditorView(template: editingTemplate)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    private var filteredTemplates: [NoteTemplate] {
        switch selectedCategory {
        case .all:
            return NoteTemplate.builtIns + customTemplates.filter { !$0.isBuiltIn }
        case .builtIn:
            return NoteTemplate.builtIns
        case .custom:
            return customTemplates.filter { !$0.isBuiltIn }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Template Card
// ─────────────────────────────────────────────────────────────────────────────

private struct TemplateCard: View {

    let template: NoteTemplate
    let onTap:    () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {

                HStack {
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundStyle(Color.noCalAccent)
                    Spacer()
                    if template.isBuiltIn {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }
                }

                Text(template.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(template.content)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(
                Color(uiColorName: "systemBackground").opacity(0.8),
                in: RoundedRectangle(cornerRadius: NoCalTheme.radiusMed)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NoCalTheme.radiusMed)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

// Helper for cross-platform background
private extension Color {
    init(uiColorName: String) {
        #if os(iOS)
        self = Color(UIColor(named: uiColorName) ?? .systemBackground)
        #else
        self = Color(NSColor(named: uiColorName) ?? .windowBackgroundColor)
        #endif
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Template Editor
// ─────────────────────────────────────────────────────────────────────────────

struct TemplateEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    var template: NoteTemplate?

    @State private var name:         String = ""
    @State private var icon:         String = "doc.text"
    @State private var titlePattern: String = ""
    @State private var content:      String = ""

    private let icons = [
        "doc.text", "star", "lightbulb", "person.3", "calendar",
        "checkmark.circle", "folder", "flag", "heart", "bookmark",
        "tag", "paperclip", "link", "photo", "map",
        "sun.max", "moon", "cloud", "flame", "bolt",
    ]

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("템플릿 이름", text: $name)

                    LabeledContent("아이콘") {
                        Menu {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                                ForEach(icons, id: \.self) { ic in
                                    Button {
                                        icon = ic
                                    } label: {
                                        Image(systemName: ic)
                                            .frame(width: 32, height: 32)
                                            .background(ic == icon ? Color.noCalAccent.opacity(0.15) : .clear,
                                                        in: RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            .padding(8)
                        } label: {
                            Image(systemName: icon)
                                .frame(width: 32, height: 32)
                                .background(Color.noCalAccent.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(Color.noCalAccent)
                        }
                    }

                    TextField("제목 패턴 (예: {{date}} 회의록)", text: $titlePattern)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                } header: {
                    Text("내용")
                } footer: {
                    Text("{{date}} {{time}} {{weekday}} {{week}} {{month}} {{year}} 사용 가능")
                        .font(.caption2)
                }
            }
            .navigationTitle(template == nil ? "새 템플릿" : "템플릿 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadTemplate() }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    private func loadTemplate() {
        guard let t = template else { return }
        name         = t.name
        icon         = t.icon
        titlePattern = t.titlePattern
        content      = t.content
    }

    private func save() {
        if let existing = template {
            existing.name         = name
            existing.icon         = icon
            existing.titlePattern = titlePattern
            existing.content      = content
        } else {
            let t = NoteTemplate(
                name:         name,
                icon:         icon,
                titlePattern: titlePattern,
                content:      content,
                isBuiltIn:    false
            )
            modelContext.insert(t)
        }
        try? modelContext.save()
        dismiss()
    }
}
