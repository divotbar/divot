import AppKit
import DivotCore

/// Reads and writes the app appearance through AppKit's public appearance API.
///
/// This is a single shared instance that observes and controls `NSApp.appearance`,
/// which affects Divot's own rendering. It is not a system-wide appearance toggle
/// (that requires private APIs or AppleScript); it's the app-level appearance override.
public final class SystemAppearanceReading: AppearanceReading, @unchecked Sendable {
    private var token: NSObjectProtocol?
    private let lock = NSLock()

    public init() {}

    nonisolated public func snapshot() -> AppearanceSnapshot? {
        var mode: AppearanceMode = .light
        // Read from NSApp.appearance to get the app's current setting.
        // If nil, the app follows system, so read effectiveAppearance.
        let appearance: NSAppearance.Name
        if let appAppearance = NSApplication.shared.appearance {
            appearance = appAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        } else {
            appearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        }
        mode = appearance == .darkAqua ? .dark : .light
        return AppearanceSnapshot(mode: mode)
    }

    nonisolated public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription {
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
            }
        }
    }

    /// Toggle the app appearance between light and dark.
    ///
    /// Sets `NSApp.appearance` to override the system appearance for Divot's rendering.
    /// This is the app-level override, not a system-wide setting change.
    nonisolated public func toggleAppearance() {
        DispatchQueue.main.async {
            let current = NSApplication.shared.appearance?.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
            let newAppearance = current == .darkAqua ? NSAppearance(named: .aqua)! : NSAppearance(named: .darkAqua)!
            NSApp.appearance = newAppearance
        }
    }
}
