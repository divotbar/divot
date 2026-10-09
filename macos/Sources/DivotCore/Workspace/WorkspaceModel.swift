import Foundation

// MARK: - Manager identity

/// The window manager behind a workspace snapshot.
///
/// AeroSpace is the first adapter; yabai joins behind the same model in its own
/// milestone. Divot never mixes two managers into one bar.
public enum WorkspaceManagerKind: String, Codable, Sendable, CaseIterable {
    case aerospace
    case yabai

    /// Human-facing name used in diagnostics and the unavailable state.
    public var displayName: String {
        switch self {
        case .aerospace: return "AeroSpace"
        case .yabai: return "yabai"
        }
    }

    /// Deterministic selection order when more than one manager is installed
    /// and the user has no preference. AeroSpace ships first.
    public static let selectionPriority: [WorkspaceManagerKind] = [.aerospace, .yabai]
}

// MARK: - Workspace identity

/// Stable workspace identity for one manager.
///
/// The label is the manager's own workspace name (`"1"`, `"web"`, `"M"`). Divot
/// never invents numbered spaces; if the manager reports no workspaces the bar
/// is honestly empty rather than populated with placeholders.
public struct WorkspaceID: Hashable, Sendable, Comparable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static func < (lhs: WorkspaceID, rhs: WorkspaceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { rawValue }
}

/// A monitor as the manager attributes it. `id` is the manager's own stable
/// number; `name` is cosmetic and may be empty.
public struct WorkspaceMonitor: Hashable, Sendable, Comparable, Codable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String = "") {
        self.id = id
        self.name = name
    }

    public static func < (lhs: WorkspaceMonitor, rhs: WorkspaceMonitor) -> Bool {
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        return lhs.name < rhs.name
    }

    public var displayName: String { name.isEmpty ? "Monitor \(id)" : name }
}

// MARK: - Applications

/// A deduplicated application identity. Bundle id is the icon key; a missing
/// bundle id falls back to the name so dedup still has a stable key.
public struct WorkspaceAppIdentity: Hashable, Sendable, Codable {
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }

    public var dedupKey: String {
        bundleID.isEmpty ? "name:\(name)" : "bundle:\(bundleID)"
    }
}

/// One window as reported by the manager, carrying its app identity.
public struct WorkspaceApp: Hashable, Sendable, Codable {
    public let identity: WorkspaceAppIdentity
    public let pid: Int
    public let windowID: Int

    public init(identity: WorkspaceAppIdentity, pid: Int, windowID: Int) {
        self.identity = identity
        self.pid = pid
        self.windowID = windowID
    }
}

// MARK: - State

/// Focused, occupied and empty are three distinct states a workspace can be in.
public enum WorkspaceOccupancy: String, Equatable, Sendable, Codable {
    case empty
    case occupied
}

/// One workspace with the state the manager reports.
///
/// `apps` is deduplicated by bundle identity, in stable first-seen order, so a
/// workspace with two Terminal windows still shows one icon.
public struct Workspace: Hashable, Sendable, Identifiable {
    public let id: WorkspaceID
    public let isFocused: Bool
    public let isVisible: Bool
    public let monitor: WorkspaceMonitor?
    public let apps: [WorkspaceApp]

    public init(id: WorkspaceID,
                isFocused: Bool = false,
                isVisible: Bool = false,
                monitor: WorkspaceMonitor? = nil,
                apps: [WorkspaceApp] = []) {
        self.id = id
        self.isFocused = isFocused
        self.isVisible = isVisible
        self.monitor = monitor
        self.apps = Workspace.appsByDeduplicating(apps)
    }

    public var occupancy: WorkspaceOccupancy { apps.isEmpty ? .empty : .occupied }
    public var isOccupied: Bool { !apps.isEmpty }
    public var isEmpty: Bool { apps.isEmpty }

    public var appIdentities: [WorkspaceAppIdentity] { apps.map(\.identity) }

    /// Keep the first window seen for each app identity, preserving order.
    public static func appsByDeduplicating(_ apps: [WorkspaceApp]) -> [WorkspaceApp] {
        var seen = Set<String>()
        var result: [WorkspaceApp] = []
        for app in apps where seen.insert(app.identity.dedupKey).inserted {
            result.append(app)
        }
        return result
    }
}

/// One immutable manager reading. The feed stamps generations; the snapshot
/// itself carries no clock so it stays easy to compare in tests.
public struct WorkspaceSnapshot: Equatable, Sendable {
    public let manager: WorkspaceManagerKind
    public let workspaces: [Workspace]

    public init(manager: WorkspaceManagerKind, workspaces: [Workspace]) {
        self.manager = manager
        self.workspaces = workspaces
    }

    public var focused: Workspace? { workspaces.first(where: \.isFocused) }
    public var focusedWorkspaceID: WorkspaceID? { focused?.id }

    public func workspace(_ id: WorkspaceID) -> Workspace? {
        workspaces.first { $0.id == id }
    }

    /// Monitors that at least one workspace is attributed to, stable order.
    public var monitors: [WorkspaceMonitor] {
        var seen = Set<WorkspaceMonitor>()
        var result: [WorkspaceMonitor] = []
        for workspace in workspaces {
            guard let monitor = workspace.monitor, seen.insert(monitor).inserted else { continue }
            result.append(monitor)
        }
        return result.sorted()
    }
}

// MARK: - Display options

/// Which workspace detail to show. Mirrors the proposed
/// `widgets.workspaces` options so the renderer and configuration share one
/// model; defaults keep the calm first-launch bar.
public struct WorkspaceDisplayOptions: Equatable, Sendable {
    /// Keep workspaces with no windows visible.
    public var showEmpty: Bool
    /// Show the deduplicated per-workspace app icons.
    public var showAppIcons: Bool
    /// Optional cap on app icons per workspace; `nil` shows all.
    public var maxAppIconsPerWorkspace: Int?

    public init(showEmpty: Bool = true,
                showAppIcons: Bool = false,
                maxAppIconsPerWorkspace: Int? = nil) {
        self.showEmpty = showEmpty
        self.showAppIcons = showAppIcons
        self.maxAppIconsPerWorkspace = maxAppIconsPerWorkspace
    }

    public static let `default` = WorkspaceDisplayOptions()
}
