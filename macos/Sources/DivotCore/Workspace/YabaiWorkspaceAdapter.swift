import Foundation

/// The yabai workspace adapter, the second implementation behind
/// `WorkspaceAdapting`.
///
/// Like the AeroSpace adapter it is deliberately thin and stateless: parsing
/// lives in `YabaiParser`, all process I/O behind `WorkspaceProcessRunning`. It
/// reads only documented `yabai -m query` messages and activates with
/// `yabai -m space --focus`.
///
/// Privileges: the read path (`query --spaces` / `--windows` / `--displays`)
/// and `space --focus` are **not** among the yabai commands documented as
/// requiring System Integrity Protection to be partially disabled, so this
/// adapter needs no scripting addition and no private API. yabai itself needs
/// its Accessibility permission to manage windows; if that is missing the query
/// path fails and the adapter reports the honest unavailable state rather than
/// guessing.
public struct YabaiWorkspaceAdapter: WorkspaceAdapting {
    public let kind: WorkspaceManagerKind = .yabai

    /// `nil` when no `yabai` binary was located, the honest not-installed state.
    private let executablePath: String?
    private let runner: WorkspaceProcessRunning
    private let commandTimeout: TimeInterval
    private let capabilityTimeout: TimeInterval
    private let processIdentity: WorkspaceProcessIdentityResolving?
    private let displayIndex: WorkspaceDisplayIndexResolving?

    public init(executablePath: String?,
                runner: WorkspaceProcessRunning,
                commandTimeout: TimeInterval = 3,
                capabilityTimeout: TimeInterval = 2,
                processIdentity: WorkspaceProcessIdentityResolving? = nil,
                displayIndex: WorkspaceDisplayIndexResolving? = nil) {
        self.executablePath = executablePath
        self.runner = runner
        self.commandTimeout = max(0.1, commandTimeout)
        self.capabilityTimeout = max(0.1, capabilityTimeout)
        self.processIdentity = processIdentity
        self.displayIndex = displayIndex
    }

    // MARK: Capability detection

    public func capabilities() async -> WorkspaceAvailability {
        guard let executablePath else { return .unavailable(.managerNotInstalled) }

        // yabai has no per-subcommand `--help`; the documented `query --spaces`
        // message is both the liveness check and the workspaces capability. A
        // non-zero exit means the server is not answering; a thrown error is a
        // probe failure (timeout), not a false "not running".
        let spaces: WorkspaceCommandResult
        do {
            spaces = try await runner.run(YabaiCLI.querySpaces(executable: executablePath,
                                                               timeout: capabilityTimeout))
        } catch let error as WorkspaceAdapterError {
            return .unavailable(.capabilityProbeFailed(error.summary))
        } catch {
            return .unavailable(.capabilityProbeFailed("\(error)"))
        }
        guard spaces.succeeded else { return .unavailable(.managerNotRunning) }
        guard YabaiParser.spaces(fromJSON: spaces.stdout) != nil else {
            return .unavailable(.capabilityProbeFailed("`query --spaces` did not return JSON"))
        }

        let windows = try? await runner.run(YabaiCLI.queryWindows(executable: executablePath,
                                                                  timeout: capabilityTimeout))
        let windowsSupported = (windows?.succeeded ?? false)
            && YabaiParser.windows(fromJSON: windows?.stdout ?? "") != nil

        let displays = try? await runner.run(YabaiCLI.queryDisplays(executable: executablePath,
                                                                    timeout: capabilityTimeout))
        let displaysSupported = (displays?.succeeded ?? false)
            && YabaiParser.displays(fromJSON: displays?.stdout ?? "") != nil

        return .available(WorkspaceCapabilities(
            supportsListWorkspaces: true,
            supportsListWindows: windowsSupported,
            // yabai exposes no persistent event stream; its signals run
            // configured callbacks instead, which the feed treats as bounded
            // refreshes.
            supportsSubscription: false,
            supportsCallbacks: true,
            supportsMonitorAssignment: displaysSupported))
    }

    // MARK: Reads

    public func snapshot() async throws -> WorkspaceSnapshot {
        guard let executablePath else { throw WorkspaceAdapterError.unavailable(.managerNotInstalled) }

        let spacesCommand = YabaiCLI.querySpaces(executable: executablePath, timeout: commandTimeout)
        let spacesResult = try await runner.run(spacesCommand)
        guard spacesResult.succeeded else {
            throw WorkspaceAdapterError.commandFailed(command: spacesCommand.displayName,
                                                      exitCode: spacesResult.exitCode,
                                                      stderr: spacesResult.stderr)
        }
        guard let spaces = YabaiParser.spaces(fromJSON: spacesResult.stdout) else {
            throw WorkspaceAdapterError.malformedOutput(
                detail: "`yabai -m query --spaces` did not return a JSON array")
        }

        // Icons and the display map are optional detail. A failed optional query
        // must not blank the real workspaces.
        let windowsResult = try? await runner.run(YabaiCLI.queryWindows(executable: executablePath,
                                                                        timeout: commandTimeout))
        let windows = windowsResult?.succeeded == true
            ? YabaiParser.windows(fromJSON: windowsResult?.stdout ?? "")
            : nil

        let displaysResult = try? await runner.run(YabaiCLI.queryDisplays(executable: executablePath,
                                                                          timeout: commandTimeout))
        let displays = displaysResult?.succeeded == true
            ? (YabaiParser.displays(fromJSON: displaysResult?.stdout ?? "") ?? [])
            : []

        return YabaiParser.snapshot(spaces: spaces,
                                    windows: windows ?? [],
                                    displays: displays,
                                    manager: kind,
                                    appsAvailable: windows != nil,
                                    processIdentity: processIdentity,
                                    displayIndex: displayIndex)
    }

    // MARK: Actions

    public func activate(_ workspace: WorkspaceID) async throws {
        guard let executablePath else { throw WorkspaceAdapterError.unavailable(.managerNotInstalled) }
        let trimmed = workspace.rawValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw WorkspaceAdapterError.malformedOutput(detail: "empty workspace name")
        }
        let command = YabaiCLI.activate(executable: executablePath,
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
        // Nothing is owned here: the adapter holds no subscription or process.
    }
}
