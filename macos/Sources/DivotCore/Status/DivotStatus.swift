import Foundation

// MARK: - Permission state

/// How a system permission Divot can depend on currently reads.
///
/// The public APIs do not always expose the same granularity: Location Services
/// distinguishes "not asked" from "denied", while Accessibility only says
/// trusted or not. `notGranted` is the honest state for the latter, so a report
/// never claims the user actively denied something they were never asked.
public enum StatusPermissionState: String, Equatable, Sendable {
    case granted
    case notDetermined
    case denied
    case notGranted
    case unknown

    /// Whether Divot can use the capability the permission gates.
    public var isGranted: Bool { self == .granted }

    /// Human-readable form for the text report; the JSON keeps the raw value.
    public var displayName: String {
        switch self {
        case .granted: return "granted"
        case .notDetermined: return "not determined"
        case .denied: return "denied"
        case .notGranted: return "not granted"
        case .unknown: return "unknown"
        }
    }
}

/// One permission reading plus the System Settings pane a person opens to
/// change it. The CLI only reports the pane; it never prompts or grants.
public struct StatusPermission: Equatable, Sendable {
    public let state: StatusPermissionState
    public let pane: String
    public let settingsURL: String

    public init(state: StatusPermissionState, pane: String, settingsURL: String) {
        self.state = state
        self.pane = pane
        self.settingsURL = settingsURL
    }

    public var isGranted: Bool { state.isGranted }

    /// The Accessibility reading. Public API only (`AXIsProcessTrusted`), which
    /// cannot tell "never asked" from "denied", so a false reading is
    /// `notGranted`.
    public static func accessibility(state: StatusPermissionState) -> StatusPermission {
        StatusPermission(state: state,
                         pane: "Privacy & Security › Accessibility",
                         settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    /// The Location Services reading used to read the Wi-Fi network name.
    public static func location(state: StatusPermissionState) -> StatusPermission {
        StatusPermission(state: state,
                         pane: "Privacy & Security › Location Services",
                         settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
    }

    var jsonObject: [String: Any] {
        [
            "granted": isGranted,
            "state": state.rawValue,
            "settingsPane": pane,
            "settingsURL": settingsURL
        ]
    }
}

// MARK: - Workspace adapter

/// Which window manager Divot talks to, and how that choice was made.
public struct StatusWorkspaceAdapter: Equatable, Sendable {
    /// The manager Divot will try to talk to. A configured or default manager
    /// can win even when its binary is missing, so a report must check
    /// `detected` before treating this as available.
    public let selected: WorkspaceManagerKind?
    /// Every supported manager found on this machine.
    public let installed: [WorkspaceManagerKind]
    /// Where the choice came from: `environment`, `config`, `default`, or `none`.
    public let source: String

    public init(selected: WorkspaceManagerKind?, installed: [WorkspaceManagerKind], source: String) {
        self.selected = selected
        self.installed = installed
        self.source = source
    }

    public var detected: Bool { selected.map(installed.contains) ?? false }

    var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "detected": detected,
            "installed": installed.map(\.rawValue),
            "source": source
        ]
        if let selected { object["selected"] = selected.rawValue }
        return object
    }

    var summary: String {
        let installedNames = installed.isEmpty
            ? "none"
            : installed.map(\.displayName).joined(separator: ", ")
        guard detected, let selected else {
            return "none (installed: \(installedNames); source: \(source))"
        }
        return "\(selected.displayName) (installed: \(installedNames); source: \(source))"
    }
}

// MARK: - Config

/// The on-disk configuration's location and current validity.
public struct StatusConfig: Equatable, Sendable {
    public enum Source: String, Equatable, Sendable {
        /// A configuration file was read.
        case file
        /// No file was present; the built-in defaults are active.
        case defaults
    }

    public let path: String
    public let valid: Bool
    public let source: Source
    /// Present when a supported older document was migrated on load.
    public let migratedFromVersion: Int?
    /// The failing field path and message when the file is invalid.
    public let error: String?

    public init(path: String,
                valid: Bool,
                source: Source,
                migratedFromVersion: Int? = nil,
                error: String? = nil) {
        self.path = path
        self.valid = valid
        self.source = source
        self.migratedFromVersion = migratedFromVersion
        self.error = error
    }

