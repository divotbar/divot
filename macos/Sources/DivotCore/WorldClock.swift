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

    public init(timezone: String, displayName: String, date: Date, offsetSeconds: Int, dayLabel: String?, hourOffset: Double) {
        self.timezone = timezone
        self.displayName = displayName
        self.date = date
        self.offsetSeconds = offsetSeconds
        self.dayLabel = dayLabel
        self.hourOffset = hourOffset
    }
}

/// Pure logic for computing world clock entries from a timezone list.
public enum WorldClock {
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

        var entries: [WorldClockEntry] = []
        for tzString in timezones {
            guard allTimeZones.contains(tzString) else {
                continue
            }
            guard let tz = TimeZone(identifier: tzString) else {
                continue
            }

            let displayName = tzString.components(separatedBy: "/").last ?? tzString
            let offsetSeconds = tz.secondsFromGMT(for: referenceDate)
            let localOffsetSeconds = localTimeZone.secondsFromGMT(for: referenceDate)
            let diffSeconds = offsetSeconds - localOffsetSeconds
            let hourOffset = Double(diffSeconds) / 3600.0

            var localCalendar = calendar
            localCalendar.timeZone = localTimeZone
            let localDay = localCalendar.component(.day, from: referenceDate)
            let localMonth = localCalendar.component(.month, from: referenceDate)
            let localYear = localCalendar.component(.year, from: referenceDate)

            var tzCalendar = calendar
            tzCalendar.timeZone = tz
            let tzDay = tzCalendar.component(.day, from: referenceDate)
            let tzMonth = tzCalendar.component(.month, from: referenceDate)
            let tzYear = tzCalendar.component(.year, from: referenceDate)

            let dayLabel: String?
            if tzYear == localYear && tzMonth == localMonth {
                if tzDay == localDay {
                    dayLabel = nil
                } else if tzDay == localDay + 1 {
                    dayLabel = "Tomorrow"
                } else if tzDay == localDay - 1 {
                    dayLabel = "Yesterday"
                } else {
                    dayLabel = nil
                }
            } else {
                dayLabel = nil
            }

            let entry = WorldClockEntry(
                timezone: tzString,
                displayName: displayName,
                date: referenceDate,
                offsetSeconds: offsetSeconds,
                dayLabel: dayLabel,
                hourOffset: hourOffset
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
