import Foundation

// MARK: - Capabilities and availability

/// What an installed manager's CLI actually supports, probed from its own
/// documented `--help` output rather than assumed from a version number.
public struct WorkspaceCapabilities: Equatable, Sendable {
    public let supportsListWorkspaces: Bool
    public let supportsListWindows: Bool
    /// A persistent event subscription (`aerospace subscribe`) is available, so
    /// refreshes are driven by events instead of polling.
    public let supportsSubscription: Bool
    /// The manager exposes a documented workspace-change callback for users who
    /// prefer configured callbacks over a subscription.
    public let supportsCallbacks: Bool
    /// The manager attributes each workspace to a monitor.
    public let supportsMonitorAssignment: Bool

    public init(supportsListWorkspaces: Bool,
                supportsListWindows: Bool,
                supportsSubscription: Bool,
                supportsCallbacks: Bool,
                supportsMonitorAssignment: Bool) {
        self.supportsListWorkspaces = supportsListWorkspaces
        self.supportsListWindows = supportsListWindows
        self.supportsSubscription = supportsSubscription
        self.supportsCallbacks = supportsCallbacks
        self.supportsMonitorAssignment = supportsMonitorAssignment
    }

    public static let none = WorkspaceCapabilities(supportsListWorkspaces: false,
                                                   supportsListWindows: false,
                                                   supportsSubscription: false,
                                                   supportsCallbacks: false,
                                                   supportsMonitorAssignment: false)

    /// Every capability the AeroSpace adapter can detect.
    public static let full = WorkspaceCapabilities(supportsListWorkspaces: true,
                                                   supportsListWindows: true,
                                                   supportsSubscription: true,
                                                   supportsCallbacks: true,
                                                   supportsMonitorAssignment: true)
}

/// Why workspace navigation is not available. Every case is honest: Divot never
/// substitutes fake numbered spaces.
public enum WorkspaceUnavailabilityReason: Equatable, Sendable {
    /// No supported manager binary was found.
    case managerNotInstalled
    /// The binary exists but the manager server is not running.
    case managerNotRunning
    /// The binary is present but does not answer a required documented command.
    case unsupportedVersion(String)
    /// The read-only capability probe failed for another reason.
    case capabilityProbeFailed(String)
    /// A required permission (e.g. Accessibility) is missing.
    case permissionRequired(String)

    /// Short human-readable reason for the unavailable state.
    public var summary: String {
        switch self {
        case .managerNotInstalled:
            return "No supported window manager found"
        case .managerNotRunning:
            return "The window manager is not running"
        case .unsupportedVersion(let detail):
            return "Unsupported window manager version: \(detail)"
        case .capabilityProbeFailed(let detail):
            return "Window manager capability probe failed: \(detail)"
        case .permissionRequired(let detail):
            return "Window manager access needs permission: \(detail)"
        }
    }
}

/// Resolved availability of the selected manager.
public enum WorkspaceAvailability: Equatable, Sendable {
    case available(WorkspaceCapabilities)
    case unavailable(WorkspaceUnavailabilityReason)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    public var capabilities: WorkspaceCapabilities? {
        if case .available(let capabilities) = self { return capabilities }
        return nil
    }

    public var unavailability: WorkspaceUnavailabilityReason? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }

    public var summary: String {
        switch self {
        case .available(let capabilities):
            var features: [String] = []
            if capabilities.supportsListWorkspaces { features.append("workspaces") }
            if capabilities.supportsListWindows { features.append("windows") }
            if capabilities.supportsSubscription { features.append("events") }
            if capabilities.supportsCallbacks { features.append("callbacks") }
            if capabilities.supportsMonitorAssignment { features.append("monitors") }
            return features.isEmpty ? "available" : "available (\(features.joined(separator: ", ")))"
        case .unavailable(let reason):
            return "unavailable (\(reason.summary))"
        }
    }
}

// MARK: - Errors