    var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "path": path,
            "valid": valid,
            "source": source.rawValue
        ]
        if let migratedFromVersion { object["migratedFromVersion"] = migratedFromVersion }
        if let error { object["error"] = error }
        return object
    }

    var summary: String {
        let location = "\(path) — \(valid ? "valid" : "invalid") (\(source.rawValue))"
        guard valid else { return "\(location): \(error ?? "unknown error")" }
        if let migratedFromVersion {
            return "\(location), migrated from version \(migratedFromVersion)"
        }
        return location
    }

    /// Build the reading from the store's most recent load outcome.
    static func from(_ outcome: ConfigurationStore.Outcome, path: String) -> StatusConfig {
        switch outcome {
        case .defaults:
            return StatusConfig(path: path, valid: true, source: .defaults)
        case .loaded:
            return StatusConfig(path: path, valid: true, source: .file)
        case .migrated(let from, _):
            return StatusConfig(path: path, valid: true, source: .file, migratedFromVersion: from)
        case .invalid(let error):
            return StatusConfig(path: path, valid: false, source: .file, error: error.description)
        }
    }
}

// MARK: - Report

/// An actionable gap found while assembling a status report.
public struct StatusProblem: Equatable, Sendable {
    public let kind: String
    public let message: String
    public let settingsPane: String?
    public let settingsURL: String?

    public init(kind: String,
                message: String,
                settingsPane: String? = nil,
                settingsURL: String? = nil) {
        self.kind = kind
        self.message = message
        self.settingsPane = settingsPane
        self.settingsURL = settingsURL
    }

    var jsonObject: [String: Any] {
        var object: [String: Any] = ["kind": kind, "message": message]
        if let settingsPane { object["settingsPane"] = settingsPane }
        if let settingsURL { object["settingsURL"] = settingsURL }
        return object
    }
}

/// One `divot status` reading. It is a plain value so the same report can be
/// rendered as text or JSON and asserted in tests without a live machine.
public struct DivotStatusReport: Equatable, Sendable {
    public let version: String
    public let running: Bool
    public let accessibility: StatusPermission
    public let location: StatusPermission
    public let workspaceAdapter: StatusWorkspaceAdapter
    public let config: StatusConfig

    public init(version: String,
                running: Bool,
                accessibility: StatusPermission,
                location: StatusPermission,
                workspaceAdapter: StatusWorkspaceAdapter,
                config: StatusConfig) {
        self.version = version
        self.running = running
        self.accessibility = accessibility
        self.location = location
        self.workspaceAdapter = workspaceAdapter
        self.config = config
    }

    /// Read-only gaps worth acting on. Permission gaps carry the System
    /// Settings pane the CLI will never open for you.
    public var problems: [StatusProblem] {
        var problems: [StatusProblem] = []
        if !accessibility.isGranted {
            problems.append(StatusProblem(
                kind: "permission",
                message: "Accessibility is not granted; notched-display menu-bar detection stays indeterminate.",
                settingsPane: accessibility.pane,
                settingsURL: accessibility.settingsURL))
        }
        if !location.isGranted {
            problems.append(StatusProblem(
                kind: "permission",
                message: "Location is not granted; the Wi-Fi network name is unavailable.",
                settingsPane: location.pane,
                settingsURL: location.settingsURL))
        }
        if !config.valid {
            problems.append(StatusProblem(
                kind: "config",
                message: "The config file is invalid and the running app keeps the last valid configuration: \(config.error ?? "unknown error")"))
        }
        if !workspaceAdapter.detected {
            problems.append(StatusProblem(
                kind: "workspace",
                message: "No supported window manager (AeroSpace or yabai) was found; the workspace row reports an honest unavailable state."))
        }
        return problems
    }

