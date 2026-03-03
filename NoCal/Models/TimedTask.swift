/// TimedTask.swift
/// Phase 3: SwiftData model for nocal tasks pinned to the timeline.
/// Displayed as outline blocks in TimelineView alongside solid EKEvent blocks.

import Foundation
import SwiftData
import SwiftUI

@Model
final class TimedTask {
    var id:          UUID
    var title:       String
    var startDate:   Date
    var duration:    TimeInterval   // seconds
    var isCompleted: Bool
    var colorName:   String
    var notes:       String

    /// Optional link back to the source Note (nil if created standalone)
    @Relationship(deleteRule: .nullify)
    var sourceNote: Note?

    /// External identifier if synced to EKReminder
    var ekReminderID: String?
    /// External identifier if synced to EKEvent
    var ekEventID: String?

    init(
        title:      String,
        startDate:  Date,
        duration:   TimeInterval = 3600,
        sourceNote: Note?        = nil,
        colorName:  String       = "indigo"
    ) {
        self.id          = UUID()
        self.title       = title
        self.startDate   = startDate
        self.duration    = duration
        self.isCompleted = false
        self.colorName   = colorName
        self.notes       = ""
        self.sourceNote  = sourceNote
    }

    // MARK: - Computed

    var endDate: Date { startDate.addingTimeInterval(duration) }

    var startMinuteOfDay: CGFloat {
        let c = Calendar.current
        return CGFloat(c.component(.hour, from: startDate) * 60
                     + c.component(.minute, from: startDate))
    }

    var durationMinutes: CGFloat { CGFloat(duration / 60) }

    var accentColor: Color {
        switch colorName {
        case "red":    return .red
        case "orange": return .orange
        case "green":  return .green
        case "blue":   return .blue
        case "purple": return .purple
        default:       return .indigo
        }
    }

    var timeRangeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm"
        return "\(fmt.string(from: startDate))–\(fmt.string(from: endDate))"
    }
}
