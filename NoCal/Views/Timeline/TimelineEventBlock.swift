/// TimelineEventBlock.swift
/// Phase 3: Event block UI components for the timeline.
///   EKEventBlock   — Solid filled block (Apple Calendar events)
///   TimedTaskBlock — Outline block (nocal scheduled tasks)

import SwiftUI
import EventKit
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - EKEventBlock  (solid, Apple Calendar color)
// ─────────────────────────────────────────────────────────────────────────────
struct EKEventBlock: View {
    let event: EKEvent
    var onEdit:   (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "제목 없음")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(event.timeRangeString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            event.calendarColor,
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(event.calendarColor.opacity(0.4), lineWidth: 0.5)
        )
        .contextMenu {
            if let onEdit {
                Button(action: onEdit) {
                    Label("일정 편집", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("일정 삭제", systemImage: "trash")
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - TimedTaskBlock  (outline, nocal accent)
// ─────────────────────────────────────────────────────────────────────────────
struct TimedTaskBlock: View {
    @Bindable var task: TimedTask
    var modelContext: ModelContext

    private var eventKit: EventKitService { EventKitService.shared }

    var body: some View {
        HStack(spacing: 5) {
            // Checkbox — 완료 토글 시 EKReminder에도 동기화
            Button {
                withAnimation(.spring(response: 0.25)) {
                    task.isCompleted.toggle()
                }
                try? modelContext.save()
                if let id = task.ekReminderID {
                    eventKit.syncCompletion(ekReminderID: id, isCompleted: task.isCompleted)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(task.accentColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(task.timeRangeString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    // EKReminder 연결 표시 아이콘
                    if task.ekReminderID != nil {
                        Image(systemName: "checklist")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.noCalAccent.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            task.accentColor.opacity(task.isCompleted ? 0.03 : 0.06),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    task.accentColor.opacity(task.isCompleted ? 0.2 : 0.7),
                    lineWidth: 1.5
                )
        )
        .contextMenu {
            // EKReminder 연결 여부 표시
            if task.ekReminderID != nil {
                Label("미리알림과 연결됨", systemImage: "link")
                Divider()
            }

            Button(role: .destructive) {
                // TimedTask 삭제 시 연결된 EKReminder도 삭제
                if let id = task.ekReminderID {
                    eventKit.deleteReminder(ekReminderID: id)
                }
                modelContext.delete(task)
                try? modelContext.save()
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ReminderRow  (flat list row for the reminders panel)
// ─────────────────────────────────────────────────────────────────────────────
struct ReminderRow: View {
    let reminder: EKReminder
    var onToggle: () -> Void
    var onEdit:   (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // 완료 토글 버튼
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(reminder.isCompleted ? .secondary : Color.noCalAccent)
            }
            .buttonStyle(.plain)

            // 제목 + 날짜 (탭 → 편집)
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title ?? "")
                    .font(.subheadline)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)

                if let due = reminder.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(reminder.isOverdue ? Color.red : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onEdit?() }

            // 편집 버튼 (iOS Reminders 스타일 info 버튼)
            if let onEdit {
                Button(action: onEdit) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.noCalAccent.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let onEdit {
                Button(action: onEdit) {
                    Label("편집", systemImage: "pencil")
                }
                .tint(Color.noCalAccent)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AllDayEventChip
// ─────────────────────────────────────────────────────────────────────────────
struct AllDayEventChip: View {
    let event: EKEvent

    var body: some View {
        Text(event.title ?? "")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(event.calendarColor, in: Capsule())
            .lineLimit(1)
    }
}
