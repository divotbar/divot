import Foundation

/// The documented yabai message-passing surface Divot uses.
///
/// Every command here is a documented `yabai -m` message (`man yabai`): the
/// read-only `query` commands and `space --focus`. Divot never speaks yabai's
/// internal socket and never runs a frame-rate query. Reads come from
/// `query --spaces`, `query --windows`, and `query --displays`; activation is
/// `space --focus <label|index>`.
public enum YabaiCLI {
    public static func querySpaces(executable: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable, arguments: ["-m", "query", "--spaces"], timeout: timeout)
    }

    public static func queryWindows(executable: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable, arguments: ["-m", "query", "--windows"], timeout: timeout)
    }

    public static func queryDisplays(executable: String, timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable, arguments: ["-m", "query", "--displays"], timeout: timeout)
    }

    /// Focus a space by its mission-control index or its `--label` alias.
    ///
    /// A `SPACE_SEL` accepts both forms, so one command covers labeled and
    /// unlabeled spaces. This path needs no scripting addition: `space --focus`
    /// is not one of the documented commands gated behind System Integrity
    /// Protection.
    public static func activate(executable: String,
                                workspace: WorkspaceID,
                                timeout: TimeInterval) -> WorkspaceCommand {
        WorkspaceCommand(executable: executable,
                         arguments: ["-m", "space", "--focus", workspace.rawValue],
                         timeout: timeout)
    }
}

// MARK: - Documented query shapes

/// One space from `yabai -m query --spaces`, per the documented SPACE dataformat.
public struct YabaiSpace: Equatable, Sendable {
    public let id: Int
    public let label: String
    public let index: Int
    public let display: Int
    public let windows: [Int]
    public let isFocused: Bool
    public let isVisible: Bool

    public init(id: Int,
                label: String,
                index: Int,
                display: Int,
                windows: [Int],
                isFocused: Bool,
                isVisible: Bool) {
        self.id = id
        self.label = label
        self.index = index
        self.display = display
        self.windows = windows
        self.isFocused = isFocused
        self.isVisible = isVisible
    }

    /// The manager's own identity: its `--label` when set, otherwise its
    /// mission-control index. Divot never invents a name; an unlabeled space is
    /// shown by the number yabai itself uses.
    public var workspaceID: WorkspaceID {
        WorkspaceID(label.isEmpty ? String(index) : label)
    }
}

/// One window from `yabai -m query --windows`, per the documented WINDOW
/// dataformat. yabai reports an app name and pid, not a bundle id.
public struct YabaiWindow: Equatable, Sendable {
    public let id: Int
    public let pid: Int
    public let app: String
    public let space: Int

    public init(id: Int, pid: Int, app: String, space: Int) {
        self.id = id
        self.pid = pid
        self.app = app
        self.space = space
    }
}

/// One display from `yabai -m query --displays`. `id` is a
/// `CGDirectDisplayID`; `index` is yabai's arrangement index.
public struct YabaiDisplay: Equatable, Sendable {
    public let id: Int
    public let index: Int

    public init(id: Int, index: Int) {
        self.id = id
        self.index = index
    }
}

// MARK: - Parser

/// Pure parsers for yabai's documented JSON output.
///
/// They take already-captured text, so adapter behavior is fixture-tested with
/// no installed manager. A malformed row is skipped rather than crashing, but a
/// top-level value that is not the expected JSON array is reported as `nil` so
/// the adapter can surface a real probe failure instead of pretending there are
/// no spaces.
public enum YabaiParser {
    // MARK: Spaces

    public static func spaces(fromJSON output: String) -> [YabaiSpace]? {
        guard let objects = objects(fromJSON: output) else { return nil }
        return objects.compactMap { object in
            guard let index = int(object["index"]) else { return nil }
            return YabaiSpace(id: int(object["id"]) ?? index,
                              label: string(object["label"]),
                              index: index,
                              display: int(object["display"]) ?? 0,
                              windows: (object["windows"] as? [Any])?.compactMap { int($0) } ?? [],
                              isFocused: bool(object["has-focus"]),
                              isVisible: bool(object["is-visible"]))
        }
    }

    // MARK: Windows

    public static func windows(fromJSON output: String) -> [YabaiWindow]? {
        guard let objects = objects(fromJSON: output) else { return nil }
        return objects.compactMap { object in
            guard let id = int(object["id"]), let pid = int(object["pid"]) else { return nil }
            return YabaiWindow(id: id, pid: pid, app: string(object["app"]), space: int(object["space"]) ?? 0)
        }
    }

