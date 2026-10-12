import Testing
import DivotCore

/// A notification arms a bounded number of re-checks, then the window closes —
/// so a lagging charging flag is caught within a second or two without turning
/// into continuous polling.
@Test func batteryRecheckWindowIsBoundedAfterEachNotification() {
    var window = BatteryRecheckWindow(interval: 1, maxAttempts: 3)
    #expect(!window.isActive)

    window.notificationArrived()
    #expect(window.isActive)
    let first = window.consume()
    let second = window.consume()
    let third = window.consume()
    let extra = window.consume()
    #expect(first)
    #expect(second)
    #expect(third)
    #expect(!extra)
    #expect(!window.isActive)
}

@Test func batteryRecheckWindowRestartsOnANewNotification() {
    var window = BatteryRecheckWindow(interval: 1, maxAttempts: 2)
    window.notificationArrived()
    let initial = window.consume()
    #expect(initial)
    // A second notification restarts the window rather than consuming the old
    // remainder, so a fresh plug event still gets the full bounded follow-up.
    window.notificationArrived()
    let first = window.consume()
    let second = window.consume()
    let extra = window.consume()
    #expect(first)
    #expect(second)
    #expect(!extra)
}

@Test func batteryRecheckWindowCanBeDisabledAndClosed() {
    var disabled = BatteryRecheckWindow(interval: 1, maxAttempts: 0)
    disabled.notificationArrived()
    #expect(!disabled.isActive)
    let disabledConsumed = disabled.consume()
    #expect(!disabledConsumed)

    var window = BatteryRecheckWindow(interval: 1, maxAttempts: 4)
    window.notificationArrived()
    window.close()
    #expect(!window.isActive)
    let closedConsumed = window.consume()
    #expect(!closedConsumed)
}

@Test func batteryRecheckWindowClampsNonPositiveInterval() {
    // A zero interval would make the timer fire continuously; the window keeps
    // a small positive floor instead.
    #expect(BatteryRecheckWindow(interval: 0).interval > 0)
    #expect(BatteryRecheckWindow(interval: -5).interval > 0)
}
