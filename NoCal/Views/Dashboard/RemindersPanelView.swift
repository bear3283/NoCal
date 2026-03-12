/// RemindersPanelView.swift
/// 대시보드 좌측 하단 패널: 미완료 미리알림 목록 + 편집

import SwiftUI
import EventKit
#if os(macOS)
import AppKit
#endif

struct RemindersPanelView: View {

    @State private var showNewReminder   = false
    @State private var editableReminder: IdentifiableReminder?
    @State private var headerFlash       = false

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            let reminders = EventKitService.shared.incompleteReminders

            if !EventKitService.shared.hasRemindersAccess {
                permissionView
            } else if reminders.isEmpty {
                placeholder("미완료 미리알림 없음", icon: "checkmark.circle")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                            RemindersPanelRow(
                                reminder: reminder,
                                onEdit: { editableReminder = IdentifiableReminder(reminder) }
                            )
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewReminder, onDismiss: {
            Task { await EventKitService.shared.fetchReminders() }
        }) {
            NewEventSheet(presetDate: Date(), defaultItemType: .reminder)
        }
        .sheet(item: $editableReminder, onDismiss: {
            Task { await EventKitService.shared.fetchReminders() }
        }) { wrapper in
            EditReminderSheet(reminder: wrapper.reminder)
        }
        .task { await EventKitService.shared.fetchReminders() }
        .onReceive(NotificationCenter.default.publisher(for: .noCalItemAdded)) { notif in
            guard notif.object as? String == "reminder" else { return }
            withAnimation(.easeIn(duration: 0.15)) { headerFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.4)) { headerFlash = false }
            }
        }
    }

    // MARK: - Header
    private var panelHeader: some View {
        HStack {
            Text("미리알림")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button { showNewReminder = true } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("새 미리알림 추가")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            headerFlash
                ? Color.green.opacity(0.18)
                : Color.clear
        )
        .background(.ultraThinMaterial)
    }

    private var permissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("미리알림 권한 필요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("미리알림을 보고 완료하려면\n권한을 허용해주세요")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if EventKitService.shared.remindersStatus == .denied {
                Button("시스템 설정에서 허용") {
                    #if os(macOS)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                        NSWorkspace.shared.open(url)
                    }
                    #endif
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("허용") {
                    Task { await EventKitService.shared.requestRemindersAccess() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeholder(_ text: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.quaternary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reminder Row

private struct RemindersPanelRow: View {
    let reminder: EKReminder
    let onEdit:   () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                try? EventKitService.shared.toggleReminder(reminder)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.noCalReminder)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title ?? "미리알림")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let due = reminder.dueDate {
                    Text(due, style: .date)
                        .font(.caption2)
                        .foregroundStyle(reminder.isOverdue ? .red : .secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
