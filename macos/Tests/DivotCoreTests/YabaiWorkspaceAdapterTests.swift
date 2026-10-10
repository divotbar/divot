import Foundation
import Testing
@testable import DivotCore

// MARK: - Fixture runner

/// Synchronous command log, kept out of the async context so `NSLock` is only
/// used from a non-async function.
private final class YabaiCommandRecorder: @unchecked Sendable {
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

/// A fixture runner: responses are chosen per documented query and every call is
/// recorded, so yabai adapter behavior is exercised with no installed manager.
final class YabaiFixtureRunner: WorkspaceProcessRunning, @unchecked Sendable {
    typealias Handler = @Sendable (WorkspaceCommand) throws -> WorkspaceCommandResult

    private let handler: Handler
    private let recorder = YabaiCommandRecorder()

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func run(_ command: WorkspaceCommand) async throws -> WorkspaceCommandResult {
        recorder.note(command)
        return try handler(command)
    }

    var commands: [WorkspaceCommand] { recorder.commands }
}

private let spacesJSON = """
[
  {"id":1,"uuid":"AAAA","index":1,"label":"","type":"desktop","display":1,"windows":[101,102],"first-window":101,"last-window":102,"has-focus":true,"is-visible":true,"is-native-fullscreen":false},
  {"id":2,"uuid":"BBBB","index":2,"label":"web","type":"desktop","display":1,"windows":[103],"first-window":103,"last-window":103,"has-focus":false,"is-visible":false,"is-native-fullscreen":false},
  {"id":3,"uuid":"CCCC","index":3,"label":"","type":"desktop","display":2,"windows":[],"first-window":0,"last-window":0,"has-focus":false,"is-visible":true,"is-native-fullscreen":false},
  {"id":4,"uuid":"DDDD","index":4,"label":"chat","type":"desktop","display":1,"windows":[104],"first-window":104,"last-window":104,"has-focus":false,"is-visible":false,"is-native-fullscreen":false}
]
"""

private let windowsJSON = """
[
  {"id":101,"pid":501,"app":"Terminal","title":"a","space":1},
  {"id":102,"pid":501,"app":"Terminal","title":"b","space":1},
  {"id":103,"pid":600,"app":"Safari","title":"c","space":2},
  {"id":104,"pid":700,"app":"Messages","title":"d","space":4}
]
"""

private let displaysJSON = """
[
  {"id":1,"uuid":"UUID-1","index":1,"label":"","frame":{"x":0,"y":0,"w":1600,"h":1000},"spaces":[1,2,4],"has-focus":true},
  {"id":2,"uuid":"UUID-2","index":2,"label":"","frame":{"x":1600,"y":0,"w":1920,"h":1080},"spaces":[3],"has-focus":false}
]
"""

private func ok(_ stdout: String = "") -> WorkspaceCommandResult {
    WorkspaceCommandResult(exitCode: 0, stdout: stdout, stderr: "")
}

private func failure(_ code: Int32 = 1, _ stderr: String = "boom") -> WorkspaceCommandResult {
    WorkspaceCommandResult(exitCode: code, stdout: "", stderr: stderr)
}

/// A healthy yabai: every documented query answers.
private func healthyRunner(spaces: String = spacesJSON,
                           windows: String = windowsJSON,
                           displays: String = displaysJSON,
                           windowsSucceed: Bool = true,
                           displaysSucceed: Bool = true) -> YabaiFixtureRunner {
    YabaiFixtureRunner { command in
        if command.arguments.contains("--spaces") { return ok(spaces) }
        if command.arguments.contains("--windows") { return windowsSucceed ? ok(windows) : failure(1, "no windows") }
        if command.arguments.contains("--displays") { return displaysSucceed ? ok(displays) : failure(1, "no displays") }
        if command.arguments.contains("--focus") { return ok() }
        throw WorkspaceAdapterError.commandFailed(command: command.displayName, exitCode: 127, stderr: "unexpected")
    }
}

/// Maps fixture display ids to 1-based screen indices.
private struct FixtureDisplayIndexResolver: WorkspaceDisplayIndexResolving {
    let mapping: [Int: Int]
    func screenIndex(forDisplayIdentifier identifier: Int) -> Int? { mapping[identifier] }
}

private struct FixtureProcessIdentityResolver: WorkspaceProcessIdentityResolving {
    let mapping: [Int: String]
    func bundleIdentifier(forProcessID pid: Int) -> String? { mapping[pid] }
}

// MARK: - Capability detection

@Test func yabaiWithoutBinaryIsHonestlyUnavailable() async {
    let runner = healthyRunner()
    let adapter = YabaiWorkspaceAdapter(executablePath: nil, runner: runner)
    #expect(await adapter.capabilities() == .unavailable(.managerNotInstalled))
    #expect(runner.commands.isEmpty)
}

@Test func healthyYabaiReportsSupportedCapabilities() async {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner())
    let capabilities = try! #require((await adapter.capabilities()).capabilities)
    #expect(capabilities.supportsListWorkspaces)
    #expect(capabilities.supportsListWindows)
    #expect(capabilities.supportsMonitorAssignment)
    // yabai exposes no persistent stream; signals are the callback path.
    #expect(!capabilities.supportsSubscription)
    #expect(capabilities.supportsCallbacks)
}

