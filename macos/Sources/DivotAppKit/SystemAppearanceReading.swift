import AppKit
import DivotCore

/// Reads and writes Divot's appearance override through AppKit's public appearance API.
///
/// This instance controls `NSApp.appearance`, which toggles Divot's light/dark rendering only.
/// It does not change the macOS system appearance (which would require private APIs);
/// it's the app-level override that Divot already supports via configuration.
public final class SystemAppearanceReading: AppearanceReading, @unchecked Sendable {
    private var token: NSObjectProtocol?
    private let lock = NSLock()
    private var changeHandler: (@MainActor @Sendable () -> Void)?

    public init() {}

    nonisolated public func snapshot() -> AppearanceSnapshot? {
        // Read the effective appearance: either the app's override, or the system mode.
        let appearance = DispatchQueue.main.sync {
            NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        }
        let mode: AppearanceMode = appearance == .darkAqua ? .dark : .light
        return AppearanceSnapshot(mode: mode)
    }

    nonisolated public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription {
        lock.withLock { self.changeHandler = handler }

        let token = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in handler() }
        }
        lock.withLock { self.token = token }

        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.withLock {
                if let token = self.token {
                    DistributedNotificationCenter.default().removeObserver(token)
                    self.token = nil
                }
                self.changeHandler = nil
            }
        }
    }

    /// Toggle Divot's appearance between light and dark.
    ///
    /// Sets `NSApp.appearance` to override the effective appearance for Divot's rendering only.
    /// This does not change the macOS system appearance; it's the app-level toggle
    /// that Divot already supports via configuration.
    nonisolated public func toggleAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let current = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
            let newAppearance = current == .darkAqua ? NSAppearance(named: .aqua)! : NSAppearance(named: .darkAqua)!
            NSApp.appearance = newAppearance
            // Notify the provider so the bar item updates immediately.
            self.lock.lock()
            let handler = self.changeHandler
            self.lock.unlock()
            if let handler {
                Task { @MainActor in handler() }
            }
        }
    }

    /// Toggle the macOS system appearance between light and dark.
    ///
    /// Uses AppleScript to set the system appearance through the public API.
    /// This affects the system-wide appearance setting, not just Divot.
    nonisolated public func toggleSystemAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Use AppleScript to toggle macOS system appearance
            let script = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """

            var error: NSDictionary?
            guard let scriptObject = NSAppleScript(source: script) else { return }
            scriptObject.executeAndReturnError(&error)

            // Notify the provider so the bar item updates immediately.
            self.lock.lock()
            let handler = self.changeHandler
            self.lock.unlock()
            if let handler {
                Task { @MainActor in handler() }
            }
        }
    }
}