    // MARK: Displays

    public static func displays(fromJSON output: String) -> [YabaiDisplay]? {
        guard let objects = objects(fromJSON: output) else { return nil }
        return objects.compactMap { object in
            guard let id = int(object["id"]), let index = int(object["index"]) else { return nil }
            return YabaiDisplay(id: id, index: index)
        }
    }

    // MARK: Snapshot

    /// Join the read-only queries into the shared model.
    ///
    /// Workspace order is yabai's own space order. Apps are deduplicated per
    /// workspace by the shared model. `displayIndex` maps yabai's display id to
    /// Divot's screen index; when it is absent or cannot match, `screensID`
    /// stays `nil` and the renderer falls back rather than duplicating another
    /// display. `appsAvailable` is `false` when windows were not read, so
    /// occupancy is `unknown` rather than mislabeled `empty`.
    public static func snapshot(spaces: [YabaiSpace],
                                windows: [YabaiWindow],
                                displays: [YabaiDisplay] = [],
                                manager: WorkspaceManagerKind = .yabai,
                                appsAvailable: Bool = true,
                                processIdentity: WorkspaceProcessIdentityResolving? = nil,
                                displayIndex: WorkspaceDisplayIndexResolving? = nil) -> WorkspaceSnapshot {
        var appsBySpace: [Int: [WorkspaceApp]] = [:]
        for window in windows {
            let bundleID = processIdentity?.bundleIdentifier(forProcessID: window.pid) ?? ""
            let name = window.app.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty || !bundleID.isEmpty else { continue }
            let identity = WorkspaceAppIdentity(bundleID: bundleID, name: name.isEmpty ? bundleID : name)
            appsBySpace[window.space, default: []].append(
                WorkspaceApp(identity: identity, pid: window.pid, windowID: window.id))
        }

        let displayIDByIndex = Dictionary(displays.map { ($0.index, $0.id) },
                                          uniquingKeysWith: { first, _ in first })

        let workspaces = spaces.map { space -> Workspace in
            let screensID: Int? = {
                guard let displayID = displayIDByIndex[space.display] else { return nil }
                return displayIndex?.screenIndex(forDisplayIdentifier: displayID)
            }()
            let monitor = WorkspaceMonitor(id: space.display,
                                           name: "Display \(space.display)",
                                           screensID: screensID)
            return Workspace(id: space.workspaceID,
                             isFocused: space.isFocused,
                             isVisible: space.isVisible,
                             monitor: monitor,
                             apps: appsBySpace[space.index] ?? [])
        }
        return WorkspaceSnapshot(manager: manager, workspaces: workspaces, appsAvailable: appsAvailable)
    }

    // MARK: Events

    /// Map a documented yabai **signal** event onto the shared event model.
    ///
    /// yabai has no persistent event stream; its signals run a user-configured
    /// action, and the action's environment carries the documented `YABAI_*`
    /// values. `space_changed` and `display_changed` map to typed cases; every
    /// other documented or future event is preserved as `unknown`, which the
    /// feed treats as refresh-worthy so a newer yabai cannot silently stop
    /// refreshing. The typed payload is best-effort: a signal passes ids and
    /// indices, not the space label the model uses as identity, so the feed
    /// refreshes on the event kind rather than trusting that identity.
    public static func event(fromSignalEvent event: String,
                             environment: [String: String] = [:]) -> WorkspaceEvent {
        switch event {
        case "space_changed":
            guard let index = intValue(environment["YABAI_SPACE_INDEX"]) else {
                return .unknown("yabai.space_changed")
            }
            let previous = intValue(environment["YABAI_RECENT_SPACE_INDEX"]).map { WorkspaceID(String($0)) }
            return .focusedWorkspaceChanged(workspace: WorkspaceID(String(index)), previous: previous)
        case "display_changed":
            return .focusedMonitorChanged(monitorID: intValue(environment["YABAI_DISPLAY_INDEX"]) ?? 0,
                                          workspace: nil)
        default:
            return .unknown("yabai.\(event)")
        }
    }

    // MARK: Helpers

    private static func objects(fromJSON output: String) -> [[String: Any]]? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static func intValue(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespaces))
    }

    private static func string(_ value: Any?) -> String {
        (value as? String) ?? ""
    }

    private static func bool(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        if let flag = value as? Bool { return flag }
        return false
    }
}
