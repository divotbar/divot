import XCTest
@testable import DivotCore

/// The pure conversion and day/night logic behind the world clock popover's
/// time scrubber: 15-minute stepping, date-line and DST conversions, day labels
/// and the fixed working-hours marker boundaries. No clock, timer or display.
final class WorldClockScrubberTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let newYork = TimeZone(identifier: "America/New_York")!
    private let gregorian = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int, _ minute: Int, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func localComponents(_ date: Date, in timeZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    // MARK: - Stepping

    func testStepFromAGridInstantMovesExactlyFifteenMinutes() {
        let now = date(2026, 6, 1, 12, 0, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        scrubber.step(by: 1)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 12 * 60 + 15)
        scrubber.step(by: 1)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 12 * 60 + 30)
        scrubber.step(by: -2)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 12 * 60)
        XCTAssertEqual(scrubber.shownDate, now)
    }

    func testFirstStepSnapsToTheAdjacentQuarterHour() {
        let now = date(2026, 6, 1, 12, 7, in: newYork)

        var forward = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)
        forward.step(by: 1)
        XCTAssertEqual(forward.shownMinutesOfDay, 12 * 60 + 15, "the first step right lands on the next quarter")

        var backward = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)
        backward.step(by: -1)
        XCTAssertEqual(backward.shownMinutesOfDay, 12 * 60, "the first step left lands on the previous quarter")

        var twoForward = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)
        twoForward.step(by: 2)
        XCTAssertEqual(twoForward.shownMinutesOfDay, 12 * 60 + 30)
    }

    func testSteppingAcrossMidnightRollsTheLocalDate() {
        let now = date(2026, 6, 1, 23, 45, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        scrubber.step(by: 1)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 0)
        let forward = localComponents(scrubber.shownDate, in: newYork)
        XCTAssertEqual(forward.day, 2, "stepping past midnight advances the local date")

        scrubber.step(by: -1)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 23 * 60 + 45)
        let back = localComponents(scrubber.shownDate, in: newYork)
        XCTAssertEqual(back.day, 1, "stepping back rewinds the local date")
    }

    func testStepAcrossSpringForwardSkipsTheMissingHour() {
        // US daylight saving starts 2026-03-08 at 02:00 local; 02:00–02:59 does
        // not exist, so one step from 01:45 lands on 03:00 (not 02:00).
        let now = date(2026, 3, 8, 1, 45, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        XCTAssertEqual(newYork.secondsFromGMT(for: scrubber.shownDate), -5 * 3600)
        scrubber.step(by: 1)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 3 * 60)
        XCTAssertEqual(newYork.secondsFromGMT(for: scrubber.shownDate), -4 * 3600,
                       "the step crosses into daylight time")
    }

    // MARK: - Selection and reset

    func testSetTimeOfDayKeepsTheLocalDate() {
        let now = date(2026, 6, 1, 12, 0, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        scrubber.setTimeOfDay(hour: 20, minute: 45)
        let components = localComponents(scrubber.shownDate, in: newYork)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 20)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 20 * 60 + 45)
    }

    func testSetTimeOfDayClampsOutOfRangeValues() {
        let now = date(2026, 6, 1, 12, 0, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        scrubber.setTimeOfDay(hour: 99, minute: 99)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 23 * 60 + 59)
    }

    func testResetReturnsToNowAndTheFollowingState() {
        let now = date(2026, 6, 1, 9, 3, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        XCTAssertTrue(scrubber.isFollowingNow)
        scrubber.step(by: 1)
        XCTAssertFalse(scrubber.isFollowingNow)
        scrubber.reset()
        XCTAssertTrue(scrubber.isFollowingNow)
        XCTAssertEqual(scrubber.shownDate, now)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 9 * 60 + 3)
    }

    func testAdvancingReferenceFollowsNowUntilScrubbed() {
        let now = date(2026, 6, 1, 9, 0, in: newYork)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: newYork, calendar: gregorian)

        scrubber.referenceDate = date(2026, 6, 1, 9, 30, in: newYork)
        XCTAssertEqual(scrubber.shownMinutesOfDay, 9 * 60 + 30, "un-scrubbed follows the refreshed reference")

        scrubber.step(by: 1)
        let scrubbed = scrubber.shownDate
        scrubber.referenceDate = date(2026, 6, 1, 10, 0, in: newYork)
        XCTAssertEqual(scrubber.shownDate, scrubbed, "a scrubbed instant is not reset by a refresh")
    }

    // MARK: - Day/night markers

    func testWorkingHoursBoundaries() {
        func working(at hour: Int, _ minute: Int) -> Bool {
            WorldClockScrubber.isWorkingHours(date(2026, 6, 1, hour, minute, in: newYork),
                                              in: newYork, calendar: gregorian)
        }

        XCTAssertFalse(working(at: 8, 59), "08:59 is before the window")
        XCTAssertTrue(working(at: 9, 0), "09:00 is inside the window")
        XCTAssertTrue(working(at: 12, 0))
        XCTAssertTrue(working(at: 17, 59), "17:59 is still inside the window")
        XCTAssertFalse(working(at: 18, 0), "18:00 is at the exclusive end")
        XCTAssertFalse(working(at: 23, 0))
        XCTAssertFalse(working(at: 0, 0))
    }

    func testConvertedEntriesMarkWorkingHoursAndCrossTheDateLine() {
        // Local UTC 10:00 on 2026-01-01, the #0085 date-line fixture: Kiritimati
        // (+14) is already tomorrow, Midway (-11) is still yesterday.
        let now = date(2026, 1, 1, 10, 0, in: utc)
        let scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: utc, calendar: gregorian)

        let entries = WorldClock.entries(for: ["Pacific/Kiritimati", "Pacific/Midway", "Europe/London"],
                                         at: scrubber.shownDate,
                                         localTimeZone: utc,
                                         calendar: gregorian)
        XCTAssertEqual(entries[0].dayLabel, "Tomorrow")
        XCTAssertEqual(entries[1].dayLabel, "Yesterday")
        XCTAssertNil(entries[2].dayLabel)

        XCTAssertEqual(entries[0].localMinutesOfDay, 0)
        XCTAssertFalse(entries[0].isWorkingHours, "Kiritimati is at midnight")
        XCTAssertEqual(entries[1].localMinutesOfDay, 23 * 60)
        XCTAssertFalse(entries[1].isWorkingHours, "Midway is at 23:00")
        XCTAssertEqual(entries[2].localMinutesOfDay, 10 * 60)
        XCTAssertTrue(entries[2].isWorkingHours, "London is at 10:00")
    }

    func testScrubbedEntriesChangeTheirWorkingHoursMarker() {
        // A zone in the local working window becomes off-hours once the scrubber
        // moves past 18:00 local.
        let now = date(2026, 6, 1, 10, 0, in: utc)
        var scrubber = WorldClockScrubber(referenceDate: now, localTimeZone: utc, calendar: gregorian)

        let morning = WorldClock.entries(for: ["Europe/London"], at: scrubber.shownDate,
                                         localTimeZone: utc, calendar: gregorian).first
        XCTAssertEqual(morning?.isWorkingHours, true)

        scrubber.setTimeOfDay(hour: 19, minute: 0)
        let evening = WorldClock.entries(for: ["Europe/London"], at: scrubber.shownDate,
                                         localTimeZone: utc, calendar: gregorian).first
        XCTAssertEqual(evening?.isWorkingHours, false)
    }
}
