import Foundation

// MARK: - Seam

/// The seam the appearance popover drives through.
///
/// It is deliberately the same configuration source the Settings window edits:
/// reads report the current `appearance` block, writes go through the atomic
/// store, and the observer reports a change made anywhere — the Settings window,
/// the `divot theme` command, or the file watcher — so an open popover never
/// disagrees with the window. The live implementation is
/// `DivotAppKit.ConfigurationController`; tests supply a fake, so the selection
/// rules are asserted without touching the file system.
@MainActor
public protocol AppearanceSettingsControlling: AnyObject {
    /// The current appearance block (family, mode, and the rest).
    var appearance: AppearanceConfiguration { get }

    /// Persist a new System / Light / Dark variant.
    func setAppearanceMode(_ mode: AppearanceConfiguration.Mode)

    /// Persist a new theme family.
    func setAppearanceFamily(_ family: AppearanceConfiguration.Family)

    /// Observe published configuration changes. Removed by `removeObserver`.
    @discardableResult
    func addObserver(_ observer: @escaping (DivotConfiguration) -> Void) -> UUID

    /// Remove a previously registered observer.
    func removeObserver(_ id: UUID)
}

// MARK: - Model

/// Holds the appearance selection the popover renders and routes edits through
/// the seam.
///
/// The popover owns one of these. It reads the current selection when it opens,
/// subscribes to published configuration changes while it is open (so a change
/// made in the Settings window or by the file watcher shows up immediately), and
/// removes that observer when it closes. There is no second copy of the truth:
/// every edit is written through the shared store and read back.
@MainActor
public final class AppearancePopoverModel {
    /// The latest `appearance` block, read back from the shared source.
    public private(set) var appearance: AppearanceConfiguration

    /// Called on the main actor after an external change updates `appearance`,
    /// so a presenter can repaint. Not called for the presenter's own writes.
    public var onChange: (@MainActor () -> Void)?

    private let settings: any AppearanceSettingsControlling
    private var observer: UUID?

    public init(settings: any AppearanceSettingsControlling) {
        self.settings = settings
        self.appearance = settings.appearance
    }

    /// The theme families, taken from the configuration enum so a new family
    /// appears in the popover automatically — never a hand-copied list.
    public var families: [AppearanceConfiguration.Family] {
        AppearanceConfiguration.Family.allCases
    }

    /// The variants, taken from the configuration enum.
    public var modes: [AppearanceConfiguration.Mode] {
        AppearanceConfiguration.Mode.allCases
    }

    public var family: AppearanceConfiguration.Family { appearance.family }
    public var mode: AppearanceConfiguration.Mode { appearance.mode }

    /// Re-read the shared selection. Called when the popover opens.
    public func refresh() {
        appearance = settings.appearance
    }

    /// Subscribe to published changes. Idempotent while open.
    public func startObserving() {
        guard observer == nil else { return }
        observer = settings.addObserver { [weak self] configuration in
            guard let self else { return }
            self.appearance = configuration.appearance
            self.onChange?()
        }
    }

    /// Remove the published-change subscription. Called when the popover closes.
    public func stopObserving() {
        guard let observer else { return }
        settings.removeObserver(observer)
        self.observer = nil
    }

    /// The popover's variant choice. Applies immediately and returns the mode the
    /// store settled on. Re-selecting the current mode is a no-op, so a stray
    /// click on the checked row does not trigger a redundant write.
    @discardableResult
    public func select(_ mode: AppearanceConfiguration.Mode) -> AppearanceConfiguration.Mode {
        guard mode != settings.appearance.mode else { return appearance.mode }
        settings.setAppearanceMode(mode)
        appearance = settings.appearance
        return appearance.mode
    }

    /// The popover's family choice. Applies immediately and returns the family
    /// the store settled on. Re-selecting the current family is a no-op.
    @discardableResult
    public func select(_ family: AppearanceConfiguration.Family) -> AppearanceConfiguration.Family {
        guard family != settings.appearance.family else { return appearance.family }
        settings.setAppearanceFamily(family)
        appearance = settings.appearance
        return appearance.family
    }
}
