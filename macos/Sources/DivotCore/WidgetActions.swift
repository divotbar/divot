import Foundation

// MARK: - Settings panes

/// A System Settings pane a widget can open.
///
/// Divot deliberately does not mirror the system's own menu extras. Its click
/// behavior is an explicit, narrow choice: a status item either opens the
/// matching native settings pane or activates an application. The network pane
/// uses the macOS 13+ Wi-Fi Settings extension id (confirmed against the local
/// `/System/Library/ExtensionKit/Extensions/Wi-Fi.appex` bundle on macOS 26),
/// with the older Network pane as a fallback. The remaining pane identifiers are
/// physical-validation items for the target OS, and a later milestone may replace
/// the volume/network links with a native control popover (see
/// `docs/evidence/0004-native-providers.md`).
public enum WidgetSettingsPane: String, Equatable, Sendable, CaseIterable {
    case battery
    case network
    case sound
    case dateTime = "datetime"
    case general

    /// Deep link for the pane. `nil` when the URL cannot be formed.
    ///
    /// The network item points at the macOS 13+ Wi-Fi Settings extension
    /// (`com.apple.wifi-settings-extension`, the bundle identifier of
    /// `/System/Library/ExtensionKit/Extensions/Wi-Fi.appex`) so a click opens
    /// System Settings › Wi-Fi directly. The remaining panes keep the older
    /// `com.apple.preference.*` candidates.
    public var url: URL? {
        switch self {
        case .network:
            return URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")
        default:
            return URL(string: "x-apple.systempreferences:com.apple.preference.\(rawValue)")
        }
    }

    /// A secondary deep link used only when `url` cannot be opened. The network
    /// item falls back to the generic Network pane on systems that do not host
    /// the Wi-Fi Settings extension. `nil` for panes with no fallback.
    public var fallbackURL: URL? {
        switch self {
        case .network:
            return URL(string: "x-apple.systempreferences:com.apple.preference.network")
        default:
            return nil
        }
    }
}

// MARK: - Actions

/// What activating a bar item does.
public enum WidgetAction: Equatable, Sendable {
    /// Bring an app forward by bundle identifier.
    case activateApplication(bundleIdentifier: String)
    /// Open the matching System Settings pane.
    case openSettings(WidgetSettingsPane)
    /// Toggle the keep-awake power assertion (the battery item's click).
    case toggleKeepAwake
    /// Toggle the system appearance between light and dark (the appearance item's click).
    case toggleAppearance
    /// Open Divot's own settings window (the optional app-icon click). Distinct
    /// from `openSettings` so it routes to Divot's window, not a System Settings
    /// pane.
    case openDivotSettings
    /// The item has no activation behavior.
    case none
}

/// Maps the default bar items to their click behavior.
///
/// This is intentionally its own, tested decision rather than a side effect of
/// rendering, so the product choice is reviewable and never silently assumes
/// that Divot reproduces Apple's status menu.
public enum WidgetActions {
    public static func defaultAction(for id: BarItemID,
                                     content: WidgetContent = .unavailable(.init(kind: .noData, message: ""))) -> WidgetAction {
        switch id {
        case .frontApp:
            // The only action that depends on live data: bring the app forward
            // when we know which one it is.
            if case .frontApp(let snapshot) = content, let bundle = snapshot.bundleIdentifier {
                return .activateApplication(bundleIdentifier: bundle)
            }
            return .none
        case .battery:
            // Clicking the battery item toggles the Caffeine-style keep-awake
            // assertion (task 0018). The state rides on the battery snapshot.
            return .toggleKeepAwake
        case .network:
            return .openSettings(.network)
        case .volume:
            return .openSettings(.sound)
        case .clock, .date, .time:
            return .openSettings(.dateTime)
        case .appearance:
            return .toggleAppearance
        case .workspaces:
            // Workspace activation belongs to the workspace adapter milestone.
            return .none
        }
    }
}
