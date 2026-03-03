import SwiftUI

struct MiniCalendarView: View {
    @Binding var selectedDate: Date
    var noteDates: Set<Date> = []

    @State private var displayMonth: Date = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: NoCalTheme.spacing8) {
            monthHeader
            weekdayHeader
            daysGrid
        }
        .padding(.horizontal, NoCalTheme.spacing4)
    }

    // MARK: - Month Navigation Header
    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(displayMonth, format: .dateTime.month(.wide).year())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Weekday Labels
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Days Grid
    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(calendarDays.indices, id: \.self) { index in
                if let date = calendarDays[index] {
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasNote: hasNote(on: date)
                    )
                    .onTapGesture { selectedDate = date }
                } else {
                    Color.clear.frame(height: 28)
                }
            }
        }
    }

    // MARK: - Helpers
    private func changeMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayMonth) {
            displayMonth = newMonth
        }
    }

    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayMonth) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 0..<daysInMonth {
            days.append(calendar.date(byAdding: .day, value: day, to: firstDay))
        }
        // Pad last row
        let remainder = days.count % 7
        if remainder != 0 {
            days.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return days
    }

    private func hasNote(on date: Date) -> Bool {
        noteDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
}

// MARK: - Day Cell
private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasNote: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Selected background
            if isSelected {
                Circle()
                    .fill(Color.noCalAccent)
                    .padding(1)
            } else if isToday {
                Circle()
                    .fill(Color.noCalAccent.opacity(0.15))
                    .padding(1)
            }

            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.calendarDay)
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? Color.noCalAccent :
                        .primary
                    )
                    .fontWeight(isToday ? .semibold : .regular)

                // Note dot
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.7) : Color.noCalAccent)
                    .frame(width: 4, height: 4)
                    .opacity(hasNote ? 1 : 0)
            }
        }
        .frame(height: 32)
    }
}

#Preview {
    MiniCalendarView(
        selectedDate: .constant(Date()),
        noteDates: [Date(), Calendar.current.date(byAdding: .day, value: -2, to: Date())!]
    )
    .padding()
    .frame(width: 240)
}
