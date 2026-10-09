import Foundation

/// The documented AeroSpace CLI surface Divot uses.
///
/// Everything here is a documented command or `--format` variable from the
/// AeroSpace guide; Divot deliberately does not speak the raw Unix socket or
/// any undocumented flag. `%{tab}` is the field delimiter so workspace and app
/// names are read as whole values rather than re-split on spaces.
public enum AeroSpaceCLI {
    public static let fieldSeparator: Character = "\t"

    /// `workspace`, focused, visible, monitor id, monitor name.
    public static let listWorkspacesFormat =
        "%{workspace}%{tab}%{workspace-is-focused}%{tab}%{workspace-is-visible}%{tab}%{monitor-id}%{tab}%{monitor-name}"

    /// `workspace`, bundle id, app name, pid, window id.
    public static let listWindowsFormat =
        "%{workspace}%{tab}%{app-bundle-id}%{tab}%{app-name}%{tab}%{app-pid}%{tab}%{window-id}"

    public static func listWorkspaces(executable: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: ["list-workspaces", "--all", "--format", listWorkspacesFormat],
                         timeout: timeout)
    }

    public static func listWindows(executable: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: ["list-windows", "--all", "--format", listWindowsFormat],
                         timeout: timeout)
    }

    /// A cheap read-only liveness probe: `--count` prints a number and fails if
    /// the manager server is not running.
    public static func liveness(executable: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: ["list-workspaces", "--all", "--count"],
                         timeout: timeout)
    }

    /// Workspace activation. This is the user action; it never targets the bar.
    public static func activate(executable: String, workspace: WorkspaceID, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: ["workspace", workspace.rawValue],
                         timeout: timeout)
    }

    /// Persistent event subscription. `--no-send-initial` suppresses the initial
    /// state burst because the feed takes its own first snapshot.
    public static func subscribe(executable: String) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: ["subscribe", "--all", "--no-send-initial"],
                         timeout: 0.1)
    }

    /// `--help` existence probe for one subcommand.
    public static func help(executable: String, command: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: [command, "--help"],
                         timeout: timeout)
    }
}

/// Pure parsers for AeroSpace CLI output.
///
/// They take already-captured text so adapter behavior is fixture-tested with no
/// live manager. Unknown or malformed lines are skipped rather than crashing,
/// because a bar must not fail on a single unexpected row.
public enum AeroSpaceParser {
    // MARK: Workspaces

    public static func workspaces(from output: String) -> [Workspace] {
        output.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let fields = line.split(separator: AeroSpaceCLI.fieldSeparator, omittingEmptySubsequences: false).map(String.init)
            guard let rawName = fields.first else { return nil }
            let name = rawName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }

            let focused = fields.count > 1 && parseBool(fields[1])
            let visible = fields.count > 2 && parseBool(fields[2])
            let monitor: WorkspaceMonitor? = {
                guard fields.count > 3, let id = Int(fields[3].trimmingCharacters(in: .whitespaces)) else { return nil }
                let monitorName = fields.count > 4 ? fields[4].trimmingCharacters(in: .whitespaces) : ""
                return WorkspaceMonitor(id: id, name: monitorName)
            }()

            return Workspace(id: WorkspaceID(name), isFocused: focused, isVisible: visible, monitor: monitor)
        }
    }

    // MARK: Windows

    public static func workspaceApps(from output: String) -> [WorkspaceID: [WorkspaceApp]] {
        var result: [WorkspaceID: [WorkspaceApp]] = [:]
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(separator: AeroSpaceCLI.fieldSeparator, omittingEmptySubsequences: false).map(String.init)
            guard let workspaceField = fields.first else { continue }
            let workspaceName = workspaceField.trimmingCharacters(in: .whitespaces)
            guard !workspaceName.isEmpty else { continue }

            let bundleID = fields.count > 1 ? fields[1].trimmingCharacters(in: .whitespaces) : ""
            let appName = fields.count > 2 ? fields[2].trimmingCharacters(in: .whitespaces) : ""
            // A window with neither bundle id nor name carries no useful icon or
            // identity; skip it rather than render a blank chip.
            guard !bundleID.isEmpty || !appName.isEmpty else { continue }

            let pid = fields.count > 3 ? Int(fields[3].trimmingCharacters(in: .whitespaces)) ?? 0 : 0
            let windowID = fields.count > 4 ? Int(fields[4].trimmingCharacters(in: .whitespaces)) ?? 0 : 0
            let app = WorkspaceApp(identity: WorkspaceAppIdentity(bundleID: bundleID, name: appName),
                                   pid: pid,
                                   windowID: windowID)
            result[WorkspaceID(workspaceName), default: []].append(app)
        }
        return result
    }

    // MARK: Snapshot

    /// Join the two read-only queries into one snapshot. Workspace order comes
    /// from `list-workspaces` (the manager's own order) and each workspace keeps
    /// its deduplicated app list.
    public static func snapshot(workspacesOutput: String,
                                windowsOutput: String,
                                manager: WorkspaceManagerKind = .aerospace) -> WorkspaceSnapshot {
        let appsByWorkspace = workspaceApps(from: windowsOutput)
        let workspaces = workspaces(from: workspacesOutput).map { workspace in
            Workspace(id: workspace.id,
                      isFocused: workspace.isFocused,
                      isVisible: workspace.isVisible,
                      monitor: workspace.monitor,
                      apps: appsByWorkspace[workspace.id] ?? [])
        }
        return WorkspaceSnapshot(manager: manager, workspaces: workspaces)
    }

    // MARK: Events

    /// Parse one `aerospace subscribe` JSON line. Returns `nil` for blank or
    /// non-JSON lines so the reader can skip noise.
    public static func event(fromLine line: String) -> WorkspaceEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let name = object["_event"] as? String else { return nil }

        let workspace = workspaceID(object["workspace"])
        let previous = workspaceID(object["prevWorkspace"])

        switch name {
        case "focus-changed":
            guard let workspace else { return .unknown(name) }
            return .focusChanged(workspace: workspace)
        case "focused-monitor-changed":
            let monitorID = (object["monitorId"] as? NSNumber)?.intValue ?? 0
            return .focusedMonitorChanged(monitorID: monitorID, workspace: workspace)
        case "focused-workspace-changed":
            guard let workspace else { return .unknown(name) }
            return .focusedWorkspaceChanged(workspace: workspace, previous: previous)
        case "window-detected":
            return .windowDetected(workspace: workspace,
                                   appBundleID: object["appBundleId"] as? String,
                                   appName: object["appName"] as? String)
        case "mode-changed":
            return .modeChanged(object["mode"] as? String ?? "")
        case "binding-triggered":
            return .bindingTriggered(object["binding"] as? String ?? "")
        default:
            return .unknown(name)
        }
    }

    // MARK: Helpers

    private static func parseBool(_ field: String) -> Bool {
        field.trimmingCharacters(in: .whitespaces).lowercased() == "true"
    }

    private static func workspaceID(_ value: Any?) -> WorkspaceID? {
        guard let name = value as? String else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : WorkspaceID(trimmed)
    }
}
