/// NoteRowView.swift
/// Phase 6 Design: Improved typography, spacing, and visual hierarchy.

import SwiftUI

struct NoteRowView: View {

    let note: Note
    var onSchedule: ((Note) -> Void)? = nil

    private var tags: [String] { Array(MarkdownTag.extract(from: note.content).prefix(3)) }

    private var checkboxProgress: (done: Int, total: Int) {
        let lines = note.content.components(separatedBy: .newlines)
        let total = lines.filter { $0.hasPrefix("- [ ]") || $0.lowercased().hasPrefix("- [x]") }.count
        let done  = lines.filter { $0.lowercased().hasPrefix("- [x]") }.count
        return (done, total)
    }

    var body: some View {
        rowContent
            .draggable(note.id.uuidString)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: NoCalTheme.sp6) {

            // MARK: Title row
            HStack(spacing: 5) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.noCalAccent)
                }
                Text(note.displayTitle)
                    .font(.noteListTitle)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if note.isDaily {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                if note.isFavorite {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.yellow)
                }
            }

            // MARK: Preview
            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.notePreview)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("내용 없음")
                    .font(.notePreview)
                    .foregroundStyle(.quaternary)
                    .italic()
            }

            // MARK: Footer
            HStack(spacing: 6) {
                Text(note.relativeDate)
                    .font(.metaLabel)
                    .foregroundStyle(.tertiary)

                let (done, total) = checkboxProgress
                if total > 0 {
                    checkboxPill(done: done, total: total)
                }

                Spacer(minLength: 0)

                if !tags.isEmpty {
                    tagsRow
                }
            }
        }
        .padding(.vertical, NoCalTheme.noteRowVerticalPad)
        .contentShape(Rectangle())
    }

    // MARK: - Subviews

    private func checkboxPill(done: Int, total: Int) -> some View {
        let complete = done == total
        return HStack(spacing: 3) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(complete ? Color.noCalDone : Color.noCalAccent)
            Text("\(done)/\(total)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(complete ? Color.noCalDone : Color.noCalAccent)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (complete ? Color.noCalDone : Color.noCalAccent).opacity(0.09),
            in: Capsule()
        )
    }

    private var tagsRow: some View {
        HStack(spacing: 3) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .noCalTagChip()
            }
        }
    }
}
