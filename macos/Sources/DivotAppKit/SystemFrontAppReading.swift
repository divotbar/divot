import AppKit
import DivotCore

/// Live frontmost application from `NSWorkspace`.
///
/// `NSWorkspace` and its activation notifications are main-actor, and reading
/// the front app is a cached lookup, not blocking I/O.
@MainActor
public final class NSWorkspaceFrontAppReading: FrontAppReading {
    public init() {}

    public func snapshot() -> FrontAppSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontAppSnapshot(name: app.localizedName ?? "Application",
                                bundleIdentifier: app.bundleIdentifier,
                                processIdentifier: app.processIdentifier)
    }

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription {
        let center = NSWorkspace.shared.notificationCenter
        let token = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                       object: nil,
                                       queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        let box = NotificationTokenBox(token)
        return CallbackSubscription { center.removeObserver(box.token) }
    }
}

/// Wraps a notification token so it can cross into the subscription's
/// `@Sendable` cancel closure.
private final class NotificationTokenBox: @unchecked Sendable {
    let token: any NSObjectProtocol
    init(_ token: any NSObjectProtocol) { self.token = token }
}
