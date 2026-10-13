import Foundation

/// A month/year pair for calendar navigation.
public struct CalendarMonth: Equatable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = max(1, min(12, month))
    }

    /// Create a CalendarMonth for the current month.
    public static func today(calendar: Calendar = .current) -> CalendarMonth {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return CalendarMonth(year: components.year ?? 2024, month: components.month ?? 1)
    }

    /// Move forward by one month.
    public func next() -> CalendarMonth {
        if month == 12 {
            return CalendarMonth(year: year + 1, month: 1)
        }
        return CalendarMonth(year: year, month: month + 1)
    }

    /// Move backward by one month.
    public func previous() -> CalendarMonth {
        if month == 1 {
            return CalendarMonth(year: year - 1, month: 12)
        }
        return CalendarMonth(year: year, month: month - 1)
    }

    /// Convert to a Date at the start of this month.
    public func startDate(calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return calendar.date(from: components) ?? Date()
    }
}

/// A day in a calendar month, which may be from an adjacent month.
public struct CalendarDay: Equatable, Sendable {
    /// The day of the month (1–31).
    public let day: Int
    /// Whether this day belongs to the displayed month (true) or an adjacent month (false).
    public let isCurrentMonth: Bool
    /// The full date for this day.
    public let date: Date

    public init(day: Int, isCurrentMonth: Bool, date: Date) {
        self.day = day
        self.isCurrentMonth = isCurrentMonth
        self.date = date
    }
}

/// Layout for a calendar month: weeks of days, padded with adjacent-month days.
public struct CalendarMonthLayout: Equatable, Sendable {
    /// The month/year this layout represents.
    public let month: CalendarMonth
    /// The weeks: each subarray is exactly 7 days, starting on the locale's first weekday.
    public let weeks: [[CalendarDay]]
    /// The weekday names (Sun–Sat or Mon–Sun, depending on locale), starting from the
    /// calendar's first weekday.
    public let weekdayNames: [String]
    /// The full localized month/year string.
    public let monthYearString: String

    public init(month: CalendarMonth, weeks: [[CalendarDay]], weekdayNames: [String], monthYearString: String) {
        self.month = month
        self.weeks = weeks
        self.weekdayNames = weekdayNames
        self.monthYearString = monthYearString
    }

    /// Create the layout for a given month.
    public static func `for`(_ month: CalendarMonth,
                             calendar: Calendar = .current,
                             locale: Locale = .current) -> CalendarMonthLayout {
        let startDate = month.startDate(calendar: calendar)
        let components = calendar.dateComponents([.weekday], from: startDate)
        let firstWeekday = calendar.firstWeekday

        let daysInMonth = calendar.range(of: .day, in: .month, for: startDate)?.count ?? 28
        var leadingDays = (components.weekday ?? firstWeekday) - firstWeekday
        if leadingDays < 0 { leadingDays += 7 }

        var days: [CalendarDay] = []

        if leadingDays > 0 {
            let prevMonth = month.previous()
            let prevMonthStart = month.startDate(calendar: calendar)
            let prevMonthEnd = calendar.range(of: .day, in: .month, for: prevMonth.startDate(calendar: calendar))?.count ?? 28
            let prevMonthStartDay = prevMonthEnd - leadingDays + 1
            for i in prevMonthStartDay...prevMonthEnd {
                let date = calendar.date(bySetting: .day, value: i, of: prevMonth.startDate(calendar: calendar))!
                days.append(CalendarDay(day: i, isCurrentMonth: false, date: date))
            }
        }

        for day in 1...daysInMonth {
            let date = calendar.date(bySetting: .day, value: day, of: startDate)!
            days.append(CalendarDay(day: day, isCurrentMonth: true, date: date))
        }

        let totalCells = leadingDays + daysInMonth
        let trailingDays = (7 - (totalCells % 7)) % 7
        for day in 1...trailingDays {
            let nextMonth = month.next()
            let date = calendar.date(bySetting: .day, value: day, of: nextMonth.startDate(calendar: calendar))!
            days.append(CalendarDay(day: day, isCurrentMonth: false, date: date))
        }

        let weeks = stride(from: 0, to: days.count, by: 7).map { i in
            Array(days[i..<min(i + 7, days.count)])
        }

        let weekdayNames = weekdaySymbols(calendar: calendar, locale: locale, firstWeekday: firstWeekday)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMMM yyyy"
        let monthYearString = formatter.string(from: startDate)

        return CalendarMonthLayout(month: month, weeks: weeks, weekdayNames: weekdayNames, monthYearString: monthYearString)
    }

    /// Get the weekday symbols starting from the calendar's first weekday.
    private static func weekdaySymbols(calendar: Calendar, locale: Locale, firstWeekday: Int) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.shortWeekdaySymbols ?? []
        if symbols.isEmpty { return [] }
        let adjusted = (firstWeekday - 1) % symbols.count
        return Array(symbols[adjusted...]) + Array(symbols[..<adjusted])
    }
}

/// Check if a date is today.
public func isToday(_ date: Date, calendar: Calendar = .current) -> Bool {
    let today = calendar.startOfDay(for: Date())
    let day = calendar.startOfDay(for: date)
    return today == day
}
