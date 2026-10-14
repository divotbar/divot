import Foundation

/// World clock entry: a timezone with its offset and day label relative to local time.
public struct WorldClockEntry: Equatable, Sendable {
    /// IANA timezone identifier (e.g., "America/Los_Angeles").
    public let timezone: String
    /// The city or region name to display.
    public let displayName: String
    /// The time in this timezone.
    public let date: Date
    /// Seconds offset from UTC (positive east, negative west).
    public let offsetSeconds: Int
    /// Day label relative to local time: "Yesterday", "Today", or "Tomorrow".
    /// Nil when the day is the same as local.
    public let dayLabel: String?
    /// Hour offset from local time (can be fractional for half-hour zones).
    public let hourOffset: Double
    /// Minutes since midnight in this zone (0..<1440), for the converted instant.
    /// Lets the row show a day/night marker without re-deriving the wall clock.
    public let localMinutesOfDay: Int
    /// True when the converted instant falls inside the fixed 09:00–18:00 local
    /// working window. Drives the sun/moon marker on the row.
    public let isWorkingHours: Bool

    public init(timezone: String, displayName: String, date: Date, offsetSeconds: Int,
                dayLabel: String?, hourOffset: Double, localMinutesOfDay: Int = 0,
                isWorkingHours: Bool = true) {
        self.timezone = timezone
        self.displayName = displayName
        self.date = date
        self.offsetSeconds = offsetSeconds
        self.dayLabel = dayLabel
        self.hourOffset = hourOffset
        self.localMinutesOfDay = localMinutesOfDay
        self.isWorkingHours = isWorkingHours
    }
}

/// Pure logic for computing world clock entries from a timezone list.
public enum WorldClock {
    /// The zones a first-time user sees before they have configured a list, in
    /// display order (San Francisco, London, Singapore).
    public static let defaultTimezones = ["America/Los_Angeles", "Europe/London", "Asia/Singapore"]

    /// Resolve the stored timezone list into the zones to show.
    ///
    /// An absent list (`nil`) means the user has never configured one, so the
    /// defaults are used — minus the local zone, which the header already shows.
    /// Any stored array (including an empty one) is returned as-is, so an
    /// explicitly emptied list stays empty and the defaults never come back on
    /// their own.
    public static func resolvedTimezones(configured: [String]?,
                                         localTimeZone: TimeZone = .current) -> [String] {
        guard let configured else {
            return defaultTimezones.filter { !isSameZone($0, localTimeZone.identifier) }
        }
        return configured
    }

    /// True when two identifiers name the same zone, following IANA aliases.
    ///
    /// `US/Pacific` and `America/Los_Angeles` are distinct identifiers with the
    /// same rules, and Foundation does not canonicalise them, so compare the
    /// resolved zones instead of the strings: identical standard *and* daylight
    /// offsets (two instants a half-year apart) means the same zone, while a
    /// fixed-offset zone that merely shares the winter offset stays distinct.
    public static func isSameZone(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard let a = TimeZone(identifier: lhs), let b = TimeZone(identifier: rhs) else { return false }
        let winter = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01
        let summer = Date(timeIntervalSince1970: 1_719_792_000) // 2024-07-01
        return a.secondsFromGMT(for: winter) == b.secondsFromGMT(for: winter)
            && a.secondsFromGMT(for: summer) == b.secondsFromGMT(for: summer)
    }

    /// The friendly name to show for a zone: the well-known zones are named by
    /// city (San Francisco for `America/Los_Angeles`), and every other identifier
    /// falls back to its last path segment with underscores as spaces. Kept in one
    /// place so the popover, its search results and the Settings list cannot drift.
    public static func friendlyName(for identifier: String) -> String {
        let friendlyNames: [String: String] = [
            "America/Los_Angeles": "San Francisco",
            "Europe/London": "London",
            "Asia/Singapore": "Singapore"
        ]
        if let name = friendlyNames[identifier] { return name }
        return (identifier.components(separatedBy: "/").last ?? identifier)
            .replacingOccurrences(of: "_", with: " ")
    }

