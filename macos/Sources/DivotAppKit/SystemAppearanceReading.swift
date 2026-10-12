import AppKit
import DivotCore

/// Reads and writes Divot's appearance override through AppKit's public appearance API.
///
/// This instance controls `NSApp.appearance`, which toggles Divot's light/dark rendering only.
/// It does not change the macOS system appearance (which would require private APIs);
/// it's the app-level override that Divot already supports via configuration.
///
/// `NSApplication`, `NSApp`, and the effective-appearance read are main-actor
/// APIs. The reader is therefore main-actor isolated and touches them directly.
/// An earlier `nonisolated` version reached AppKit through
/// `DispatchQueue.main.sync`; when that call already ran on the main thread —
/// which the provider's initial push and the toggle's change handler both do —
/// libdispatch traps with SIGTRAP and the bar vanished. Following the same
/// pattern as `NSWorkspaceFrontAppReading`, the call is now statically on the
/// main actor instead of dispatching back onto it.
@MainActor
public final class SystemAppearanceReading: AppearanceReading {
    private var changeHandler: (@MainActor @Sendable () -> Void)?
    private var observationGeneration = 0

    public init() {}

    public func snapshot() -> AppearanceSnapshot? {
        let appearance = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        return AppearanceSnapshot(mode: appearance == .darkAqua ? .dark : .light)
    }

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription {
        observationGeneration += 1
        let generation = observationGeneration
        changeHandler = handler
        let center = DistributedNotificationCenter.default()
        let token = center.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { handler() }
        }
        let box = AppearanceNotificationTokenBox(token)
        return CallbackSubscription { [weak self] in
            center.removeObserver(box.token)
            // Cancelling happens off the main actor. Only clear the handler if a
            // newer observation has not already replaced it.
            Task { @MainActor in
                guard let self, self.observationGeneration == generation else { return }
                self.changeHandler = nil
            }
        }
    }

    /// Toggle Divot's appearance between light and dark.
    ///
    /// Sets `NSApplication.shared.appearance` to override the effective appearance
    /// for Divot's rendering only, then notifies the provider so the bar item
    /// updates immediately.
    public func toggleAppearance() {
        let current = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        NSApplication.shared.appearance = current == .darkAqua
            ? NSAppearance(named: .aqua)
            : NSAppearance(named: .darkAqua)
        changeHandler?()
    }
}

/// Wraps a notification token so it can cross into the subscription's
/// `@Sendable` cancel closure.
private final class AppearanceNotificationTokenBox: @unchecked Sendable {
    let token: any NSObjectProtocol
    init(_ token: any NSObjectProtocol) { self.token = token }
}
