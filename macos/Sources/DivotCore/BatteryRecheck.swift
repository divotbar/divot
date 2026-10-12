import Foundation

/// A bounded follow-up window after a power-source notification.
///
/// IOKit's power-source notification can arrive before the charging flag has
/// flipped. On plug-in the system may still report `Is Charging == false` when
/// the notification lands, and no second notification is guaranteed when
/// charging actually begins, so a single read at notification time can miss the
/// bolt until the next percentage change. This window re-reads the power source
/// on a short fixed interval for a bounded number of attempts and then closes,
/// so a lagging flag is caught within about a second without introducing
/// continuous polling.
///
/// The type is deliberately pure: the AppKit layer owns the timer and asks this
/// window whether another re-check is due, so the policy is testable with no
/// real clock or run loop.
public struct BatteryRecheckWindow: Equatable, Sendable {
    /// The fixed interval between re-checks, in seconds.
    public let interval: TimeInterval
    /// The number of re-checks allowed after a notification before the window
    /// closes. `0` disables the bounded follow-up entirely.
    public let maxAttempts: Int
    private var attemptsRemaining: Int

    public init(interval: TimeInterval = 1, maxAttempts: Int = 4) {
        // A zero or negative interval would make the timer fire continuously;
        // clamp to a small positive floor.
        self.interval = max(0.1, interval)
        self.maxAttempts = max(0, maxAttempts)
        self.attemptsRemaining = 0
    }

    /// Arm the window when a power-source notification arrives. A new
    /// notification restarts the bounded window rather than stacking attempts.
    public mutating func notificationArrived() {
        attemptsRemaining = maxAttempts
    }

    /// Whether any re-check remains after the notification.
    public var isActive: Bool { attemptsRemaining > 0 }

    /// Consume one re-check. Returns `true` when the handler should read now.
    public mutating func consume() -> Bool {
        guard attemptsRemaining > 0 else { return false }
        attemptsRemaining -= 1
        return true
    }

    /// Close the window, e.g. when the observer stops.
    public mutating func close() {
        attemptsRemaining = 0
    }
}
