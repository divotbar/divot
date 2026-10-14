import Foundation

/// Pure, clock-injectable time conversion for the world clock popover.
///
/// The scrubber holds the instant a user is converting *at* — the reference is
/// injected, so it never reads a timer or the network. It owns the 15-minute
/// stepping rule and the fixed working-hours window (09:00–18:00 local) that
/// drives each row's day/night marker, all as plain arithmetic that is unit
/// tested without a real clock or a display.
public struct WorldClockScrubber: Equatable, Sendable {
    /// The fixed granularity of a scrub step, in minutes.
    public static let stepMinutes = 15
    /// The start of the fixed working-hours window, in local minutes of day.
    public static let workingHoursStartMinutes = 9 * 60
    /// The end of the fixed working-hours window (exclusive), in local minutes.
    public static let workingHoursEndMinutes = 18 * 60

    /// The instant the scrubber follows while un-scrubbed, and the value the
    /// "Now" control resets to. Refreshed by the caller on each render so "Now"
    /// always means the current minute.
    public var referenceDate: Date
    /// The local zone the shown time and the working-hours window are measured in.
    public let localTimeZone: TimeZone
    /// The calendar used for wall-clock arithmetic; its timezone is the local one.
    public var calendar: Calendar

    /// The chosen instant, or `nil` while the scrubber still follows "now".
    public private(set) var selectedDate: Date?

    public init(referenceDate: Date,
                localTimeZone: TimeZone = .current,
                calendar: Calendar = .current) {
        var local = calendar
        local.timeZone = localTimeZone
        self.referenceDate = referenceDate
        self.localTimeZone = localTimeZone
        self.calendar = local
        self.selectedDate = nil
    }

    /// True while the scrubber is showing "now" and has not been moved.
    public var isFollowingNow: Bool { selectedDate == nil }

    /// The instant to render: the chosen one, or the reference "now".
    public var shownDate: Date { selectedDate ?? referenceDate }

    /// The shown local time as minutes since local midnight (0..<1440).
    public var shownMinutesOfDay: Int {
        Self.minutesOfDay(of: shownDate, in: localTimeZone, calendar: calendar)
    }

    /// Move the selection by whole 15-minute steps.
    ///
    /// From an instant already on a quarter hour, one step is exactly 15
    /// minutes. From an arbitrary "now", the first step moves to the *adjacent*
    /// quarter hour in the direction pressed (the first press right from 12:07
    /// gives 12:15, not 12:30) and later steps stay on the grid. The arithmetic
    /// is calendar-based, so stepping across a daylight-saving change follows the
    /// zone's real instants rather than assuming a fixed 15 wall-clock minutes.
    public mutating func step(by steps: Int) {
        guard steps != 0 else { return }
        let current = shownDate
        let forward = steps > 0
        if Self.isOnGrid(current, in: localTimeZone, calendar: calendar) {
            selectedDate = calendar.date(byAdding: .minute,
                                         value: steps * Self.stepMinutes,
                                         to: current) ?? current
            return
        }
        // Snapping to the adjacent quarter consumes one of the requested steps.
        let base = Self.snappedToGrid(current, in: localTimeZone, calendar: calendar, forward: forward)
        let remaining = steps - (forward ? 1 : -1)
        selectedDate = calendar.date(byAdding: .minute,
                                     value: remaining * Self.stepMinutes,
                                     to: base) ?? base
    }

    /// Move the selection to an exact local time of day, keeping the local date
    /// of the currently shown instant. Out-of-range values are clamped. Used by
    /// the typed field and the slider's drag, both of which express a time of
    /// day rather than a delta.
    public mutating func setTimeOfDay(hour: Int, minute: Int) {
        let clampedHour = min(max(hour, 0), 23)
        let clampedMinute = min(max(minute, 0), 59)
        var components = calendar.dateComponents([.year, .month, .day], from: shownDate)
        components.hour = clampedHour
        components.minute = clampedMinute
        components.second = 0
        if let date = calendar.date(from: components) {
            selectedDate = date
        }
    }

    /// Return to "now", following `referenceDate` again.
    public mutating func reset() { selectedDate = nil }

    // MARK: - Day/night

    /// Whether `date` falls inside the fixed 09:00–18:00 local working window.
    /// The start is inclusive and the end exclusive, so 09:00 is working and
    /// 18:00 is already outside.
    public static func isWorkingHours(_ date: Date,
                                      in timeZone: TimeZone,
                                      calendar: Calendar = .current) -> Bool {
        let minutes = minutesOfDay(of: date, in: timeZone, calendar: calendar)
        return minutes >= workingHoursStartMinutes && minutes < workingHoursEndMinutes
    }

    /// Local minutes since midnight (0..<1440) for `date` in `timeZone`.
    public static func minutesOfDay(of date: Date,
                                    in timeZone: TimeZone,
                                    calendar: Calendar = .current) -> Int {
        var local = calendar
        local.timeZone = timeZone
        let components = local.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// True when `date` is exactly on a local quarter-hour line (seconds and
    /// sub-second parts dropped).
    static func isOnGrid(_ date: Date,
                         in timeZone: TimeZone,
                         calendar: Calendar = .current) -> Bool {
        var local = calendar
        local.timeZone = timeZone
        let components = local.dateComponents([.minute, .second, .nanosecond], from: date)
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let nanosecond = components.nanosecond ?? 0
        return minute % stepMinutes == 0 && second == 0 && nanosecond == 0
    }

    /// Round `date` to the nearest quarter-hour line of the local wall clock,
    /// dropping seconds. `forward` picks between a later and an earlier line so
    /// the first step moves in the direction the user pressed.
    static func snappedToGrid(_ date: Date,
                              in timeZone: TimeZone,
                              calendar: Calendar = .current,
                              forward: Bool) -> Date {
        var local = calendar
        local.timeZone = timeZone
        var components = local.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let floorMinutes = (minute / stepMinutes) * stepMinutes
        let remainder = minute - floorMinutes
        let snappedMinute: Int
        if remainder == 0 {
            snappedMinute = minute
        } else if forward {
            snappedMinute = floorMinutes + stepMinutes
        } else {
            snappedMinute = floorMinutes
        }
        components.minute = 0
        components.second = 0
        let hourStart = local.date(from: components) ?? date
        return local.date(byAdding: .minute, value: snappedMinute, to: hourStart) ?? date
    }
}
