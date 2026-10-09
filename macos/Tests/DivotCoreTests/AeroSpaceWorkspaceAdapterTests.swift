import Foundation
import Testing
@testable import DivotCore

// MARK: - Fake runner

/// Thread-safe command log, kept in a synchronous type so the async runner
/// never calls `NSLock` directly from an async context.
private final class CommandRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [WorkspaceCommand] = []

    func note(_ command: WorkspaceCommand) {
        lock.lock()
        recorded.append(command)
        lock.unlock()
    }

    var commands: [WorkspaceCommand] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

/// A fixture runner: responses are chosen per command and every call is
/// recorded, so adapter behavior is exercised without an installed manager.
final class FakeWorkspaceRunner: WorkspaceProcessRunning, @unchecked Sendable {
    typealias Handler = @Sendable (WorkspaceCommand) throws -> WorkspaceCommandResult

    private let handler: Handler
    private let recorder = CommandRecorder()

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func run(_ command: WorkspaceCommand) async throws -> WorkspaceCommandResult {
        recorder.note(command)
        return try handler(command)
    }

    var commands: [WorkspaceCommand] { recorder.commands }
}

private let workspacesOutput = """
1\tfalse\ttrue\t1\tBuilt-in Retina Display
2\tfalse\tfalse\t1\tBuilt-in Retina Display
3\ttrue\tfalse\t1\tBuilt-in Retina Display
"""

private let windowsOutput = """
3\tcom.apple.Terminal\tTerminal\t501\t28218
1\tcom.apple.Safari\tSafari\t600\t111
"""

private func ok(_ stdout: String = "") -> WorkspaceCommandResult {
    WorkspaceCommandResult(exitCode: 0, stdout: stdout, stderr: "")
}

private func failure(_ code: Int32 = 1, _ stderr: String = "boom") -> WorkspaceCommandResult {
    WorkspaceCommandResult(exitCode: code, stdout: "", stderr: stderr)
}

/// A healthy AeroSpace CLI: every documented subcommand answers.
private func healthyRunner(workspaces: String = workspacesOutput,
                           windows: String = windowsOutput,
                           windowsHelpSucceeds: Bool = true,
                           subscribeHelpSucceeds: Bool = true) -> FakeWorkspaceRunner {
    FakeWorkspaceRunner { command in
        let isHelp = command.arguments.contains("--help")
        switch command.arguments.first {
        case "list-workspaces":
            if isHelp { return ok("usage") }
            if command.arguments.contains("--count") { return ok("3") }
            return ok(workspaces)
        case "list-windows":
            return windowsHelpSucceeds ? ok(windows) : failure(1, "no list-windows")
        case "subscribe":
            return subscribeHelpSucceeds ? ok("usage") : failure(1, "no subscribe")
        case "workspace":
            return ok()
        default:
            throw WorkspaceAdapterError.commandFailed(command: command.displayName, exitCode: 127, stderr: "unexpected")
        }
    }
}

// MARK: - Capability detection

@Test func adapterWithoutBinaryIsHonestlyUnavailable() async {
    let runner = healthyRunner()
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: nil, runner: runner)
    let availability = await adapter.capabilities()
    #expect(availability == .unavailable(.managerNotInstalled))
    #expect(runner.commands.isEmpty)
}

@Test func healthyManagerReportsSupportedCapabilities() async {
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace",
                                            runner: healthyRunner())
    let availability = await adapter.capabilities()
    let capabilities = try! #require(availability.capabilities)
    #expect(capabilities.supportsListWorkspaces)
    #expect(capabilities.supportsListWindows)
    #expect(capabilities.supportsSubscription)
    #expect(capabilities.supportsMonitorAssignment)
}

@Test func missingListWorkspacesCommandIsAProbeFailure() async {
    let runner = FakeWorkspaceRunner { command in
        command.arguments.contains("--help") ? failure(1, "unrecognized command") : ok()
    }
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    let availability = await adapter.capabilities()
    #expect(availability == .unavailable(.capabilityProbeFailed("`list-workspaces` is not supported")))
}

