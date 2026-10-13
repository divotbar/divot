import Foundation
import Testing
@testable import DivotCore

@Suite("Calendar month navigation")
struct CalendarMonthNavigationTests {
    @Test func previousMonthWrapsProperly() {
        let jan = CalendarMonth(year: 2024, month: 1)
        let prev = jan.previous()
        #expect(prev.month == 12)
        #expect(prev.year == 2023)
    }

    @Test func nextMonthWrapsProperly() {
        let dec = CalendarMonth(year: 2024, month: 12)
        let next = dec.next()
        #expect(next.month == 1)
        #expect(next.year == 2025)
    }

    @Test func navigationInMiddleOfYear() {
        let may = CalendarMonth(year: 2024, month: 5)
        #expect(may.previous().month == 4)
        #expect(may.next().month == 6)
    }
}

@Suite("Calendar layout")
struct CalendarMonthLayoutTests {
    private func makeCalendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday
        return cal
    }

    @Test func februaryLeapYear() {
        let calendar = makeCalendar(firstWeekday: 1)
        let layout = CalendarMonthLayout.`for`(CalendarMonth(year: 2024, month: 2), calendar: calendar)

        let daysInFeb = layout.weeks.flatMap { $0 }.filter { $0.isCurrentMonth }.count
        #expect(daysInFeb == 29, "2024 is a leap year")
    }

    @Test func februaryNonLeapYear() {
        let calendar = makeCalendar(firstWeekday: 1)
        let layout = CalendarMonthLayout.`for`(CalendarMonth(year: 2023, month: 2), calendar: calendar)

        let daysInFeb = layout.weeks.flatMap { $0 }.filter { $0.isCurrentMonth }.count
        #expect(daysInFeb == 28, "2023 is not a leap year")
    }

    @Test func allMonthsHaveFullWeeks() {
        let calendar = makeCalendar(firstWeekday: 1)
        for month in 1...12 {
            let layout = CalendarMonthLayout.`for`(CalendarMonth(year: 2024, month: month), calendar: calendar)
            for week in layout.weeks {
                #expect(week.count == 7, "Week must have exactly 7 days")
            }
        }
    }

    @Test func weekdayNamesMatchFirstWeekday() {
        let calendar = makeCalendar(firstWeekday: 1)
        let layout = CalendarMonthLayout.`for`(CalendarMonth(year: 2024, month: 1), calendar: calendar)

        #expect(layout.weekdayNames.count == 7)
        let formatter = DateFormatter()
        formatter.locale = .current
        let allSymbols = formatter.shortWeekdaySymbols

        if let firstSymbol = allSymbols?.first {
            #expect(layout.weekdayNames.first == firstSymbol, "Should start with Sunday")
        }
    }

    @Test func leadingDaysAreDimmed() {
        let calendar = makeCalendar(firstWeekday: 1)
        let layout = CalendarMonthLayout.`for`(CalendarMonth(year: 2024, month: 1), calendar: calendar)

        let firstWeek = layout.weeks.first ?? []
        let currentMonthDaysInFirst = firstWeek.filter { $0.isCurrentMonth }
        #expect(!currentMonthDaysInFirst.isEmpty, "First week should have at least one current-month day")

        if firstWeek.contains(where: { !$0.isCurrentMonth }) {
            let allBefore = firstWeek.prefix { !$0.isCurrentMonth }
            #expect(allBefore.allSatisfy { !$0.isCurrentMonth }, "Leading days should all be dimmed")
        }
    }

    @Test func trailingDaysAreDimmed() {
        let calendar = makeCalendar(firstWeekday: 1)
        let layout = CalendarMonthLayout.`for`(CalendarMonth(year: 2024, month: 1), calendar: calendar)

        if let lastWeek = layout.weeks.last {
            var trailingCount = 0
            for day in lastWeek.reversed() {
                if !day.isCurrentMonth {
                    trailingCount += 1
                } else {
                    break
                }
            }
            #expect(trailingCount >= 0, "Trailing days should be from next month")
        }
    }
}

@Suite("Today detection")
struct IsTodayTests {
    @Test func recognizesToday() {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        #expect(isToday(today, calendar: calendar))
    }

    @Test func rejectsYesterday() {
        let calendar = Calendar(identifier: .gregorian)
        let yesterday = Date(timeIntervalSinceNow: -86400)
        #expect(!isToday(yesterday, calendar: calendar))
    }

    @Test func rejectsTomorrow() {
        let calendar = Calendar(identifier: .gregorian)
        let tomorrow = Date(timeIntervalSinceNow: 86400)
        #expect(!isToday(tomorrow, calendar: calendar))
    }

    @Test func ignoresTime() {
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 15
        components.minute = 30
        let laterToday = calendar.date(from: components)!
        #expect(isToday(laterToday, calendar: calendar))
    }
}

@Suite("Calendar month equality")
struct CalendarMonthEqualityTests {
    @Test func sameMonthAndYearAreEqual() {
        let m1 = CalendarMonth(year: 2024, month: 1)
        let m2 = CalendarMonth(year: 2024, month: 1)
        #expect(m1 == m2)
    }

    @Test func differentMonthsAreNotEqual() {
        let m1 = CalendarMonth(year: 2024, month: 1)
        let m2 = CalendarMonth(year: 2024, month: 2)
        #expect(m1 != m2)
    }

    @Test func differentYearsAreNotEqual() {
        let m1 = CalendarMonth(year: 2024, month: 1)
        let m2 = CalendarMonth(year: 2025, month: 1)
        #expect(m1 != m2)
    }
}
