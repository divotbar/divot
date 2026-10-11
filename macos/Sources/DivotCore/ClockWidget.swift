import Foundation

// MARK: - Scheduling

/// Pure next-boundary math for the minute clock.
///
/// AppKit/Core Audio style polling is deliberately avoided: the provider sleeps
/// until the boundary and emits once. Keeping the arithmetic separate makes the
/// edge cases (already on a boundary, sub-second offsets) testable without a
/// real clock.
public enum ClockSchedule {
    /// Seconds from `date` to the next boundary strictly after it. Minute
    /// resolution by default; second resolution when `seconds` is enabled.
    ///
    /// Boundaries are measured in absolute time, so they never stall on a DST
    /// transition; the local wall-clock rendering is the formatter's job.
    public static func secondsUntilNextBoundary(after date: Date, seconds: Bool) -> TimeInterval {
        let interval = date.timeIntervalSinceReferenceDate
        guard interval.isFinite else { return 60 }
        let unit: Double = seconds ? 1 : 60
        let next = (floor(interval / unit) + 1) * unit
        return next - interval
    }

    /// Seconds from `date` to the next local midnight strictly after it.
    ///
    /// The date item only changes at local midnight, so the date provider sleeps
    /// to the next day boundary instead of waking every minute. Adding a
    /// calendar day to the start of the day also does the right thing across a
    /// daylight-saving change, when a local day is not exactly 24 hours. The
    /// calendar is injected so the arithmetic is deterministic under test.
    public static func secondsUntilNextDayBoundary(after date: Date,
                                                   calendar: Calendar = .current) -> TimeInterval {
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 24 * 60 * 60
        }
        return max(1, nextMidnight.timeIntervalSince(date))
    }
}

// MARK: - Formatting

/// Which components the clock shows. Matches the configuration options for
/// `widgets.clock`; the defaults are the first-launch story's weekday + date +
/// time.
public struct ClockFormatOptions: Equatable, Sendable {
    public var weekday: Bool
    public var date: Bool
    public var seconds: Bool

    public init(weekday: Bool = true, date: Bool = true, seconds: Bool = false) {
        self.weekday = weekday
        self.date = date
        self.seconds = seconds
    }

    public static let `default` = ClockFormatOptions()
}

/// Locale-aware clock text.
///
/// Uses a localized date-format template so field order follows the user's
/// locale, and takes an explicit locale/timezone/calendar so tests are
/// deterministic. The rendering is a pure function of the snapshot.
public enum ClockText {
    public static func string(for snapshot: ClockSnapshot,
                              options: ClockFormatOptions = .default,
                              locale: Locale = .current,
                              timeZone: TimeZone = .current,
                              includeTime: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template(options, includeTime: includeTime))
        var result = formatter.string(from: snapshot.date)
        if !includeTime {
            result = result.replacingOccurrences(of: ",", with: "")
        }
        return result
    }

    /// The unlocalized template handed to `setLocalizedDateFormatFromTemplate`.
    /// Exposed so tests can assert component selection independent of locale.
    static func template(_ options: ClockFormatOptions, includeTime: Bool = true) -> String {
        var fields: [String] = []
        if options.weekday { fields.append("EEE") }
        if options.date { fields.append("MMMd") }
        if includeTime {
            fields.append(options.seconds ? "jmms" : "jmm")
        }
        return fields.joined(separator: " ")
    }
}
