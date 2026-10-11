import Foundation

// MARK: - Settings panes

/// A System Settings pane a widget can open.
///
/// Divot deliberately does not mirror the system's own menu extras. Its click
/// behavior is an explicit, narrow choice: a status item either opens the
/// matching native settings pane or activates an application. These "open a
/// pane" links are the design-time candidates; the exact pane identifiers are a
/// physical-validation item for the target OS, and a later milestone may replace
/// the volume/network links with a native control popover (see
/// `docs/evidence/0004-native-providers.md`).
public enum WidgetSettingsPane: String, Equatable, Sendable, CaseIterable {
    case battery
    case network
    case sound
    case dateTime = "datetime"

    /// Candidate deep link for the pane. `nil` when the URL cannot be formed.
    public var url: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.\(rawValue)")
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
        case .workspaces:
            // Workspace activation belongs to the workspace adapter milestone.
            return .none
        }
    }
}
