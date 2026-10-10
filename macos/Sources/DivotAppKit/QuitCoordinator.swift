import AppKit

/// The single in-app quit path.
///
/// The Divot menu-bar menu, the app's main menu, and the Settings window all
/// funnel here, so there is exactly one way to end the process. Quitting always
/// calls `NSApplication.terminate(_:)`, which lets the application delegate's
/// `applicationWillTerminate` run the normal shutdown — removing the bar,
/// stopping providers, and releasing any keep-awake power assertion.
///
/// The `terminate` and `releasePowerAssertions` hooks are injected so the path
/// can be tested without actually terminating the test runner. The application
/// delegate owns one instance and every quit control shares it.
@MainActor
public final class QuitCoordinator: NSObject {
    private let terminate: @MainActor () -> Void
    private let releasePowerAssertions: @MainActor () -> Void

    public init(terminate: @escaping @MainActor () -> Void = { NSApplication.shared.terminate(nil) },
                releasePowerAssertions: @escaping @MainActor () -> Void = {}) {
        self.terminate = terminate
        self.releasePowerAssertions = releasePowerAssertions
        super.init()
    }

    /// The menu action. Both the main menu and the status item menu target this
    /// selector on the same coordinator, so a menu click is the same path the
    /// Settings button takes.
    @objc public func quit(_ sender: Any?) {
        performQuit()
    }

    /// The Settings button's path, invoked after the shared confirmation dialog.
    public func quit() {
        performQuit()
    }

    private func performQuit() {
        // Drop the power assertion before asking to terminate, so it cannot
        // outlive the process even if termination is deferred. The delegate's
        // `applicationWillTerminate` releases it again, and release is idempotent.
        releasePowerAssertions()
        terminate()
    }
}
