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
}
