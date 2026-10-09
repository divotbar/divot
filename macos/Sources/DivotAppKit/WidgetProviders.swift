import Foundation
import DivotCore

// MARK: - Clock

/// A clock source so the minute loop is testable without waiting.
public protocol ClockSource: Sendable {
    func now() -> Date
    /// Sleep for `seconds`. Throwing ends the loop (cancellation).
    func sleep(seconds: TimeInterval) async throws
}

/// The real system clock.
public struct SystemClockSource: ClockSource {
    public init() {}
    public func now() -> Date { Date() }
    public func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(max(0, seconds)))
    }
}

/// Emits the local time immediately, then at each boundary.
///
/// A minute clock by default (the boundary math lives in `DivotCore`), so the
/// process is woken about once a minute and never runs a render loop. The loop
/// runs in a detached task: the clock is a pure value read, not main-thread I/O.
public struct ClockProvider: WidgetProvider {
    public let id = BarItemID.clock
    private let seconds: Bool
    private let source: any ClockSource

    public init(seconds: Bool = false, source: any ClockSource = SystemClockSource()) {
        self.seconds = seconds
        self.source = source
    }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        let source = self.source
        let seconds = self.seconds
        let task = Task.detached {
            emit(.clock(ClockSnapshot(date: source.now())))
            while !Task.isCancelled {
                let delay = ClockSchedule.secondsUntilNextBoundary(after: source.now(), seconds: seconds)
                do {
                    try await source.sleep(seconds: delay)
                } catch {
                    break
                }
                if Task.isCancelled { break }
                emit(.clock(ClockSnapshot(date: source.now())))
            }
        }
        return TaskSubscription(task)
    }
}

// MARK: - Front app

/// Reads the frontmost application. Main-actor only: `NSWorkspace` and its
/// notifications belong there, and reading the front app is a cheap cached
/// lookup, not blocking I/O.
@MainActor
public protocol FrontAppReading: Sendable {
    func snapshot() -> FrontAppSnapshot?
    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription
}

/// Emits the frontmost app on activation changes.
public struct FrontAppProvider: WidgetProvider {
    public let id = BarItemID.frontApp
    private let reading: any FrontAppReading

    public init(reading: any FrontAppReading) { self.reading = reading }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        let bag = SubscriptionBag()
        let reading = self.reading
        let task = Task { @MainActor in
            let push: @MainActor @Sendable () -> Void = {
                if let snapshot = reading.snapshot() {
                    emit(.frontApp(snapshot))
                } else {
                    emit(.unavailable(.init(kind: .noData, message: "No frontmost application")))
                }
            }
            push()
            bag.add(reading.observeChanges { push() })
        }
        bag.add(TaskSubscription(task))
        return bag
    }
}

// MARK: - Battery

/// Reads power state and reports changes.
public protocol BatteryReading: Sendable {
    /// The current state, or `nil` when it cannot be read this moment.
    func snapshot() -> BatterySnapshot?
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription
}

/// Emits the power state and every change. A desktop Mac reports a settled
/// no-battery state, not an error.
public struct BatteryProvider: WidgetProvider {
    public let id = BarItemID.battery
    private let reading: any BatteryReading

    public init(reading: any BatteryReading) { self.reading = reading }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        let reading = self.reading
        let push: @Sendable () -> Void = {
            if let snapshot = reading.snapshot() {
                emit(.battery(snapshot))
            } else {
                emit(.unavailable(.init(kind: .failed, message: "Battery state is unavailable")))
            }
        }
        push()
        return reading.observeChanges { push() }
    }
}

// MARK: - Network

/// Observes connectivity. `NWPathMonitor` delivers the first path as its first
/// callback, so there is no synchronous current value.
public protocol NetworkReading: Sendable {
    func observe(_ handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription
}

/// Emits connectivity on path changes. It carries no SSID or other
/// location-gated detail, so it never needs an extra permission.
public struct NetworkProvider: WidgetProvider {
    public let id = BarItemID.network
    private let reading: any NetworkReading

    public init(reading: any NetworkReading) { self.reading = reading }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        reading.observe { snapshot in emit(.network(snapshot)) }
    }
}

// MARK: - Volume

/// Reads output volume and mute state and reports changes.
public protocol VolumeReading: Sendable {
    func snapshot() -> VolumeSnapshot?
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription
}

/// Emits output volume and mute changes, with a no-output state when every
/// device is gone.
public struct VolumeProvider: WidgetProvider {
    public let id = BarItemID.volume
    private let reading: any VolumeReading

    public init(reading: any VolumeReading) { self.reading = reading }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        let reading = self.reading
        let push: @Sendable () -> Void = {
            if let snapshot = reading.snapshot() {
                emit(.volume(snapshot))
            } else {
                emit(.unavailable(.init(kind: .failed, message: "Output volume is unavailable")))
            }
        }
        push()
        return reading.observeChanges { push() }
    }
}
