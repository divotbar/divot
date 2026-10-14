import Foundation

// MARK: - Toast state

/// The keep-awake toast that appears when the user toggles caffeine.
public struct KeepAwakeToastState: Equatable, Sendable {
    /// Whether caffeine is on (true) or off (false).
    public let isActive: Bool
    /// When the toast was shown.
    public let shownAt: Date

    public init(isActive: Bool, shownAt: Date = .now) {
        self.isActive = isActive
        self.shownAt = shownAt
    }

    /// The main text for the toast.
    public var mainText: String {
        isActive ? "Caffeine on" : "Caffeine off"
    }

    /// Optional subtext for the toast.
    public var subtext: String {
        isActive ? "Your Mac will stay awake" : "Your Mac can sleep"
    }

    /// The color role for the accent (the dot/bar and heading text).
    public var colorRole: ColorRole {
        isActive ? .active : .inactive
    }

    /// The color role for the toast. Green for on, red for off.
    public enum ColorRole: Equatable, Sendable {
        case active
        case inactive
    }
}

// MARK: - Controller

/// Owns the keep-awake toast lifecycle: when to show, what to show, and when to dismiss.
///
/// The model is responsible for the logic (text, color, duration, replacement, suppression
/// at launch); presentation is handled by an injectable presenter in the AppKit layer so
/// tests never put a real window on screen.
public final class KeepAwakeToastController: @unchecked Sendable {
    private let lock = NSLock()
    private var currentToast: KeepAwakeToastState?
    private var dismissalTimer: Timer?
    private var observers: [UUID: @Sendable (KeepAwakeToastState?) -> Void] = [:]

    /// The duration a toast stays visible before auto-dismissing. Configured here
    /// so tests can override it.
    public var dismissalDuration: TimeInterval = 2.0

    public init() {}

    /// The currently shown toast, or nil if none is showing.
    public var current: KeepAwakeToastState? {
        lock.lock(); defer { lock.unlock() }
        return currentToast
    }

    /// Show a toast with the given state. Replaces any existing toast immediately.
    public func showToast(isActive: Bool) {
        lock.lock()
        let toast = KeepAwakeToastState(isActive: isActive)
        currentToast = toast
        dismissalTimer?.invalidate()
        dismissalTimer = nil
        let handlers = Array(observers.values)
        let newToast = toast
        lock.unlock()

        notifyObservers(handlers, toast: newToast)

        // Schedule dismissal on the main run loop (toggle runs on the main actor).
        let timer = Timer.scheduledTimer(withTimeInterval: dismissalDuration, repeats: false) { [weak self] _ in
            self?.dismissToast()
        }
        lock.lock()
        dismissalTimer = timer
        lock.unlock()
    }

    /// Dismiss any shown toast immediately without triggering observers.
    /// Used when the app quits or the toast is being replaced.
    public func dismissToast() {
        lock.lock()
        dismissalTimer?.invalidate()
        dismissalTimer = nil
        guard currentToast != nil else {
            lock.unlock()
            return
        }
        currentToast = nil
        let handlers = Array(observers.values)
        lock.unlock()

        notifyObservers(handlers, toast: nil)
    }

    private func notifyObservers(_ handlers: [@Sendable (KeepAwakeToastState?) -> Void],
                                 toast: KeepAwakeToastState?) {
        let deliver = {
            for handler in handlers { handler(toast) }
        }
        if Thread.isMainThread {
            deliver()
        } else {
            DispatchQueue.main.async(execute: deliver)
        }
    }

    /// Observe changes to the toast state. Returns a subscription that can be cancelled.
    public func observe(_ handler: @escaping @Sendable (KeepAwakeToastState?) -> Void) -> any ProviderSubscription {
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

    /// Release all resources and dismiss any shown toast. Called on quit.
    public func releaseAll() {
        lock.lock()
        dismissalTimer?.invalidate()
        dismissalTimer = nil
        currentToast = nil
        observers.removeAll()
        lock.unlock()
    }
}