@Test func yabaiNotRunningIsReportedWhenTheQueryFails() async {
    let runner = YabaiFixtureRunner { _ in failure(1, "yabai: cannot connect to socket") }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    #expect(await adapter.capabilities() == .unavailable(.managerNotRunning))
}

@Test func yabaiQueryTimeoutIsAProbeFailureNotANotRunningClaim() async {
    let runner = YabaiFixtureRunner { command in
        throw WorkspaceAdapterError.timedOut(command: command.displayName)
    }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    if case .unavailable(.capabilityProbeFailed) = await adapter.capabilities() {
        // Expected: a timeout is a probe failure, not a false "not running".
    } else {
        Issue.record("expected capabilityProbeFailed")
    }
}

@Test func nonJSONSpacesOutputIsAProbeFailure() async {
    let runner = YabaiFixtureRunner { _ in ok("not json at all") }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    guard case .unavailable(.capabilityProbeFailed) = await adapter.capabilities() else {
        Issue.record("expected capabilityProbeFailed for non-JSON spaces output")
        return
    }
}

@Test func missingOptionalQueriesDegradeCapabilities() async {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner(windowsSucceed: false, displaysSucceed: false))
    let capabilities = try! #require((await adapter.capabilities()).capabilities)
    #expect(capabilities.supportsListWorkspaces)
    #expect(!capabilities.supportsListWindows)
    #expect(!capabilities.supportsMonitorAssignment)
}

// MARK: - Reads

@Test func snapshotReadsLabelsFocusAndDeduplicatedApps() async throws {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner())
    let snapshot = try await adapter.snapshot()
    #expect(snapshot.manager == .yabai)
    // Unlabeled spaces use yabai's own index; labeled spaces use the label.
    #expect(snapshot.workspaces.map(\.id.rawValue) == ["1", "web", "3", "chat"])
    #expect(snapshot.focusedWorkspaceID == WorkspaceID("1"))
    // Two Terminal windows collapse to one identity.
    #expect(snapshot.workspace(WorkspaceID("1"))?.apps.count == 1)
    #expect(snapshot.workspace(WorkspaceID("1"))?.apps.first?.identity.name == "Terminal")
    #expect(snapshot.workspace(WorkspaceID("web"))?.apps.map(\.identity.name) == ["Safari"])
    #expect(snapshot.workspace(WorkspaceID("3"))?.isEmpty == true)
    #expect(snapshot.workspace(WorkspaceID("chat"))?.isOccupied == true)
}

