/// EventParserService.swift
/// 마크다운 텍스트에서 날짜 패턴을 파싱하여 캘린더/미리알림 후보를 추출합니다.
///
/// 지원 패턴:
///   @YYYY-MM-DD HH:mm 제목  → EKEvent (캘린더 일정)
///   @YYYY-MM-DD 제목        → EKEvent (시간 없음, 종일)
///   !YYYY-MM-DD 제목        → EKReminder (미리알림)
///   due: YYYY-MM-DD 제목    → EKReminder (미리알림)

import Foundation

// MARK: - ParsedEventType
enum ParsedEventType {
    case calendar
    case reminder
}

// MARK: - ParsedEvent
struct ParsedEvent: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let type: ParsedEventType
    var isAllDay: Bool { type == .calendar && !hasTime }
    var hasTime: Bool = false
}

// MARK: - EventParserService
struct EventParserService {

    static let shared = EventParserService()
    private init() {}

    /// 노트 텍스트에서 ParsedEvent 배열을 추출합니다.
    func parse(from text: String) -> [ParsedEvent] {
        var results: [ParsedEvent] = []
        results.append(contentsOf: parseCalendarEvents(from: text))
        results.append(contentsOf: parseReminders(from: text))
        return results
    }

    // MARK: - Calendar Pattern: @YYYY-MM-DD [HH:mm] 제목
    private func parseCalendarEvents(from text: String) -> [ParsedEvent] {
        // With time: @2026-03-15 14:00 제목
        let withTimePattern = #"@(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)"#
        // Date only: @2026-03-15 제목
        let dateOnlyPattern = #"@(\d{4}-\d{2}-\d{2})\s+([^@!].+)"#

        var events: [ParsedEvent] = []

        if let regex = try? NSRegularExpression(pattern: withTimePattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for m in matches {
                guard m.numberOfRanges == 4,
                      let dateRange  = Range(m.range(at: 1), in: text),
                      let timeRange  = Range(m.range(at: 2), in: text),
                      let titleRange = Range(m.range(at: 3), in: text)
                else { continue }

                let dateStr  = String(text[dateRange])
                let timeStr  = String(text[timeRange])
                let title    = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                if let date = parseDateTime(date: dateStr, time: timeStr) {
                    var ev = ParsedEvent(title: title, date: date, type: .calendar)
                    ev.hasTime = true
                    events.append(ev)
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: dateOnlyPattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for m in matches {
                guard m.numberOfRanges == 3,
                      let dateRange  = Range(m.range(at: 1), in: text),
                      let titleRange = Range(m.range(at: 2), in: text)
                else { continue }

                let dateStr = String(text[dateRange])
                let title   = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                // Exclude if title starts with digits (likely already matched above)
                guard !title.hasPrefix(":") else { continue }
                if let date = parseDate(dateStr) {
                    let ev = ParsedEvent(title: title, date: date, type: .calendar)
                    // Only add if no matching timed event already exists for same date+title
                    if !events.contains(where: { $0.title == title }) {
                        events.append(ev)
                    }
                }
            }
        }

        return events
    }

    // MARK: - Reminder Pattern: !YYYY-MM-DD 제목 / due: YYYY-MM-DD 제목
    private func parseReminders(from text: String) -> [ParsedEvent] {
        let exclamationPattern = #"!(\d{4}-\d{2}-\d{2})\s+(.+)"#
        let duePattern         = #"(?i)due:\s*(\d{4}-\d{2}-\d{2})\s+(.+)"#

        var reminders: [ParsedEvent] = []

        for pattern in [exclamationPattern, duePattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for m in matches {
                guard m.numberOfRanges == 3,
                      let dateRange  = Range(m.range(at: 1), in: text),
                      let titleRange = Range(m.range(at: 2), in: text)
                else { continue }

                let dateStr = String(text[dateRange])
                let title   = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                if let date = parseDate(dateStr) {
                    reminders.append(ParsedEvent(title: title, date: date, type: .reminder))
                }
            }
        }

        return reminders
    }

    // MARK: - Date Parsing Helpers
    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateStr)
    }

    private func parseDateTime(date dateStr: String, time timeStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: "\(dateStr) \(timeStr)")
    }
}
