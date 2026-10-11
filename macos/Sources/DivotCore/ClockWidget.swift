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
                              timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template(options))
        return formatter.string(from: snapshot.date)
    }

    /// Format a date snapshot with an optional custom pattern.
    /// If the pattern is invalid, falls back to the default template.
    public static func string(for snapshot: ClockSnapshot,
                              options: ClockFormatOptions = .default,
                              customPattern: String? = nil,
                              locale: Locale = .current,
                              timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        if let pattern = customPattern {
            // Try to use the custom pattern
            formatter.dateFormat = pattern
            // Validate by attempting to format a test date
            if formatter.string(from: Date()) != "" {
                return formatter.string(from: snapshot.date)
            }
        }

        // Fall back to the default template
        formatter.dateFormat = nil
        formatter.setLocalizedDateFormatFromTemplate(template(options))
        return formatter.string(from: snapshot.date)
    }

    /// The unlocalized template handed to `setLocalizedDateFormatFromTemplate`.
    /// Exposed so tests can assert component selection independent of locale.
    static func template(_ options: ClockFormatOptions) -> String {
        var fields: [String] = []
        if options.weekday { fields.append("EEE") }
        if options.date { fields.append("MMMd") }
        fields.append(options.seconds ? "jmms" : "jmm")
        return fields.joined(separator: " ")
    }

    /// Format a time snapshot with optional time format and custom pattern.
    public static func string(for snapshot: ClockSnapshot,
                              options: ClockFormatOptions = .default,
                              locale: Locale = .current,
                              timeZone: TimeZone = .current,
                              timeFormat: TimeConfiguration.Format? = nil,
                              customTimePattern: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        // If custom pattern is provided and valid, use it
        if let pattern = customTimePattern, ClockText.isValidCustomPattern(pattern) {
            formatter.dateFormat = pattern
            return formatter.string(from: snapshot.date)
        }

        // Otherwise use the time format
        if let format = timeFormat {
            let timeTemplate: String
            switch format {
            case .twentyFourHour:
                timeTemplate = options.seconds ? "HHmms" : "HHmm"
            case .ampm:
                timeTemplate = options.seconds ? "jmms" : "jmm"
            case .custom:
                timeTemplate = options.seconds ? "jmms" : "jmm"
            }
            formatter.setLocalizedDateFormatFromTemplate(timeTemplate)
        } else {
            // Fall back to default time template
            formatter.setLocalizedDateFormatFromTemplate(options.seconds ? "jmms" : "jmm")
        }

        return formatter.string(from: snapshot.date)
    }

    /// Validate a custom date format pattern.
    /// Returns `true` if the pattern is valid and produces non-empty output, `false` otherwise.
    public static func isValidPattern(_ pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        // Check if the pattern is not empty and produces a formatted date
        let testDate = Date(timeIntervalSince1970: 0) // 1970-01-01
        let formatted = formatter.string(from: testDate)
        return !formatted.isEmpty && formatted != pattern
    }

    /// Validate a custom time format pattern.
    public static func isValidCustomPattern(_ pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        let testDate = Date(timeIntervalSince1970: 0)
        let formatted = formatter.string(from: testDate)
        return !formatted.isEmpty && formatted != pattern
    }
}
