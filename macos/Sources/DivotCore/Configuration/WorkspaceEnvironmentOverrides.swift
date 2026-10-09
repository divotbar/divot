import Foundation

/// Environment overrides for the workspace row, kept from the interim reader so
/// launch agents and headless runs can force a display option without editing
/// the file. These are read-time overrides only: they never change what a
/// settings save persists.
public enum WorkspaceEnvironmentOverrides {
    /// The configured adapter, overridden by `DIVOT_WORKSPACES_ADAPTER`. An
    /// unrecognized value is ignored so a typo cannot steer the selection.
    public static func adapter(_ base: WorkspaceManagerKind,
                               environment: [String: String] = ProcessInfo.processInfo.environment)
        -> WorkspaceManagerKind {
        guard let raw = environment["DIVOT_WORKSPACES_ADAPTER"],
              let kind = WorkspaceManagerKind(rawValue: raw.trimmingCharacters(in: .whitespaces).lowercased()) else {
            return base
        }
        return kind
    }

    public static func displayOptions(_ base: WorkspaceDisplayOptions,
                                      environment: [String: String] = ProcessInfo.processInfo.environment)
        -> WorkspaceDisplayOptions {
        var options = base
        if let value = boolean(environment["DIVOT_WORKSPACES_SHOW_EMPTY"]) { options.showEmpty = value }
        if let value = boolean(environment["DIVOT_WORKSPACES_SHOW_ICONS"]) { options.showAppIcons = value }
        if let value = boolean(environment["DIVOT_WORKSPACES_SHOW_DETAILS"]) { options.showDetails = value }
        return options
    }

    private static func boolean(_ raw: String?) -> Bool? {
        switch raw?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }
}
