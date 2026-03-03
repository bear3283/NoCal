import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    var isDaily: Bool
    var dailyDate: Date?
    var tags: [String]

    @Relationship(deleteRule: .nullify)
    var folder: Folder?

    init(
        title: String = "",
        content: String = "",
        isDaily: Bool = false,
        dailyDate: Date? = nil,
        folder: Folder? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.isDaily = isDaily
        self.dailyDate = dailyDate ?? (isDaily ? Calendar.current.startOfDay(for: Date()) : nil)
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isPinned = false
        self.tags = []
        self.folder = folder
    }

    // MARK: - Computed Properties

    var displayTitle: String {
        if !title.isEmpty { return title }
        if isDaily, let date = dailyDate {
            return date.formatted(date: .long, time: .omitted)
        }
        return "제목 없음"
    }

    var preview: String {
        let stripped = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .first ?? ""
        return String(stripped.prefix(120))
    }

    var extractedTags: [String] {
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        return matches.compactMap {
            guard let range = Range($0.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}
