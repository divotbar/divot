import AppKit
import DivotCore

/// Reads and writes the system appearance through AppKit's public appearance API.
public final class SystemAppearanceReading: AppearanceReading, @unchecked Sendable {
    private var token: NSObjectProtocol?
    private let lock = NSLock()

    public init() {}

    nonisolated public func snapshot() -> AppearanceSnapshot? {
        var mode: AppearanceMode = .light
        let appearance = DispatchQueue.main.sync {
            NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
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
            handler()
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

    /// Toggle the system appearance between light and dark.
    nonisolated public func toggleAppearance() {
        DispatchQueue.main.async {
            let appearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
            let newAppearance = appearance == .darkAqua ? NSAppearance(named: .aqua)! : NSAppearance(named: .darkAqua)!
            NSAppearance.current = newAppearance
        }
    }
}
