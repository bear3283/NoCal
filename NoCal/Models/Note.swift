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
    var isFavorite: Bool
    var isDaily: Bool
    var dailyDate: Date?
    var tags: [String]
    /// 이미 캘린더/미리알림에 등록된 날짜 링크 원문 (e.g. "@2026-03-15 15:00", "!2026-03-15")
    /// 중복 등록 방지 및 에디터에서 "이미 추가됨" 스타일 표시에 사용
    var registeredDateLinks: [String]

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
        self.isFavorite = false
        self.tags = []
        self.registeredDateLinks = []
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

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}
