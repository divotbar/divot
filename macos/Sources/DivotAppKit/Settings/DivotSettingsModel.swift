import AppKit
import DivotCore
import Foundation
import Observation

/// View model for the settings window.
///
/// Every edit goes through `ConfigurationController`, so the window edits the
/// same validated model as the file and never keeps a second copy of the truth.
/// An invalid edit is refused and reported; the bar keeps its last good
/// configuration.
@MainActor
@Observable
public final class DivotSettingsModel {
    public private(set) var configuration: DivotConfiguration
    /// The field error from the most recent refused edit or bad file.
    public private(set) var errorMessage: String?
    /// Launch-at-login state, mirrored from the system so the toggle is honest.
    public private(set) var loginItemEnabled: Bool
    public private(set) var loginItemStatus: String
    /// Installed font families, sorted, for the bar font picker. The system
    /// default is offered separately as an empty selection.
    public let availableFontFamilies: [String]
    /// Current location authorization status for showing Wi-Fi name.
    public private(set) var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined

    private let controller: ConfigurationController
    private let loginItem: LoginItemControlling
    /// Reads the live keep-awake state so the "remember" toggle can capture the
    /// state it is being asked to remember. Kept as a closure rather than the
    /// controller so the model does not own power state.
    private let keepAwakeIsActive: () -> Bool
    /// The single quit path shared with the menu-bar menu. Kept as a closure so
    /// the model never owns the application lifecycle and a test can observe it.
    private let requestQuit: () -> Void
    private let locationTracker: LocationAuthorizationTracker
    private var locationSubscription: (any ProviderSubscription)?