    public var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "version": version,
            "running": running,
            "accessibility": accessibility.jsonObject,
            "location": location.jsonObject,
            "workspaceAdapter": workspaceAdapter.jsonObject,
            "config": config.jsonObject
        ]
        let problems = problems
        if !problems.isEmpty {
            object["problems"] = problems.map(\.jsonObject)
        }
        return object
    }

    /// Human-readable form. Permission gaps name the System Settings pane so a
    /// person can open it; nothing here prompts or changes system state.
    public var text: String {
        var lines = [
            "divot status",
            "version: \(version)",
            "running: \(running ? "yes" : "no")",
            permissionLine("accessibility", accessibility),
            permissionLine("location", location),
            "workspace adapter: \(workspaceAdapter.summary)",
            "config: \(config.summary)"
        ]
        let problems = problems
        if !problems.isEmpty {
            lines.append("problems:")
            for problem in problems {
                var line = "  - \(problem.message)"
                if let pane = problem.settingsPane {
                    line += " Open System Settings › \(pane)."
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    private func permissionLine(_ name: String, _ permission: StatusPermission) -> String {
        guard !permission.isGranted else { return "\(name): granted" }
        return "\(name): \(permission.state.displayName) (System Settings › \(permission.pane))"
    }
}

// MARK: - Environment

/// The facts `divot status` reads. Every value is a closure so tests can inject
/// a deterministic machine and the command never touches real permission or
/// window-manager state.
public struct DivotStatusEnvironment {
    public var version: () -> String
    public var isRunning: () -> Bool
    public var accessibilityGranted: () -> Bool
    public var locationState: () -> StatusPermissionState
    public var installedManagers: () -> [WorkspaceManagerKind]
    public var store: ConfigurationStore
    public var environment: [String: String]

    public init(version: @escaping () -> String,
                isRunning: @escaping () -> Bool,
                accessibilityGranted: @escaping () -> Bool,
                locationState: @escaping () -> StatusPermissionState,
                installedManagers: @escaping () -> [WorkspaceManagerKind],
                store: ConfigurationStore,
                environment: [String: String] = [:]) {
        self.version = version
        self.isRunning = isRunning
        self.accessibilityGranted = accessibilityGranted
        self.locationState = locationState
        self.installedManagers = installedManagers
        self.store = store
        self.environment = environment
    }
}

// MARK: - Command

/// The `divot status` subcommand.
///
/// It is read-only: it never prompts for a permission, grants one, launches the
/// app, or writes a file. A missing permission is reported with the System
/// Settings pane to open, which is the CLI's whole job here.
public struct StatusCommand {
    public let environment: DivotStatusEnvironment

    public init(environment: DivotStatusEnvironment) {
        self.environment = environment
    }

    public static let helpText = """
    divot status — report the app, permissions, workspace adapter, and config

    usage:
      divot status [--json]

    Read-only. It never prompts for or grants a permission; a missing permission
    is reported with the System Settings pane to open.
    exit codes: 0 ok · 2 usage error
    """

    public func run(_ arguments: [String]) -> CLIOutcome {
        if arguments.contains("--help") || arguments.contains("-h") {
            return CLIOutcome(output: Self.helpText)
        }
        for argument in arguments where argument.hasPrefix("-") && argument != "--json" {
            return usage("unknown argument '\(argument)'")
        }
        if let positional = arguments.first(where: { !$0.hasPrefix("-") }) {
            return usage("unexpected argument '\(positional)'")
        }
        let report = makeReport()
        if arguments.contains("--json") {
            return json(report.jsonObject)
        }
        return CLIOutcome(output: report.text)
    }

    /// Assemble the report from the injected environment. Exposed so a caller
    /// can read the value without rendering it.
    public func makeReport() -> DivotStatusReport {
        let path = environment.store.configURL.path
        let config = StatusConfig.from(environment.store.load(), path: path)
        return DivotStatusReport(
            version: environment.version(),
            running: environment.isRunning(),
            accessibility: .accessibility(state: environment.accessibilityGranted() ? .granted : .notGranted),
            location: .location(state: environment.locationState()),
            workspaceAdapter: workspaceAdapter(configuration: environment.store.current,
                                              configStatus: config),
            config: config)
    }

    private func workspaceAdapter(configuration: DivotConfiguration, configStatus: StatusConfig) -> StatusWorkspaceAdapter {
        let installed = environment.installedManagers()
        let preferred = WorkspaceEnvironmentOverrides.adapter(configuration.widgets.workspaces.adapter,
                                                              environment: environment.environment)
        let selection = WorkspaceManagerSelector.select(preferred: preferred, installed: installed)
        let source: String
        if environmentAdapterOverride != nil {
            source = "environment"
        } else if configStatus.source == .file {
            source = "config"
        } else if installed.isEmpty {
            source = "none"
        } else {
            source = "default"
        }
        return StatusWorkspaceAdapter(selected: selection?.kind, installed: installed, source: source)
    }

    private var environmentAdapterOverride: WorkspaceManagerKind? {
        guard let raw = environment.environment["DIVOT_WORKSPACES_ADAPTER"] else { return nil }
        return WorkspaceManagerKind(rawValue: raw.trimmingCharacters(in: .whitespaces).lowercased())
    }

    private func usage(_ message: String) -> CLIOutcome {
        CLIOutcome(output: "error: \(message)\n\n\(Self.helpText)", exitCode: 2)
    }

    private func json(_ object: Any) -> CLIOutcome {
        guard let data = try? JSONSerialization.data(withJSONObject: object,
                                                     options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let string = String(data: data, encoding: .utf8) else {
            return CLIOutcome(output: "error: could not encode JSON", exitCode: 1)
        }
        return CLIOutcome(output: string)
    }
}
