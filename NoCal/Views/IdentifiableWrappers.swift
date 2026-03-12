/// IdentifiableWrappers.swift
/// EKEvent / EKReminder는 Identifiable을 미준수 → .sheet(item:) 용 래퍼

import EventKit

struct IdentifiableEvent: Identifiable {
    let id:    String
    let event: EKEvent
    init(_ event: EKEvent) {
        self.id    = event.eventIdentifier ?? UUID().uuidString
        self.event = event
    }
}

struct IdentifiableReminder: Identifiable {
    let id:       String
    let reminder: EKReminder
    init(_ reminder: EKReminder) {
        self.id       = reminder.calendarItemIdentifier
        self.reminder = reminder
    }
}
