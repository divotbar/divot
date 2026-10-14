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
        XCTAssertEqual(entries[0].displayName, "San Francisco")
        XCTAssertEqual(entries[1].displayName, "Tokyo")
    }

    func testFriendlyNamesForDefaultTimezones() {
        let entries = WorldClock.entries(for: ["America/Los_Angeles", "Europe/London", "Asia/Singapore"])
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].displayName, "San Francisco")
        XCTAssertEqual(entries[1].displayName, "London")
        XCTAssertEqual(entries[2].displayName, "Singapore")
    }

    func testResolvedTimezonesUsesDefaultsWhenAbsent() {
        XCTAssertEqual(WorldClock.resolvedTimezones(configured: nil, localTimeZone: jakarta),
                       ["America/Los_Angeles", "Europe/London", "Asia/Singapore"])
    }

    func testResolvedTimezonesDropsTheLocalDefault() {
        // The header already shows the local zone, so it is not repeated as a row.
        XCTAssertEqual(WorldClock.resolvedTimezones(configured: nil, localTimeZone: TimeZone(identifier: "Asia/Singapore")!),
                       ["America/Los_Angeles", "Europe/London"])
    }

    func testResolvedTimezonesKeepsAnExplicitListVerbatim() {
        XCTAssertEqual(WorldClock.resolvedTimezones(configured: [], localTimeZone: jakarta), [],
                       "an explicitly emptied list stays empty")
        XCTAssertEqual(WorldClock.resolvedTimezones(configured: ["Asia/Tokyo"], localTimeZone: jakarta),
                       ["Asia/Tokyo"])
    }

    func testResolvedTimezonesTreatsAnAliasOfTheLocalZoneAsTheLocalZone() {
        // US/Pacific is the same zone as America/Los_Angeles, so the default must
        // not be shown a second time when the local zone is the alias.
        let usPacific = TimeZone(identifier: "US/Pacific")!
        XCTAssertEqual(WorldClock.resolvedTimezones(configured: nil, localTimeZone: usPacific),
                       ["Europe/London", "Asia/Singapore"],
                       "an alias of a default is not duplicated")
    }

    func testIsSameZoneFollowsAliasesButKeepsDifferentZonesApart() {
        XCTAssertTrue(WorldClock.isSameZone("US/Pacific", "America/Los_Angeles"))
        XCTAssertTrue(WorldClock.isSameZone("Asia/Calcutta", "Asia/Kolkata"))
        XCTAssertTrue(WorldClock.isSameZone("Europe/London", "Europe/London"))
        // A fixed-offset zone that shares London's winter offset is not London.
        XCTAssertFalse(WorldClock.isSameZone("Europe/London", "Africa/Abidjan"))
        XCTAssertFalse(WorldClock.isSameZone("America/Los_Angeles", "America/New_York"))
        XCTAssertFalse(WorldClock.isSameZone("Not/AZone", "Europe/London"))
    }

    func testFriendlyNameMappingAndFallback() {
        // The same mapping the popover, its search results and the Settings list
        // use, so the defaults are named by city everywhere.
        XCTAssertEqual(WorldClock.friendlyName(for: "America/Los_Angeles"), "San Francisco")
        XCTAssertEqual(WorldClock.friendlyName(for: "Europe/London"), "London")
        XCTAssertEqual(WorldClock.friendlyName(for: "Asia/Singapore"), "Singapore")
        XCTAssertEqual(WorldClock.friendlyName(for: "America/New_York"), "New York")
        XCTAssertEqual(WorldClock.friendlyName(for: "Asia/Kolkata"), "Kolkata")
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
        // At 1970-01-01T00:00Z, Jakarta (+7) and Tokyo (+9) are the same
        // calendar day as UTC; a west-of-UTC zone would be the previous day.
        let entries = WorldClock.entries(for: ["Asia/Jakarta", "Asia/Tokyo"], at: date, localTimeZone: utc)
        XCTAssertEqual(entries.count, 2)
        for entry in entries {
            XCTAssertNil(entry.dayLabel, "\(entry.timezone) should share the local day")
        }
    }

    func testDayLabelAcrossTheDateLine() {
        // 2026-01-01T10:00Z, local UTC: Kiritimati (+14) is already the next
        // day and Midway (-11) is still the previous day.
        let date = Date(timeIntervalSince1970: 1_767_261_600)
        let entries = WorldClock.entries(for: ["Pacific/Kiritimati", "Pacific/Midway", "Asia/Tokyo", "America/Los_Angeles"],
                                         at: date, localTimeZone: utc)
        XCTAssertEqual(entries[0].dayLabel, "Tomorrow")
        XCTAssertEqual(entries[1].dayLabel, "Yesterday")
        XCTAssertNil(entries[2].dayLabel)
        XCTAssertNil(entries[3].dayLabel)
    }

    func testDayLabelAcrossAMonthBoundary() {
        // 2026-01-31T23:30Z, local UTC: Tokyo (+9) has rolled over into
        // February; Los Angeles (-8) is still January 31.
        let date = Date(timeIntervalSince1970: 1_769_902_200)
        let entries = WorldClock.entries(for: ["Asia/Tokyo", "America/Los_Angeles"], at: date, localTimeZone: utc)
        XCTAssertEqual(entries[0].dayLabel, "Tomorrow")
        XCTAssertNil(entries[1].dayLabel)
    }

    func testDaylightSavingTransitionChangesTheOffset() {
        let winter = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01T00:00Z
        let summer = Date(timeIntervalSince1970: 1_782_864_000) // 2026-07-01T00:00Z
        let winterEntry = WorldClock.entries(for: ["America/New_York"], at: winter, localTimeZone: utc).first
        let summerEntry = WorldClock.entries(for: ["America/New_York"], at: summer, localTimeZone: utc).first
        XCTAssertEqual(winterEntry?.hourOffset, -5)
        XCTAssertEqual(summerEntry?.hourOffset, -4)
    }

    func testDuplicatesAreRemovedAndOrderIsPreserved() {
        let entries = WorldClock.entries(for: ["Asia/Tokyo", "Asia/Tokyo", "America/Los_Angeles"],
                                         at: Date(timeIntervalSince1970: 0), localTimeZone: utc)
        XCTAssertEqual(entries.map(\.timezone), ["Asia/Tokyo", "America/Los_Angeles"])
    }

    func testFortyFiveMinuteOffset() {
        // Chatham Islands are UTC+12:45 in the southern winter (July).
        let winter = Date(timeIntervalSince1970: 1_782_864_000)
        let entries = WorldClock.entries(for: ["Pacific/Chatham"], at: winter, localTimeZone: utc)
        guard let entry = entries.first else {
            XCTFail("Expected one entry for Pacific/Chatham")
            return
        }
        XCTAssertEqual(entry.hourOffset, 12.75, accuracy: 0.01)
        XCTAssertEqual(WorldClock.formatHourOffset(entry.hourOffset), "12 h 45 min ahead")
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

    func testUTCOffsetLabelCoversPositiveNegativeAndZero() {
        XCTAssertEqual(WorldClock.utcOffsetLabel(forOffsetSeconds: 25200), "UTC+7", "positive whole-hour offset")
        XCTAssertEqual(WorldClock.utcOffsetLabel(forOffsetSeconds: 19800), "UTC+5:30", "positive half-hour offset")
        XCTAssertEqual(WorldClock.utcOffsetLabel(forOffsetSeconds: -18000), "UTC-5", "negative whole-hour offset")
        XCTAssertEqual(WorldClock.utcOffsetLabel(forOffsetSeconds: -12600), "UTC-3:30", "negative half-hour offset")
        XCTAssertEqual(WorldClock.utcOffsetLabel(forOffsetSeconds: 0), "UTC+0", "zero offset has an explicit sign")
    }

    func testOffsetQueryParsingCoversWholeHalfAndDecimalHours() {
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "+7"), 25200, "a positive whole hour")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "-8"), -28800, "a negative whole hour")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "+5:30"), 19800, "hours and minutes")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "-3:30"), -12600, "a negative half hour")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "+5.5"), 19800, "a decimal fraction of an hour")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "+5:45"), 20700, "a quarter hour")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "+0"), 0, "zero is accepted")
        XCTAssertEqual(WorldClock.offsetSeconds(forQuery: "  +2  "), 7200, "surrounding whitespace is ignored")
    }

    func testOffsetQueryParsingRejectsNamesAndMalformedText() {
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: "Tokyo"), "a city name is not an offset")
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: "7"), "the sign is required")
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: "+"), "a bare sign is not an offset")
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: "+5:99"), "minutes must be below 60")
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: "UTC+7"), "a prefixed label is not an offset query")
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: "+5:"), "a trailing colon is not an offset")
        XCTAssertNil(WorldClock.offsetSeconds(forQuery: ""), "an empty query is not an offset")
    }

    func testUTCOffsetFormatting() {
        // Test positive offset formatting: UTC+05:30
        let positiveOffset = 19800  // 5.5 hours
        let hours = positiveOffset / 3600
        let minutes = (positiveOffset % 3600) / 60
        let sign = "+"
        let formatted = String(format: "%@%02d:%02d", sign, hours, minutes)
        XCTAssertEqual(formatted, "+05:30")

        // Test negative offset formatting: UTC-03:30
        let negativeOffset = -12600  // -3.5 hours
        let absNegOffset = abs(negativeOffset)
        let negHours = absNegOffset / 3600
        let negMinutes = (absNegOffset % 3600) / 60
        let negSign = "-"
        let negFormatted = String(format: "%@%02d:%02d", negSign, negHours, negMinutes)
        XCTAssertEqual(negFormatted, "-03:30")

        // Test 45-minute offset: UTC+05:45
        let fortyFiveOffset = 20700  // 5.75 hours
        let fhHours = fortyFiveOffset / 3600
        let fhMinutes = (fortyFiveOffset % 3600) / 60
        let fhSign = "+"
        let fhFormatted = String(format: "%@%02d:%02d", fhSign, fhHours, fhMinutes)
        XCTAssertEqual(fhFormatted, "+05:45")
    }
}