/// Failures from a workspace adapter. Stale completions are the caller's
/// responsibility via generation checks; these are current, actionable errors.
public enum WorkspaceAdapterError: Error, Equatable, Sendable {
    case unavailable(WorkspaceUnavailabilityReason)
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case timedOut(command: String)
    case cancelled
    case malformedOutput(detail: String)

    public var summary: String {
        switch self {
        case .unavailable(let reason): return reason.summary
        case .commandFailed(let command, let exitCode, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "\(command) failed (exit \(exitCode))"
                : "\(command) failed (exit \(exitCode)): \(detail)"
        case .timedOut(let command): return "\(command) timed out"
        case .cancelled: return "Cancelled"
        case .malformedOutput(let detail): return "Unexpected window manager output: \(detail)"
        }
    }
}

// MARK: - Adapter interface

/// The manager-agnostic workspace interface.
///
/// Lifecycle is explicit (`stop`), reads are snapshots, and actions are async so
/// a slow CLI can never block the bar. Implementations must never poll at frame
/// rate; the feed drives them from events or bounded refreshes.
public protocol WorkspaceAdapting: Sendable {
    var kind: WorkspaceManagerKind { get }

    /// Probe installed/version capabilities. Read-only and safe to call once at
    /// startup (or after a reconnect); it must not mutate window-manager state.
    func capabilities() async -> WorkspaceAvailability

    /// Read the current workspaces, windows, focus and monitor attribution.
    func snapshot() async throws -> WorkspaceSnapshot

    /// Activate a workspace. Executed asynchronously with a timeout.
    func activate(_ workspace: WorkspaceID) async throws

    /// Release any resources. Idempotent.
    func stop() async
}

// MARK: - Process I/O

/// A single command line, with the timeout the adapter allows it.
public struct WorkspaceCommand: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let timeout: TimeInterval

    public init(executable: String, arguments: [String], timeout: TimeInterval = 3) {
        self.executable = executable
        self.arguments = arguments
        self.timeout = max(0.1, timeout)
    }

    /// Pretty form for diagnostics and error messages.
    public var displayName: String {
        let name = (executable as NSString).lastPathComponent
        return ([name] + arguments).joined(separator: " ")
    }
}

/// Result of a completed command.
public struct WorkspaceCommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var succeeded: Bool { exitCode == 0 }
}

/// Runs one bounded command. Injectable so adapter behavior is testable with
/// fixtures and never requires a live window manager.
public protocol WorkspaceProcessRunning: Sendable {
    func run(_ command: WorkspaceCommand) async throws -> WorkspaceCommandResult
}

/// A source of manager events. `events()` is single-use per instance; `stop`
/// ends the stream and releases the underlying process.
public protocol WorkspaceEventSource: Sendable {
    func events() -> AsyncStream<WorkspaceEvent>
    func stop() async
}

// MARK: - Identity resolution

/// Resolves a running process to its app bundle identifier.
///
/// An adapter whose CLI reports only an app name (yabai's `query --windows`
/// gives `app` and `pid`, not a bundle id) uses this so its app identities key
/// icons the same way AeroSpace's bundle ids do. Returning `nil` is honest: the
/// identity then falls back to the app name and simply has no icon.
public protocol WorkspaceProcessIdentityResolving: Sendable {
    func bundleIdentifier(forProcessID pid: Int) -> String?
}

/// Maps a manager's own display identifier to Divot's 1-based
/// `NSScreen.screens` index.
///
/// AeroSpace reports the `NSScreen` index directly. yabai reports a
/// `CGDirectDisplayID`, so the platform half supplies this mapping in order to
/// keep per-display workspace filtering correct instead of assuming ordering.
/// Returning `nil` is honest: the rows then fall back rather than duplicate
/// another display's workspaces.
public protocol WorkspaceDisplayIndexResolving: Sendable {
    func screenIndex(forDisplayIdentifier identifier: Int) -> Int?
}
