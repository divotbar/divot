import Foundation

// MARK: - Assertion seam

/// Owns one held platform power assertion.
///
/// Releasing is idempotent: the controller may release on toggle-off and again
/// on quit without double-freeing the underlying handle.
public protocol PowerAssertionHandle: Sendable {
    func release()
}

/// Creates platform power assertions.
///
/// This is the injectable seam that keeps the assertion lifecycle testable: the
/// production implementation asks IOKit for the public
/// `PreventUserIdleSystemSleep` / `PreventUserIdleDisplaySleep` assertions, a
/// test double records the calls without touching the machine's power state.
public protocol PowerAssertionCreating: Sendable {
    /// Acquire and hold the assertion(s) for `reason`. Returns `nil` when the
    /// platform refuses (for example, an unsupported assertion type), so the
    /// caller can stay honestly off instead of claiming a state it does not hold.
    func acquireAssertion(reason: String) -> (any PowerAssertionHandle)?
}

/// Reads the shared keep-awake state and reports changes, so a widget provider
/// can fold it into its snapshots without owning the assertion itself.
///
/// This is Divot's own assertion state only: an implementation reports whether
/// Divot created and still holds its assertion (through
/// `PowerAssertionCreating`), never system-wide sleep prevention or another
/// app's assertion. `BatteryProvider` folds it into the battery snapshot to
/// draw the cup, so a system-wide read here would light the cup for unrelated
/// apps such as a call holding the microphone and speaker assertions (#0051).
public protocol KeepAwakeObserving: Sendable {
    var isActive: Bool { get }
    func observe(_ handler: @escaping @Sendable (Bool) -> Void) -> any ProviderSubscription
}

// MARK: - Controller

/// The one owner of the keep-awake power assertion.
///
/// The bar's battery item toggles it through a `WidgetAction`, the provider
/// observes it to refresh its snapshot, and the app releases it on quit. It is
/// thread-safe because the toggle arrives on the main actor while the provider
/// reads it from its own executor.
public final class KeepAwakeController: KeepAwakeObserving, @unchecked Sendable {
    private let creator: any PowerAssertionCreating
    private let reason: String
    private let lock = NSLock()
    private var handle: (any PowerAssertionHandle)?
    private var active = false
    private var observers: [UUID: @Sendable (Bool) -> Void] = [:]

    public init(creator: any PowerAssertionCreating,
                reason: String = "Divot is keeping this Mac awake") {
        self.creator = creator
        self.reason = reason
    }

    public var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return active
    }

    /// Turn keep-awake on or off. Returns `false` when turning on failed because
    /// the platform refused the assertion; the state is left off in that case.
    /// Setting the state it already has is a no-op that still reports success.
    @discardableResult
    public func setActive(_ newValue: Bool) -> Bool {
        lock.lock()
        guard newValue != active else {
            lock.unlock()
            return true
        }
        if newValue {
            guard let created = creator.acquireAssertion(reason: reason) else {
                lock.unlock()
                return false
            }
            handle = created
            active = true
        } else {
            handle?.release()
            handle = nil
            active = false
        }
        let snapshot = active
        let handlers = Array(observers.values)
        lock.unlock()
        for handler in handlers { handler(snapshot) }
        return true
    }

    /// Flip the current state and report the resulting state.
    @discardableResult
    public func toggle() -> Bool { setActive(!isActive) }

    /// Release any held assertion and go off without notifying observers.
    ///
    /// Quit uses this so the process never leaves an assertion behind; it is
    /// deliberately silent because the app is tearing down.
    public func releaseAll() {
        lock.lock()
        let held = handle
        handle = nil
        active = false
        lock.unlock()
        held?.release()
    }

    public func observe(_ handler: @escaping @Sendable (Bool) -> Void) -> any ProviderSubscription {
        let id = UUID()
        lock.lock()
        observers[id] = handler
        lock.unlock()
        return CallbackSubscription { [weak self] in
            self?.removeObserver(id)
        }
    }

    private func removeObserver(_ id: UUID) {
        lock.lock(); observers[id] = nil; lock.unlock()
    }
}