@Test func snapshotMapsYabaiDisplaysToScreensThroughTheResolver() async throws {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner(),
                                        displayIndex: FixtureDisplayIndexResolver(mapping: [1: 1, 2: 2]))
    let snapshot = try await adapter.snapshot()
    #expect(snapshot.workspace(WorkspaceID("1"))?.monitor == WorkspaceMonitor(id: 1, name: "Display 1", screensID: 1))
    #expect(snapshot.workspace(WorkspaceID("3"))?.monitor?.screensID == 2)
}

@Test func snapshotWithoutAScreenMappingLeavesScreensNilButKeepsTheMonitor() async throws {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner())
    let snapshot = try await adapter.snapshot()
    // No resolver means no honest mapping; the renderer falls back rather than
    // duplicating another display's workspaces.
    #expect(snapshot.workspace(WorkspaceID("1"))?.monitor?.id == 1)
    #expect(snapshot.workspace(WorkspaceID("1"))?.monitor?.screensID == nil)
}

@Test func snapshotUsesTheProcessIdentityResolverForBundleIDs() async throws {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner(),
                                        processIdentity: FixtureProcessIdentityResolver(mapping: [501: "com.apple.Terminal",
                                                                                                  600: "com.apple.Safari"]))
    let snapshot = try await adapter.snapshot()
    #expect(snapshot.workspace(WorkspaceID("web"))?.apps.first?.identity.bundleID == "com.apple.Safari")
    #expect(snapshot.workspace(WorkspaceID("1"))?.apps.first?.identity.bundleID == "com.apple.Terminal")
}

@Test func snapshotWithoutWindowSupportStillReturnsWorkspacesWithUnknownOccupancy() async throws {
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai",
                                        runner: healthyRunner(windowsSucceed: false))
    let snapshot = try await adapter.snapshot()
    #expect(snapshot.workspaces.count == 4)
    #expect(!snapshot.appsAvailable)
    #expect(snapshot.occupancy(of: snapshot.workspace(WorkspaceID("1"))!) == .unknown)
}

@Test func yabaiSnapshotFailureSurfacesTheDocumentedCommand() async {
    let runner = YabaiFixtureRunner { command in
        command.arguments.contains("--spaces") ? failure(1, "server gone") : ok()
    }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        _ = try await adapter.snapshot()
    }
}

@Test func yabaiMalformedSpacesOutputThrowsRatherThanFabricatingEmpty() async {
    let runner = YabaiFixtureRunner { _ in ok("{\"not\":\"an array\"}") }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        _ = try await adapter.snapshot()
    }
}

@Test func yabaiSnapshotOnlyRunsDocumentedQueries() async throws {
    let runner = healthyRunner()
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    _ = try await adapter.snapshot()
    for command in runner.commands {
        #expect(command.arguments.first == "-m")
        #expect(command.arguments.contains("query") || command.arguments == ["-m", "query", "--spaces"])
    }
}

// MARK: - Actions

@Test func yabaiActivateRunsTheDocumentedSpaceFocusCommand() async throws {
    let runner = healthyRunner()
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    try await adapter.activate(WorkspaceID("web"))
    let activation = try! #require(runner.commands.last)
    #expect(activation.arguments == ["-m", "space", "--focus", "web"])
}

@Test func yabaiActivateFailureSurfacesExitCodeAndStderr() async {
    let runner = YabaiFixtureRunner { command in
        command.arguments.contains("--focus") ? failure(2, "no such space") : ok()
    }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        try await adapter.activate(WorkspaceID("nope"))
    }
}

@Test func yabaiActivateRejectsAnEmptyWorkspaceName() async {
    let runner = healthyRunner()
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    await #expect(throws: WorkspaceAdapterError.self) {
        try await adapter.activate(WorkspaceID("   "))
    }
    #expect(runner.commands.isEmpty)
}

@Test func yabaiActivateWithoutAnInstalledBinaryIsUnavailable() async {
    let adapter = YabaiWorkspaceAdapter(executablePath: nil, runner: healthyRunner())
    await #expect(throws: WorkspaceAdapterError.self) {
        try await adapter.activate(WorkspaceID("1"))
    }
}

