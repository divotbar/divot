import XCTest
@testable import DivotCore

final class WorldClockTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!
    let jakarta = TimeZone(identifier: "Asia/Jakarta")!
    let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    let newYork = TimeZone(identifier: "America/New_York")!
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let kolkata = TimeZone(identifier: "Asia/Kolkata")!

    func testValidTimezones() {
        let timezones = ["America/Los_Angeles", "Asia/Tokyo"]
        let entries = WorldClock.entries(for: timezones)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].displayName, "Los_Angeles")
        XCTAssertEqual(entries[1].displayName, "Tokyo")
    }

    func testInvalidTimezones() {
        let timezones = ["America/Los_Angeles", "Invalid/Timezone", "Asia/Tokyo"]
        let entries = WorldClock.entries(for: timezones)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].timezone, "America/Los_Angeles")
        XCTAssertEqual(entries[1].timezone, "Asia/Tokyo")
    }

    func testEmptyTimezones() {
        let timezones: [String] = []
        let entries = WorldClock.entries(for: timezones)
        XCTAssertEqual(entries.count, 0)
    }

    func testDayLabelSameDay() {
        let date = Date(timeIntervalSince1970: 0)
        let entries = WorldClock.entries(for: ["Asia/Jakarta", "America/Los_Angeles"], at: date, localTimeZone: utc)
        for entry in entries {
            XCTAssertNil(entry.dayLabel)
        }
    }

    func testHourOffsetFormat() {
        XCTAssertEqual(WorldClock.formatHourOffset(0), "same time")
        XCTAssertEqual(WorldClock.formatHourOffset(2), "2 h ahead")
        XCTAssertEqual(WorldClock.formatHourOffset(-14), "14 h behind")
        XCTAssertEqual(WorldClock.formatHourOffset(0.5), "30 min ahead")
        XCTAssertEqual(WorldClock.formatHourOffset(-5.5), "5 h 30 min behind")
    }

    func testHalfHourOffset() {
        // Test with real timezones that have half-hour offsets (e.g., India, Sri Lanka).
        // India Standard Time is UTC+5:30 year-round.
        let testDate = Date(timeIntervalSince1970: 0)
        let localTz = TimeZone(secondsFromGMT: 0)! // UTC
        let entries = WorldClock.entries(for: ["Asia/Calcutta"], at: testDate, localTimeZone: localTz)

        guard let entry = entries.first else {
            XCTFail("Expected one entry for Asia/Calcutta")
            return
        }

        XCTAssertEqual(entry.timezone, "Asia/Calcutta")
        XCTAssertEqual(entry.hourOffset, 5.5, accuracy: 0.01)
    }
}
