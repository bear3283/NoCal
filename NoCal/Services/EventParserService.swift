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
enum ParsedEventType: Equatable {
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

    // MARK: - Cached formatters (DateFormatter 생성 비용 절약)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone.current  // 타임존 명시 (자정 하루 밀림 방지)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone.current  // 타임존 명시
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    // MARK: - Cached regex patterns (NSRegularExpression 컴파일 비용 절약)
    private static let calWithTimeRegex  = try! NSRegularExpression(pattern: #"@(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)"#)
    private static let calDateOnlyRegex  = try! NSRegularExpression(pattern: #"@(\d{4}-\d{2}-\d{2})\s+([^@!].+)"#)
    private static let remExclamRegex    = try! NSRegularExpression(pattern: #"!(\d{4}-\d{2}-\d{2})\s+(.+)"#)
    private static let remDueRegex       = try! NSRegularExpression(pattern: #"(?i)due:\s*(\d{4}-\d{2}-\d{2})\s+(.+)"#)
    private static let cbCalWithTimeRegex = try! NSRegularExpression(pattern: #"- \[ \] @(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)"#)
    private static let cbCalDateOnlyRegex = try! NSRegularExpression(pattern: #"- \[ \] @(\d{4}-\d{2}-\d{2})\s+([^@!\d].+)"#)
    private static let cbRemExclamRegex  = try! NSRegularExpression(pattern: #"- \[ \] !(\d{4}-\d{2}-\d{2})\s+(.+)"#)
    private static let cbRemDueRegex     = try! NSRegularExpression(pattern: #"- \[ \] (?i)due:\s*(\d{4}-\d{2}-\d{2})\s+(.+)"#)

    /// 노트 텍스트에서 ParsedEvent 배열을 추출합니다.
    func parse(from text: String) -> [ParsedEvent] {
        var results: [ParsedEvent] = []
        results.append(contentsOf: parseCalendarEvents(from: text))
        results.append(contentsOf: parseReminders(from: text))
        results.append(contentsOf: parseCheckboxCalendarEvents(from: text))
        results.append(contentsOf: parseCheckboxReminders(from: text))
        return dedup(results)
    }

    /// 날짜 링크 탭 시 단일 라인을 ParsedEvent로 변환합니다.
    /// - Parameters:
    ///   - line: 탭된 라인 전체 (e.g. "@2026-03-15 15:00 팀 회의")
    ///   - type: "calendar" | "reminder"
    func parseLine(_ line: String, type: String) -> ParsedEvent? {
        let isReminder = type == "reminder"
        let nsRange = NSRange(line.startIndex..., in: line)

        // 시간 포함 패턴 먼저 시도
        let withTimeRegex = isReminder
            ? Self.remExclamRegex       // !YYYY-MM-DD HH:mm 제목 (시간 캡처 없음 → date-only로 fallback)
            : Self.calWithTimeRegex     // @YYYY-MM-DD HH:mm 제목

        if !isReminder,
           let m = Self.calWithTimeRegex.firstMatch(in: line, range: nsRange),
           m.numberOfRanges == 4,
           let dr = Range(m.range(at: 1), in: line),
           let tr = Range(m.range(at: 2), in: line),
           let nr = Range(m.range(at: 3), in: line) {
            let title = String(line[nr]).trimmingCharacters(in: .whitespaces)
            if let date = parseDateTime(date: String(line[dr]), time: String(line[tr])) {
                var ev = ParsedEvent(title: title, date: date, type: .calendar)
                ev.hasTime = true
                return ev
            }
        }

        // 날짜만 있는 패턴
        let dateOnlyRegex = isReminder ? Self.remExclamRegex : Self.calDateOnlyRegex
        if let m = dateOnlyRegex.firstMatch(in: line, range: nsRange),
           m.numberOfRanges >= 3,
           let dr = Range(m.range(at: 1), in: line),
           let nr = Range(m.range(at: 2), in: line) {
            let title = String(line[nr]).trimmingCharacters(in: .whitespaces)
            if let date = parseDate(String(line[dr])) {
                return ParsedEvent(title: title, date: date, type: isReminder ? .reminder : .calendar)
            }
        }

        // 제목 없이 날짜만 입력된 경우 (@2026-03-15 만 있을 때)
        let bareRegex = try? NSRegularExpression(pattern: isReminder
            ? #"!\d{4}-\d{2}-\d{2}"#
            : #"@\d{4}-\d{2}-\d{2}"#)
        if let m = bareRegex?.firstMatch(in: line, range: nsRange),
           let mr = Range(m.range, in: line) {
            let dateStr = String(line[mr].dropFirst()) // @ 또는 ! 제거
            if let date = parseDate(dateStr) {
                return ParsedEvent(
                    title: isReminder ? "미리알림" : "일정",
                    date: date,
                    type: isReminder ? .reminder : .calendar
                )
            }
        }

        return nil
    }

    private func dedup(_ events: [ParsedEvent]) -> [ParsedEvent] {
        var seen = Set<String>()
        return events.filter { ev in
            let typeStr = ev.type == .calendar ? "cal" : "rem"
            let key = "\(ev.title)_\(typeStr)_\(Int(ev.date.timeIntervalSinceReferenceDate / 86400))"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Calendar Pattern: @YYYY-MM-DD [HH:mm] 제목
    private func parseCalendarEvents(from text: String) -> [ParsedEvent] {
        var events: [ParsedEvent] = []
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        for m in Self.calWithTimeRegex.matches(in: text, range: range) {
            guard m.numberOfRanges == 4,
                  let dateRange  = Range(m.range(at: 1), in: text),
                  let timeRange  = Range(m.range(at: 2), in: text),
                  let titleRange = Range(m.range(at: 3), in: text)
            else { continue }
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
            if let date = parseDateTime(date: String(text[dateRange]), time: String(text[timeRange])) {
                var ev = ParsedEvent(title: title, date: date, type: .calendar)
                ev.hasTime = true
                events.append(ev)
            }
        }

        for m in Self.calDateOnlyRegex.matches(in: text, range: range) {
            guard m.numberOfRanges == 3,
                  let dateRange  = Range(m.range(at: 1), in: text),
                  let titleRange = Range(m.range(at: 2), in: text)
            else { continue }
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
            guard !title.hasPrefix(":") else { continue }
            if let date = parseDate(String(text[dateRange])),
               !events.contains(where: { $0.title == title }) {
                events.append(ParsedEvent(title: title, date: date, type: .calendar))
            }
        }

        return events
    }

    // MARK: - Reminder Pattern: !YYYY-MM-DD 제목 / due: YYYY-MM-DD 제목
    private func parseReminders(from text: String) -> [ParsedEvent] {
        var reminders: [ParsedEvent] = []
        let range = NSRange(location: 0, length: (text as NSString).length)

        for regex in [Self.remExclamRegex, Self.remDueRegex] {
            for m in regex.matches(in: text, range: range) {
                guard m.numberOfRanges == 3,
                      let dateRange  = Range(m.range(at: 1), in: text),
                      let titleRange = Range(m.range(at: 2), in: text)
                else { continue }
                let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                if let date = parseDate(String(text[dateRange])) {
                    reminders.append(ParsedEvent(title: title, date: date, type: .reminder))
                }
            }
        }

        return reminders
    }

    // MARK: - Checkbox Calendar Pattern: - [ ] @YYYY-MM-DD [HH:mm] 제목
    private func parseCheckboxCalendarEvents(from text: String) -> [ParsedEvent] {
        var events: [ParsedEvent] = []
        let range = NSRange(location: 0, length: (text as NSString).length)

        for m in Self.cbCalWithTimeRegex.matches(in: text, range: range) {
            guard m.numberOfRanges == 4,
                  let dateRange  = Range(m.range(at: 1), in: text),
                  let timeRange  = Range(m.range(at: 2), in: text),
                  let titleRange = Range(m.range(at: 3), in: text)
            else { continue }
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
            if let date = parseDateTime(date: String(text[dateRange]), time: String(text[timeRange])) {
                var ev = ParsedEvent(title: title, date: date, type: .calendar)
                ev.hasTime = true
                events.append(ev)
            }
        }

        for m in Self.cbCalDateOnlyRegex.matches(in: text, range: range) {
            guard m.numberOfRanges == 3,
                  let dateRange  = Range(m.range(at: 1), in: text),
                  let titleRange = Range(m.range(at: 2), in: text)
            else { continue }
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
            if !title.hasPrefix(":"),
               let date = parseDate(String(text[dateRange])),
               !events.contains(where: { $0.title == title }) {
                events.append(ParsedEvent(title: title, date: date, type: .calendar))
            }
        }

        return events
    }

    // MARK: - Checkbox Reminder Pattern: - [ ] !YYYY-MM-DD 제목 / - [ ] due: YYYY-MM-DD 제목
    private func parseCheckboxReminders(from text: String) -> [ParsedEvent] {
        var reminders: [ParsedEvent] = []
        let range = NSRange(location: 0, length: (text as NSString).length)

        for regex in [Self.cbRemExclamRegex, Self.cbRemDueRegex] {
            for m in regex.matches(in: text, range: range) {
                guard m.numberOfRanges == 3,
                      let dateRange  = Range(m.range(at: 1), in: text),
                      let titleRange = Range(m.range(at: 2), in: text)
                else { continue }
                let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                if let date = parseDate(String(text[dateRange])) {
                    reminders.append(ParsedEvent(title: title, date: date, type: .reminder))
                }
            }
        }

        return reminders
    }

    // MARK: - Date Parsing Helpers
    private func parseDate(_ dateStr: String) -> Date? {
        Self.dateFormatter.date(from: dateStr)
    }

    private func parseDateTime(date dateStr: String, time timeStr: String) -> Date? {
        Self.dateTimeFormatter.date(from: "\(dateStr) \(timeStr)")
    }
}
