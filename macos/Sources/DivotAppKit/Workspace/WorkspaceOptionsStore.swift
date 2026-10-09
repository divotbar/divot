import Foundation
import DivotCore

/// Reads the workspace row's display options from Divot's config file.
///
/// This is an interim reader for the documented `widgets.workspaces` object; the
/// full versioned configuration model and hot reload arrive with task 0006.
/// Missing or invalid input falls back to the defaults, so a malformed file can
/// never hide the row. Environment variables override the file for launch
/// agents and headless runs.
public enum WorkspaceOptionsStore {
    public static func defaultConfigURL(homeDirectory: String = NSHomeDirectory(),
                                        environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg).appendingPathComponent("divot/config.json")
        }
        return URL(fileURLWithPath: homeDirectory).appendingPathComponent(".config/divot/config.json")
    }

    /// Load options from `configURL` (defaults to the config file location) with
    /// environment overrides applied last.
    public static func load(configURL: URL? = defaultConfigURL(),
                            environment: [String: String] = ProcessInfo.processInfo.environment) -> WorkspaceDisplayOptions {
        var options = WorkspaceDisplayOptions.default

        if let configURL,
           let data = try? Data(contentsOf: configURL),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let widgets = root["widgets"] as? [String: Any],
           let workspaces = widgets["workspaces"] as? [String: Any] {
            if let value = workspaces["showEmpty"] as? Bool { options.showEmpty = value }
            if let value = workspaces["showAppIcons"] as? Bool { options.showAppIcons = value }
            if let value = workspaces["showDetails"] as? Bool { options.showDetails = value }
            if let value = workspaces["maxAppIconsPerWorkspace"] as? Int, value >= 0 {
                options.maxAppIconsPerWorkspace = value
            }
        }

        // Environment overrides win (launch agents, headless runs, tests).
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