    public init(controller: ConfigurationController,
                loginItem: LoginItemControlling = SMAppServiceLoginItem(),
                keepAwakeIsActive: @escaping () -> Bool = { false },
                requestQuit: @escaping () -> Void = {},
                locationTracker: LocationAuthorizationTracker = LocationAuthorizationTracker()) {
        self.controller = controller
        self.loginItem = loginItem
        self.keepAwakeIsActive = keepAwakeIsActive
        self.requestQuit = requestQuit
        self.locationTracker = locationTracker
        self.configuration = controller.configuration
        self.errorMessage = controller.lastError?.description
        self.loginItemEnabled = loginItem.isEnabled
        self.loginItemStatus = loginItem.statusDescription
        self.availableFontFamilies = BarFont.installedFamilies()
        self.locationAuthorizationStatus = locationTracker.currentStatus()

        // Keep the window in step with external edits (the file watcher) and with
        // the bar's own reloads. Values are equal after our own save, so this is
        // idempotent; there is no second copy of the truth.
        controller.addObserver { [weak self] configuration in
            self?.configuration = configuration
            self?.errorMessage = nil
        }

        // Observe location authorization status changes without requesting.
        locationSubscription = locationTracker.observeAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.locationAuthorizationStatus = status
            }
        }
    }

    /// The file the settings edit, shown so a power user can open it directly.
    public var configPath: String { controller.configURL.path }

    /// The theme the bar will actually draw, resolved from the current family,
    /// mode, accent, and palette overrides against the live effective appearance.
    public var resolvedTheme: ResolvedTheme {
        let dark = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return ThemeResolver.resolve(configuration.appearance, dark: dark)
    }

    /// The accent the bar will use: a palette override, else an explicit root
    /// accent, else the family's signature color.
    public var resolvedAccentHex: String {
        resolvedTheme.tokens?.accent.hexString ?? configuration.appearance.effectiveAccent
    }

    /// A one-line attribution for the selected family variant, or an honest
    /// "follows macOS" note for the native default.
    public var themeSourceLine: String {
        guard let attribution = resolvedTheme.attribution else {
            return "Native follows macOS appearance and the system accent."
        }
        let official = attribution.isOfficialVariant ? "official \(attribution.variantName)" : attribution.variantName
        return "\(attribution.familyName) · \(official) · \(attribution.source) (\(attribution.license))"
    }

    /// Re-read the shared snapshot (e.g. when the window is reopened after an
    /// external file change).
    public func refresh() {
        configuration = controller.configuration
        errorMessage = controller.lastError?.description
        loginItemEnabled = loginItem.isEnabled
        loginItemStatus = loginItem.statusDescription
    }

    /// Apply a settings edit through the shared store.
    public func update(_ mutate: (inout DivotConfiguration) -> Void) {
        switch controller.update(mutate) {
        case .success(let configuration):
            self.configuration = configuration
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.description
        }
    }

    // MARK: Bar items

    /// Show or hide an item. Showing places it on the left unless it already
    /// lives somewhere.
    public func setPlaced(_ id: BarItemID, _ placed: Bool) {
        update { configuration in
            if placed {
                if !configuration.isPlaced(id) { configuration.move(id, to: .left) }
            } else {
                configuration.remove(id)
            }
        }
    }

    public func setSide(_ id: BarItemID, _ side: BarSide) {
        update { configuration in
            guard configuration.isPlaced(id), configuration.side(of: id) != side else { return }
            configuration.move(id, to: side)
        }
    }

    /// Move an item one slot earlier (`delta < 0`) or later (`delta > 0`) within
    /// its current group.
    public func moveWithinSide(_ id: BarItemID, delta: Int) {
        update { configuration in
            guard let side = configuration.side(of: id) else { return }
            var items = configuration.items(on: side)
            guard let index = items.firstIndex(of: id) else { return }
            let target = index + delta
            guard items.indices.contains(target) else { return }
            items.swapAt(index, target)
            configuration.remove(id)
            for (offset, item) in items.enumerated() {
                configuration.move(item, to: side, at: offset)
            }
        }
    }

    public func canMove(_ id: BarItemID, delta: Int) -> Bool {
        guard let side = configuration.side(of: id) else { return false }
        let items = configuration.items(on: side)
        guard let index = items.firstIndex(of: id) else { return false }
        return items.indices.contains(index + delta)
    }

    // MARK: Bar

    /// Show or hide the Divot mark at the start of the left group. The bar
    /// rebuilds live from the published snapshot; the setting also survives a
    /// relaunch through the store.
    public func setShowAppIcon(_ enabled: Bool) {
        update { $0.showAppIcon = enabled }
    }

    /// Turn the subtle bottom drop shadow on or off. Off by default; the bar
    /// rebuilds live from the published snapshot and the setting survives a
    /// relaunch through the store.
    public func setBottomShadow(_ enabled: Bool) {
        update { $0.bottomShadow = enabled }
    }

    /// Draw each item in its own rounded chip or blend them together. Off by
    /// default; the bar rebuilds live from the published snapshot and the setting
    /// survives a relaunch through the store.
    public func setChipStyle(_ enabled: Bool) {
        update { $0.chipStyle = enabled }
    }

    // MARK: Text

    /// The font picker selection: the configured family when it is installed,
    /// else the system default, so a missing font shows the honest fallback
    /// rather than a blank row.
    public var selectedFontFamily: String {
        BarFontResolver.resolveFamily(configuration.text.font,
                                      installed: Set(availableFontFamilies)) ?? ""
    }

    public func setTextSize(_ size: Double) {
        update { $0.text.size = size }
    }

    public func setTextFont(_ family: String) {
        update { $0.text.font = family }
    }

    // MARK: Login item

    public func setLaunchAtLogin(_ enabled: Bool) {
        if loginItem.setEnabled(enabled) {
            errorMessage = nil
        } else {
            errorMessage = "Could not update the login item. Check Login Items in System Settings."
        }
        loginItemEnabled = loginItem.isEnabled
        loginItemStatus = loginItem.statusDescription
    }

    // MARK: Menu bar

    /// Follow the native menu bar's reveal/hide from the pointer reaching the
    /// top strip. Off leaves Divot in its current placement.
    public func setMoveBelowOnCursorReveal(_ enabled: Bool) {
        update { $0.menuBar.moveBelowOnCursorReveal = enabled }
    }

    /// Fallback: always sit below the native menu bar.
    public func setAlwaysBelowMenuBar(_ enabled: Bool) {
        update { $0.menuBar.alwaysBelow = enabled }
    }

    // MARK: Quit

    /// Take the shared quit path, the same one the menu-bar menu uses. The view
    /// only calls this after the user confirms through the shared dialog.
    public func quit() {
        requestQuit()
    }

    /// Open the Location Services pane in System Settings.
    public func openLocationServices() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Keep awake

    /// Turn the "remember across launches" policy on or off. Enabling captures
    /// the live state so the next launch restores exactly what is on now.
    public func setRememberKeepAwake(_ enabled: Bool) {
        let active = keepAwakeIsActive()
        update { configuration in
            configuration.keepAwake.remember = enabled
            if enabled { configuration.keepAwake.isActive = active }
        }
    }
}