    /// Format a zone's current UTC offset for display beside a name: "UTC+7",
    /// "UTC+5:30", "UTC-3:30", or "UTC+0" for zero. Hours are compact (no leading
    /// zero), minutes are two digits when present, and the sign is always shown.
    /// Kept here so the popover header and the search-result rows cannot drift.
    public static func utcOffsetLabel(forOffsetSeconds offsetSeconds: Int) -> String {
        let sign = offsetSeconds < 0 ? "-" : "+"
        let absOffset = abs(offsetSeconds)
        let hours = absOffset / 3600
        let minutes = (absOffset % 3600) / 60
        if minutes == 0 {
            return "UTC\(sign)\(hours)"
        }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    /// Parse a signed UTC-offset query into an offset in seconds, or `nil` when
    /// the text is not an offset.
    ///
    /// Accepts `+N`/`-N` whole hours, `+N:MM`/`-N:MM` hours and minutes, and
    /// `+N.N`/`-N.N` decimal hours, so `+5:30` and `+5.5` both resolve to
    /// 5 h 30 min (#0098). The sign is required: a bare number never turns a
    /// city-name search into an offset search.
    public static func offsetSeconds(forQuery query: String) -> Int? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sign = trimmed.first, sign == "+" || sign == "-" else { return nil }
        let magnitude = trimmed.dropFirst()
        guard !magnitude.isEmpty else { return nil }

        let seconds: Int
        if magnitude.contains(":") {
            let parts = magnitude.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  !parts[0].isEmpty, parts[0].allSatisfy({ $0.isNumber }),
                  !parts[1].isEmpty, parts[1].allSatisfy({ $0.isNumber }),
                  let hours = Int(parts[0]),
                  let minutes = Int(parts[1]), minutes < 60 else { return nil }
            seconds = hours * 3600 + minutes * 60
        } else if magnitude.contains(".") {
            let parts = magnitude.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  !parts[0].isEmpty, parts[0].allSatisfy({ $0.isNumber }),
                  !parts[1].isEmpty, parts[1].allSatisfy({ $0.isNumber }),
                  let hours = Double("\(parts[0]).\(parts[1])") else { return nil }
            seconds = Int((hours * 3600).rounded())
        } else {
            guard magnitude.allSatisfy({ $0.isNumber }), let hours = Int(magnitude) else { return nil }
            seconds = hours * 3600
        }

        return sign == "-" ? -seconds : seconds
    }

    /// Compute world clock entries for the given timezones.
    ///
    /// - Parameters:
    ///   - timezones: IANA timezone identifiers.
    ///   - at: The reference date (defaults to now).
    ///   - localTimeZone: The local timezone for computing offsets and day labels.
    ///   - calendar: The calendar for day-boundary computation.
    /// - Returns: An ordered array of world clock entries, with invalid timezones dropped.
    public static func entries(for timezones: [String],
                               at referenceDate: Date = Date(),
                               localTimeZone: TimeZone = .current,
                               calendar: Calendar = .current) -> [WorldClockEntry] {
        let allTimeZones = Set(TimeZone.knownTimeZoneIdentifiers)
        let uniqueTimezones = Array(NSOrderedSet(array: timezones)) as? [String] ?? timezones

        var entries: [WorldClockEntry] = []
        for tzString in uniqueTimezones {
            guard allTimeZones.contains(tzString) else {
                continue
            }
            guard let tz = TimeZone(identifier: tzString) else {
                continue
            }

            let displayName = friendlyName(for: tzString)
            let offsetSeconds = tz.secondsFromGMT(for: referenceDate)
            let localOffsetSeconds = localTimeZone.secondsFromGMT(for: referenceDate)
            let diffSeconds = offsetSeconds - localOffsetSeconds
            let hourOffset = Double(diffSeconds) / 3600.0

            var localCalendar = calendar
            localCalendar.timeZone = localTimeZone
            var tzCalendar = calendar
            tzCalendar.timeZone = tz

            // Compare the calendar date in the target zone with the local
            // calendar date, not the absolute elapsed time: an offset can cross
            // midnight in under 24 hours (and a half-hour zone in even less).
            let localDay = localCalendar.dateComponents([.year, .month, .day], from: referenceDate)
            let tzDay = tzCalendar.dateComponents([.year, .month, .day], from: referenceDate)
            let dayDifference: Int
            if let localStart = localCalendar.date(from: localDay),
               let tzStart = localCalendar.date(from: tzDay) {
                dayDifference = localCalendar.dateComponents([.day], from: localStart, to: tzStart).day ?? 0
            } else {
                dayDifference = 0
            }

            let dayLabel: String?
            if dayDifference == 0 {
                dayLabel = nil
            } else if dayDifference == 1 {
                dayLabel = "Tomorrow"
            } else if dayDifference == -1 {
                dayLabel = "Yesterday"
            } else {
                dayLabel = nil
            }

            let localMinutes = WorldClockScrubber.minutesOfDay(of: referenceDate,
                                                              in: tz,
                                                              calendar: calendar)
            let entry = WorldClockEntry(
                timezone: tzString,
                displayName: displayName,
                date: referenceDate,
                offsetSeconds: offsetSeconds,
                dayLabel: dayLabel,
                hourOffset: hourOffset,
                localMinutesOfDay: localMinutes,
                isWorkingHours: WorldClockScrubber.isWorkingHours(referenceDate, in: tz, calendar: calendar)
            )
            entries.append(entry)
        }

        return entries
    }

    /// Format the hour offset as a readable string (e.g., "2 h ahead", "14 h behind", "30 min ahead").
    public static func formatHourOffset(_ offset: Double) -> String {
        let absOffset = abs(offset)
        let direction = offset > 0 ? "ahead" : offset < 0 ? "behind" : "same"

        if offset == 0 {
            return "same time"
        }

        let hours = Int(absOffset)
        let minutes = Int((absOffset - Double(hours)) * 60)

        if hours == 0 {
            return "\(minutes) min \(direction)"
        } else if minutes == 0 {
            return "\(hours) h \(direction)"
        } else {
            return "\(hours) h \(minutes) min \(direction)"
        }
    }
}
