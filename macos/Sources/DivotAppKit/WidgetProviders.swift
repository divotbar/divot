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

    /// The clock's only configuration is its resolution, so a changed `seconds`
    /// option must restart the provider rather than keep the old minute ticker.
    public var activationKey: String { "clock(seconds: \(seconds))" }

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
///
/// Keep-awake (task 0018) rides on the same item, so this provider folds the
/// shared keep-awake state into each snapshot and re-emits when either the power
/// reading or the toggle changes. It never owns the assertion; it only reports
/// what `KeepAwakeController` is holding.
public struct BatteryProvider: WidgetProvider {
    public let id = BarItemID.battery
    private let reading: any BatteryReading
    private let keepAwake: (any KeepAwakeObserving)?

    public init(reading: any BatteryReading,
                keepAwake: (any KeepAwakeObserving)? = nil) {
        self.reading = reading
        self.keepAwake = keepAwake
    }

    /// Battery has no options that change its activation, and the keep-awake
    /// observer is a shared reference, so the key is deliberately identity-free:
    /// a reconfigure that keeps the same providers must not restart the IOKit
    /// observer or drop the assertion state.
    public var activationKey: String { "battery(keepAwake: \(keepAwake != nil))" }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        let reading = self.reading
        let keepAwake = self.keepAwake
        let push: @Sendable () -> Void = {
            let active = keepAwake?.isActive ?? false
            if let snapshot = reading.snapshot() {
                emit(.battery(snapshot.withKeepingAwake(active)))
            } else {
                emit(.unavailable(.init(kind: .failed, message: "Battery state is unavailable")))
            }
        }
        let bag = SubscriptionBag()
        push()
        bag.add(reading.observeChanges { push() })
        if let keepAwake {
            bag.add(keepAwake.observe { _ in push() })
        }
        return bag
    }
}

// MARK: - Network

/// Observes connectivity and optionally the current Wi-Fi network name.
/// `NWPathMonitor` delivers the first path as its first callback, so there is no
/// synchronous current value. The Wi-Fi name is only read when `readWifiName` is
/// true, since it requires location permission; when false, the reading is
/// permission-free and carries no SSID.
public protocol NetworkReading: Sendable {
    func observe(readWifiName: Bool, handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription
}

/// Emits connectivity on path changes. When `readWifiName` is on, the reading
/// attempts to read the current Wi-Fi network name using public APIs; permission
/// is requested only if the user has enabled the feature. When off, no SSID is
/// read and no permission is needed.
public struct NetworkProvider: WidgetProvider {
    public let id = BarItemID.network
    private let reading: any NetworkReading
    private let readWifiName: Bool

    public init(reading: any NetworkReading, readWifiName: Bool = false) {
        self.reading = reading
        self.readWifiName = readWifiName
    }

    /// The provider is recreated when showWifiName changes, so that SSID reading
    /// is only requested when the user has explicitly enabled the feature.
    public var activationKey: String { "network(readWifiName: \(readWifiName))" }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        reading.observe(readWifiName: readWifiName) { snapshot in emit(.network(snapshot)) }
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

// MARK: - Appearance

/// Reads the system appearance and reports changes.
public protocol AppearanceReading: Sendable {
    /// The current appearance mode, or `nil` when it cannot be read this moment.
    func snapshot() -> AppearanceSnapshot?
    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription
}

/// Emits the system appearance on changes.
public struct AppearanceProvider: WidgetProvider {
    public let id = BarItemID.appearance
    private let reading: any AppearanceReading

    public init(reading: any AppearanceReading) { self.reading = reading }

    public func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        let bag = SubscriptionBag()
        let reading = self.reading
        let task = Task { @MainActor in
            let push: @MainActor @Sendable () -> Void = {
                if let snapshot = reading.snapshot() {
                    emit(.appearance(snapshot))
                } else {
                    emit(.unavailable(.init(kind: .failed, message: "Appearance is unavailable")))
                }
            }
            push()
            bag.add(reading.observeChanges { push() })
        }
        bag.add(TaskSubscription(task))
        return bag
    }
}
