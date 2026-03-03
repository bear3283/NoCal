import Foundation
import SwiftData
import SwiftUI

@Model
final class Folder {
    var id: UUID
    var name: String
    var icon: String
    var colorName: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade)
    var notes: [Note]

    init(
        name: String,
        icon: String = "folder",
        colorName: String = "indigo",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.notes = []
    }

    var accentColor: Color {
        switch colorName {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "teal":   return .teal
        case "blue":   return .blue
        case "purple": return .purple
        case "pink":   return .pink
        default:       return .indigo
        }
    }

    var sortedNotes: [Note] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.modifiedAt > $1.modifiedAt
        }
    }
}