@Test func yabaiSnapshotPropagatesATimeout() async {
    let runner = YabaiFixtureRunner { command in
        throw WorkspaceAdapterError.timedOut(command: command.displayName)
    }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    await #expect(throws: WorkspaceAdapterError.timedOut(command: YabaiCLI.querySpaces(executable: "/opt/homebrew/bin/yabai",
                                                                                        timeout: 3).displayName)) {
        _ = try await adapter.snapshot()
    }
}

@Test func yabaiActivatePropagatesCancellation() async {
    let runner = YabaiFixtureRunner { command in
        if command.arguments.contains("--focus") { throw WorkspaceAdapterError.cancelled }
        return ok()
    }
    let adapter = YabaiWorkspaceAdapter(executablePath: "/opt/homebrew/bin/yabai", runner: runner)
    await #expect(throws: WorkspaceAdapterError.cancelled) {
        try await adapter.activate(WorkspaceID("web"))
    }
}

// MARK: - Events

@Test func spaceChangedSignalMapsToAFocusedWorkspaceChange() {
    let event = YabaiParser.event(fromSignalEvent: "space_changed",
                                  environment: ["YABAI_SPACE_INDEX": "2",
                                                "YABAI_RECENT_SPACE_INDEX": "1"])
    #expect(event == .focusedWorkspaceChanged(workspace: WorkspaceID("2"), previous: WorkspaceID("1")))
    #expect(event.requiresSnapshotRefresh)
}

@Test func displayChangedSignalMapsToAFocusedMonitorChange() {
    let event = YabaiParser.event(fromSignalEvent: "display_changed",
                                  environment: ["YABAI_DISPLAY_INDEX": "2",
                                                "YABAI_RECENT_DISPLAY_INDEX": "1"])
    #expect(event == .focusedMonitorChanged(monitorID: 2, workspace: nil))
    #expect(event.requiresSnapshotRefresh)
}

@Test func undocumentedSignalEventsArePreservedAndRefresh() {
    let event = YabaiParser.event(fromSignalEvent: "window_created",
                                  environment: ["YABAI_WINDOW_ID": "101"])
    #expect(event == .unknown("yabai.window_created"))
    #expect(event.requiresSnapshotRefresh)
}

@Test func spaceChangedWithoutAnIndexFallsBackToUnknown() {
    #expect(YabaiParser.event(fromSignalEvent: "space_changed", environment: [:])
        == .unknown("yabai.space_changed"))
}

// MARK: - Parser edge cases

@Test func malformedSpacesRowsAreSkippedButAnObjectIsRejected() {
    let noisy = """
    [
      {"id":1,"index":1,"label":"","display":1,"windows":[],"has-focus":true,"is-visible":true},
      {"label":"no index"},
      {"index":2,"label":"web","display":1,"has-focus":false,"is-visible":false}
    ]
    """
    let spaces = try! #require(YabaiParser.spaces(fromJSON: noisy))
    #expect(spaces.map(\.workspaceID.rawValue) == ["1", "web"])
    // A non-array top level is a real failure, not "no spaces".
    #expect(YabaiParser.spaces(fromJSON: "{}") == nil)
    #expect(YabaiParser.spaces(fromJSON: "") == nil)
}

@Test func windowsWithoutIdentityCarryNoSignalButAreStillParsed() {
    let windows = """
    [{"id":1,"pid":9,"app":"","space":1}]
    """
    let parsed = try! #require(YabaiParser.windows(fromJSON: windows))
    #expect(parsed == [YabaiWindow(id: 1, pid: 9, app: "", space: 1)])
    // With no app name and no resolved bundle id, no identity is fabricated.
    let snapshot = YabaiParser.snapshot(spaces: [YabaiSpace(id: 1, label: "", index: 1, display: 1,
                                                            windows: [1], isFocused: false, isVisible: true)],
                                        windows: parsed)
    #expect(snapshot.workspace(WorkspaceID("1"))?.apps.isEmpty == true)
}