@Test func managerNotRunningIsReportedWhenLivenessQueryFails() async {
    let runner = FakeWorkspaceRunner { command in
        command.arguments.contains("--help") ? ok("usage") : failure(1, "AeroSpace server is not running")
    }
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    #expect(await adapter.capabilities() == .unavailable(.managerNotRunning))
}

@Test func livenessTimeoutIsAProbeFailureNotANotRunningClaim() async {
    let runner = FakeWorkspaceRunner { command in
        if command.arguments.contains("--help") { return ok("usage") }
        throw WorkspaceAdapterError.timedOut(command: command.displayName)
    }
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    let availability = await adapter.capabilities()
    if case .unavailable(.capabilityProbeFailed) = availability {
        // Expected: a timeout is a probe failure, not a false "not running".
    } else {
        Issue.record("expected capabilityProbeFailed, got \(availability)")
    }
}

@Test func missingOptionalCommandsDegradeCapabilitiesWithoutBlocking() async {
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace",
                                            runner: healthyRunner(windowsHelpSucceeds: false,
                                                                  subscribeHelpSucceeds: false))
    let capabilities = try! #require((await adapter.capabilities()).capabilities)
    #expect(capabilities.supportsListWorkspaces)
    #expect(!capabilities.supportsListWindows)
    #expect(!capabilities.supportsSubscription)
}

// MARK: - Reads

@Test func snapshotReadsWorkspacesAndDeduplicatedApps() async throws {
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace",
                                            runner: healthyRunner())
    let snapshot = try await adapter.snapshot()
    #expect(snapshot.manager == .aerospace)
    #expect(snapshot.workspaces.map(\.id.rawValue) == ["1", "2", "3"])
    #expect(snapshot.focusedWorkspaceID == WorkspaceID("3"))
    #expect(snapshot.workspace(WorkspaceID("3"))?.apps.map(\.identity.bundleID) == ["com.apple.Terminal"])
}

@Test func snapshotWithoutWindowSupportStillReturnsWorkspaces() async throws {
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace",
                                            runner: healthyRunner(windowsHelpSucceeds: false))
    let snapshot = try await adapter.snapshot()
    #expect(snapshot.workspaces.count == 3)
    // Icons are optional detail; absent window data must not blank the bar, and
    // occupancy must read as unknown rather than empty.
    #expect(!snapshot.appsAvailable)
    #expect(snapshot.occupancy(of: snapshot.workspaces[0]) == .unknown)
}

@Test func snapshotFailureSurfacesTheDocumentedCommand() async {
    let runner = FakeWorkspaceRunner { command in
        command.arguments.first == "list-workspaces" ? failure(1, "server gone") : ok("")
    }
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        _ = try await adapter.snapshot()
    }
}

// MARK: - Actions

@Test func activateRunsTheWorkspaceCommandAsynchronously() async throws {
    let runner = healthyRunner()
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    try await adapter.activate(WorkspaceID("3"))
    let activation = try! #require(runner.commands.last)
    #expect(activation.arguments == ["workspace", "3"])
}

@Test func activateFailureSurfacesExitCodeAndStderr() async {
    let runner = FakeWorkspaceRunner { _ in failure(2, "no such workspace") }
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        try await adapter.activate(WorkspaceID("nope"))
    }
}

@Test func activateRejectsAnEmptyWorkspaceName() async {
    let runner = healthyRunner()
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: "/opt/homebrew/bin/aerospace", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        try await adapter.activate(WorkspaceID("   "))
    }
    #expect(runner.commands.isEmpty)
}

@Test func activateWithoutAnInstalledBinaryIsUnavailable() async {
    let adapter = AeroSpaceWorkspaceAdapter(executablePath: nil, runner: healthyRunner())
    await #expect(throws: WorkspaceAdapterError.self) {
        try await adapter.activate(WorkspaceID("1"))
    }
}
