import Foundation

/// The AeroSpace workspace adapter.
///
/// It is deliberately thin and stateless: all parsing lives in
/// `AeroSpaceParser`, all process I/O behind `WorkspaceProcessRunning`. That is
/// what lets the whole adapter be exercised with fixtures and no installed
/// manager. It never polls; the feed reads a snapshot only on lifecycle start
/// and on a documented event.
public struct AeroSpaceWorkspaceAdapter: WorkspaceAdapting {
    public let kind: WorkspaceManagerKind = .aerospace

    /// `nil` when no `aerospace` binary was located, which is the honest
    /// not-installed state rather than a reason to invent workspaces.
    private let executablePath: String?
    private let runner: WorkspaceProcessRunning
    private let commandTimeout: TimeInterval
    private let capabilityTimeout: TimeInterval

    public init(executablePath: String?,
                runner: WorkspaceProcessRunning,
                commandTimeout: TimeInterval = 3,
                capabilityTimeout: TimeInterval = 2) {
        self.executablePath = executablePath
        self.runner = runner
        self.commandTimeout = max(0.1, commandTimeout)
        self.capabilityTimeout = max(0.1, capabilityTimeout)
    }

    // MARK: Capability detection

    public func capabilities() async -> WorkspaceAvailability {
        guard let executablePath else { return .unavailable(.managerNotInstalled) }

        // The documented subcommands must exist. A binary that answers none of
        // them is not a usable adapter.
        guard let workspacesHelp = await probe(executable: executablePath, command: "list-workspaces"),
              workspacesHelp.succeeded else {
            return .unavailable(.capabilityProbeFailed("`list-workspaces` is not supported"))
        }

        // `--count` is a cheap read-only query. A clean non-zero exit means the
        // binary cannot reach a running server; a thrown error is a probe
        // failure (timeout), not a claim that the manager is absent.
        do {
            let liveness = try await runner.run(AeroSpaceCLI.liveness(executable: executablePath,
                                                                     timeout: capabilityTimeout))
            guard liveness.succeeded else { return .unavailable(.managerNotRunning) }
        } catch let error as WorkspaceAdapterError {
            return .unavailable(.capabilityProbeFailed(error.summary))
        } catch {
            return .unavailable(.capabilityProbeFailed("\(error)"))
        }

        let windowsHelp = await probe(executable: executablePath, command: "list-windows")
        let subscribeHelp = await probe(executable: executablePath, command: "subscribe")

        return .available(WorkspaceCapabilities(
            supportsListWorkspaces: true,
            supportsListWindows: windowsHelp?.succeeded ?? false,
            supportsSubscription: subscribeHelp?.succeeded ?? false,
            // `exec-on-workspace-change` and monitor force-assignment are
            // documented manager features; whether a given config uses them is
            // the user's choice, so these describe the adapter's supported path.
            supportsCallbacks: true,
            supportsMonitorAssignment: true))
    }

    private func probe(executable: String, command: String) async -> WorkspaceCommandResult? {
        try? await runner.run(AeroSpaceCLI.help(executable: executable,
                                                command: command,
                                                timeout: capabilityTimeout))
    }

    // MARK: Reads

    public func snapshot() async throws -> WorkspaceSnapshot {
        guard let executablePath else { throw WorkspaceAdapterError.unavailable(.managerNotInstalled) }

        let workspaces = try await runner.run(AeroSpaceCLI.listWorkspaces(executable: executablePath,
                                                                         timeout: commandTimeout))
        guard workspaces.succeeded else {
            throw WorkspaceAdapterError.commandFailed(command: AeroSpaceCLI.listWorkspaces(executable: executablePath, timeout: commandTimeout).displayName,
                                                      exitCode: workspaces.exitCode,
                                                      stderr: workspaces.stderr)
        }

        // App icons are optional detail. If `list-windows` is unsupported or
        // transiently fails, report the real workspaces with `appsAvailable:
        // false` so occupancy is `unknown`, never mislabeled as empty.
        let windows = try? await runner.run(AeroSpaceCLI.listWindows(executable: executablePath,
                                                                    timeout: commandTimeout))
        let windowsSucceeded = windows?.succeeded == true

        return AeroSpaceParser.snapshot(workspacesOutput: workspaces.stdout,
                                        windowsOutput: windowsSucceeded ? windows?.stdout ?? "" : "",
                                        manager: kind,
                                        appsAvailable: windowsSucceeded)
    }

    // MARK: Actions

    public func activate(_ workspace: WorkspaceID) async throws {
        guard let executablePath else { throw WorkspaceAdapterError.unavailable(.managerNotInstalled) }
        let trimmed = workspace.rawValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw WorkspaceAdapterError.malformedOutput(detail: "empty workspace name")
        }
        let command = AeroSpaceCLI.activate(executable: executablePath,
                                            workspace: WorkspaceID(trimmed),
                                            timeout: commandTimeout)
        let result = try await runner.run(command)
        guard result.succeeded else {
            throw WorkspaceAdapterError.commandFailed(command: command.displayName,
                                                      exitCode: result.exitCode,
                                                      stderr: result.stderr)
        }
    }

    public func stop() async {
        // Nothing is owned here. A persistent subscription is owned by the app
        // event source, which is stopped separately.
    }
}
