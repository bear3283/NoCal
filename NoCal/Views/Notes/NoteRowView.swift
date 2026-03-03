/// NoteRowView.swift
/// Phase 3: Added .draggable(note.id.uuidString) for macOS timeline drop,
/// and "타임라인 추가" swipe action for iOS.

import SwiftUI

struct NoteRowView: View {

    let note: Note
    var onSchedule: ((Note) -> Void)? = nil   // iOS: schedule callback

    private var tags: [String] { Array(MarkdownTag.extract(from: note.content).prefix(3)) }

    private var checkboxProgress: (done: Int, total: Int) {
        let lines = note.content.components(separatedBy: .newlines)
        let total = lines.filter { $0.hasPrefix("- [ ]") || $0.lowercased().hasPrefix("- [x]") }.count
        let done  = lines.filter { $0.lowercased().hasPrefix("- [x]") }.count
        return (done, total)
    }

    // ─────────────────────────────────────────────────────────────────────
    var body: some View {
        rowContent
        // macOS / iPad: drag note onto timeline to create a TimedTask
            .draggable(note.id.uuidString)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 5) {

            // ── Title ──────────────────────────────────────────────────
            HStack(spacing: 5) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.noCalAccent)
                }
                Text(note.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                if note.isDaily {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            // ── Preview ────────────────────────────────────────────────
            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // ── Footer ─────────────────────────────────────────────────
            HStack(spacing: 6) {
                Text(note.relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Checkbox progress
                let (done, total) = checkboxProgress
                if total > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: done == total ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 9))
                            .foregroundStyle(done == total ? Color.green : Color.noCalAccent)
                        Text("\(done)/\(total)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.noCalAccent)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.noCalAccent.opacity(0.08), in: Capsule())
                }

                Spacer()

                // Tags
                if !tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.noCalAccent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.noCalAccent.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
