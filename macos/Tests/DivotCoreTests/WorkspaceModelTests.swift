import Foundation
import Testing
@testable import DivotCore

// MARK: - Fixtures

private let workspacesOutput = """
1\tfalse\ttrue\t1\tBuilt-in Retina Display
2\tfalse\tfalse\t1\tBuilt-in Retina Display
3\ttrue\tfalse\t1\tBuilt-in Retina Display
M\tfalse\tfalse\t2\tDELL U2720Q
"""

private let windowsOutput = """
3\tcom.apple.Terminal\tTerminal\t501\t28218
3\tcom.apple.Terminal\tTerminal\t501\t28219
1\tcom.apple.Safari\tSafari\t600\t111
M\tcom.apple.dt.Xcode\tXcode\t700\t999
"""

private func sampleSnapshot() -> WorkspaceSnapshot {
    AeroSpaceParser.snapshot(workspacesOutput: workspacesOutput, windowsOutput: windowsOutput)
}

// MARK: - Workspace parsing

@Test func parsesRealWorkspaceNamesInManagerOrder() {
    let workspaces = AeroSpaceParser.workspaces(from: workspacesOutput)
    #expect(workspaces.map(\.id.rawValue) == ["1", "2", "3", "M"])
    #expect(workspaces.map(\.isFocused) == [false, false, true, false])
    #expect(workspaces.map(\.isVisible) == [true, false, false, false])
    #expect(workspaces[0].monitor == WorkspaceMonitor(id: 1, name: "Built-in Retina Display"))
    #expect(workspaces[3].monitor == WorkspaceMonitor(id: 2, name: "DELL U2720Q"))
}

@Test func parsesTheNScreenIndexForMonitorMapping() {
    let output = "1\tfalse\ttrue\t1\tBuilt-in Retina Display\t1\n2\tfalse\tfalse\t2\tDELL U2720Q\t2"
    let workspaces = AeroSpaceParser.workspaces(from: output)
    #expect(workspaces[0].monitor?.screensID == 1)
    #expect(workspaces[1].monitor?.screensID == 2)
}

@Test func workspacesDeduplicateAppIconsByBundleIdentity() {
    // The parser reports one row per window; the workspace model collapses them
    // to one icon identity per app.
    let snapshot = sampleSnapshot()
    let terminal = try! #require(snapshot.workspace(WorkspaceID("3")))
    #expect(terminal.apps.count == 1)
    #expect(terminal.apps[0].identity == WorkspaceAppIdentity(bundleID: "com.apple.Terminal", name: "Terminal"))
}

@Test func rawWindowRowsAreGroupedByWorkspace() {
    let apps = AeroSpaceParser.workspaceApps(from: windowsOutput)
    #expect(apps[WorkspaceID("3")]?.count == 2)
    #expect(apps[WorkspaceID("1")]?.count == 1)
}

@Test func snapshotJoinsWorkspacesAndDeduplicatedApps() {
    let snapshot = sampleSnapshot()
    #expect(snapshot.workspaces.count == 4)
    #expect(snapshot.focusedWorkspaceID == WorkspaceID("3"))
    #expect(snapshot.workspace(WorkspaceID("3"))?.apps.count == 1)
    #expect(snapshot.workspace(WorkspaceID("2"))?.isEmpty == true)
    #expect(snapshot.workspace(WorkspaceID("1"))?.isOccupied == true)
    #expect(snapshot.monitors == [WorkspaceMonitor(id: 1, name: "Built-in Retina Display"),
                                  WorkspaceMonitor(id: 2, name: "DELL U2720Q")])
}

@Test func malformedLinesAreSkippedNotFatal() {
    let noisy = """
    1\tfalse\ttrue\t1\tBuilt-in Retina Display
    \t\t\t\t
    broken
    2\tfalse\tfalse\t1\tBuilt-in Retina Display
    """
    let workspaces = AeroSpaceParser.workspaces(from: noisy)
    #expect(workspaces.map(\.id.rawValue) == ["1", "broken", "2"])
    // "broken" has no monitor fields; it is still a real name, not dropped.
    #expect(workspaces[1].monitor == nil)
}

@Test func windowsWithoutIdentityAreIgnored() {
    let windows = """
    1\tcom.apple.Safari\tSafari\t1\t2
    \t\t\t\t
    2\t\t\t0\t0
    """
    let apps = AeroSpaceParser.workspaceApps(from: windows)
    #expect(apps[WorkspaceID("1")]?.count == 1)
    #expect(apps[WorkspaceID("2")] == nil)
}

@Test func unknownKeysDoNotBreakDedupKey() {
    let window = WorkspaceApp(identity: WorkspaceAppIdentity(bundleID: "", name: "WeirdApp"), pid: 1, windowID: 2)
    let workspace = Workspace(id: WorkspaceID("1"), apps: [window, window])
    #expect(workspace.apps.count == 1)
    #expect(workspace.apps[0].identity.dedupKey == "name:WeirdApp")
}

// MARK: - Events

@Test func parsesDocumentedSubscribeEvents() {
    #expect(AeroSpaceParser.event(fromLine: #"{"_event":"focused-monitor-changed","monitorId":1,"workspace":"M"}"#)
        == .focusedMonitorChanged(monitorID: 1, workspace: WorkspaceID("M")))
    #expect(AeroSpaceParser.event(fromLine: #"{"_event":"focused-workspace-changed","prevWorkspace":"M","workspace":"N"}"#)
        == .focusedWorkspaceChanged(workspace: WorkspaceID("N"), previous: WorkspaceID("M")))
    #expect(AeroSpaceParser.event(fromLine: #"{"_event":"focus-changed","windowId":28218,"workspace":"3"}"#)
        == .focusChanged(workspace: WorkspaceID("3")))
    #expect(AeroSpaceParser.event(fromLine: #"{"_event":"window-detected","windowId":1,"workspace":"3","appBundleId":"com.apple.Terminal","appName":"Terminal"}"#)
        == .windowDetected(workspace: WorkspaceID("3"), appBundleID: "com.apple.Terminal", appName: "Terminal"))
    #expect(AeroSpaceParser.event(fromLine: #"{"_event":"mode-changed","mode":"main"}"#) == .modeChanged("main"))
    #expect(AeroSpaceParser.event(fromLine: #"{"_event":"binding-triggered","binding":"alt-1","mode":"main"}"#)
        == .bindingTriggered("alt-1"))
}

@Test func onlyStateChangingEventsRequestARefresh() {
    #expect(WorkspaceEvent.focusChanged(workspace: WorkspaceID("1")).requiresSnapshotRefresh)
    #expect(WorkspaceEvent.focusedWorkspaceChanged(workspace: WorkspaceID("1"), previous: nil).requiresSnapshotRefresh)
    #expect(WorkspaceEvent.windowDetected(workspace: WorkspaceID("1"), appBundleID: nil, appName: nil).requiresSnapshotRefresh)
    #expect(!WorkspaceEvent.modeChanged("main").requiresSnapshotRefresh)
    #expect(!WorkspaceEvent.bindingTriggered("alt-1").requiresSnapshotRefresh)
    // An unknown event may be a newer manager's state change; refresh to be safe.
    #expect(WorkspaceEvent.unknown("future").requiresSnapshotRefresh)
}

@Test func junkEventLinesAreIgnored() {
    #expect(AeroSpaceParser.event(fromLine: "") == nil)
    #expect(AeroSpaceParser.event(fromLine: "not json") == nil)
    #expect(AeroSpaceParser.event(fromLine: #"{"no_event":true}"#) == nil)
}

// MARK: - Manager selection

@Test func userOverrideWinsEvenWhenAnotherManagerIsInstalled() {
    let selection = WorkspaceManagerSelector.select(preferred: .yabai, installed: [.aerospace, .yabai])
    #expect(selection == WorkspaceManagerSelection(kind: .yabai, reason: .userOverride))
}

@Test func overrideIsHonoredEvenWhenThatManagerIsAbsent() {
    // The chosen adapter then reports the honest not-installed state rather than
    // silently switching the user to a different manager.
    let selection = WorkspaceManagerSelector.select(preferred: .yabai, installed: [.aerospace])
    #expect(selection == WorkspaceManagerSelection(kind: .yabai, reason: .userOverride))
}

@Test func deterministicPriorityPicksAeroSpaceFirst() {
    let selection = WorkspaceManagerSelector.select(preferred: nil, installed: [.yabai, .aerospace])
    #expect(selection == WorkspaceManagerSelection(kind: .aerospace, reason: .priority))
}

@Test func noInstalledManagerSelectsNothing() {
    #expect(WorkspaceManagerSelector.select(preferred: nil, installed: []) == nil)
}

// MARK: - Layout

@Test func groupsFilterEmptyWorkspacesWhenAsked() {
    let snapshot = sampleSnapshot()
    let withEmpty = WorkspaceLayout.groups(snapshot: snapshot, options: .init(showEmpty: true))
    #expect(withEmpty.flatMap(\.workspaces).count == 4)

    let withoutEmpty = WorkspaceLayout.groups(snapshot: snapshot, options: .init(showEmpty: false))
    #expect(withoutEmpty.flatMap(\.workspaces).map(\.id.rawValue) == ["1", "3", "M"])
}

@Test func groupsSortMonitorsAndKeepManagerOrderInsideAGroup() {
    let snapshot = sampleSnapshot()
    let groups = WorkspaceLayout.groups(snapshot: snapshot, options: .init())
    #expect(groups.map(\.monitor) == [WorkspaceMonitor(id: 1, name: "Built-in Retina Display"),
                                      WorkspaceMonitor(id: 2, name: "DELL U2720Q")])
    #expect(groups[0].workspaces.map(\.id.rawValue) == ["1", "2", "3"])
    #expect(groups[1].workspaces.map(\.id.rawValue) == ["M"])
}

@Test func displayAppsHonorsToggleAndCap() {
    let workspace = try! #require(sampleSnapshot().workspace(WorkspaceID("3")))
    #expect(WorkspaceLayout.displayApps(for: workspace, options: .init(showAppIcons: false)).isEmpty)

    let many = Workspace(id: WorkspaceID("x"), apps: [
        WorkspaceApp(identity: .init(bundleID: "a", name: "A"), pid: 1, windowID: 1),
        WorkspaceApp(identity: .init(bundleID: "b", name: "B"), pid: 2, windowID: 2),
        WorkspaceApp(identity: .init(bundleID: "c", name: "C"), pid: 3, windowID: 3)
    ])
    let capped = WorkspaceLayout.displayApps(for: many, options: .init(showAppIcons: true, maxAppIconsPerWorkspace: 2))
    #expect(capped.map(\.bundleID) == ["a", "b"])
}

@Test func fitKeepsTheLeadingRunWithinTheWidth() {
    let workspaces = ["1", "2", "3", "4"].map { Workspace(id: WorkspaceID($0)) }
    let overflow = WorkspaceLayout.fit(workspaces,
                                       width: { _ in 30 },
                                       availableWidth: 30 * 2 + 8, // two items plus one gap
                                       spacing: 8)
    #expect(overflow.visible.map(\.id.rawValue) == ["1", "2"])
    #expect(overflow.hidden.map(\.id.rawValue) == ["3", "4"])
    #expect(overflow.overflowCount == 2)
}

@Test func fitAlwaysKeepsTheFocusedWorkspaceVisible() {
    let workspaces = ["1", "2", "3", "4"].map { Workspace(id: WorkspaceID($0), isFocused: $0 == "4") }
    let overflow = WorkspaceLayout.fit(workspaces,
                                       width: { _ in 30 },
                                       availableWidth: 30 * 2 + 8,
                                       spacing: 8)
    // Focus pins "4" in place of the last non-focused visible item.
    #expect(overflow.visible.contains { $0.id == WorkspaceID("4") })
    #expect(overflow.visible.count == 2)
    #expect(!overflow.hidden.contains { $0.id == WorkspaceID("4") })
}

@Test func fitNeverExceedsTheAvailableWidth() {
    let workspaces = ["1", "2", "3"].map { Workspace(id: WorkspaceID($0)) }
    let overflow = WorkspaceLayout.fit(workspaces, width: { _ in 100 }, availableWidth: 50, spacing: 8)
    // A label wider than the whole row is hidden behind overflow rather than
    // allowed to cross the camera housing.
    #expect(overflow.visible.isEmpty)
    #expect(overflow.hidden.count == 3)
}

@Test func fittedRowPlusOverflowControlNeverExceedsTheBudget() {
    let workspaces = (1...6).map { Workspace(id: WorkspaceID("\($0)")) }
    let widths: [CGFloat] = [40, 55, 30, 80, 25, 60]
    let spacing: CGFloat = 8
    let overflowWidth: CGFloat = 30

    for available in stride(from: CGFloat(0), through: 400, by: 7) {
        let overflow = WorkspaceLayout.fit(workspaces,
                                           width: { widths[Int($0.id.rawValue)! - 1] },
                                           availableWidth: available,
                                           spacing: spacing,
                                           overflowWidth: overflowWidth)
        let visibleWidth = overflow.visible.reduce(CGFloat(0)) { $0 + widths[Int($1.id.rawValue)! - 1] }
            + spacing * CGFloat(max(0, overflow.visible.count - 1))
        // The visible chips never exceed the space they were given.
        #expect(visibleWidth <= available + 0.001, "available=\(available)")
        // The overflow control fits too whenever the row is at least that wide.
        if !overflow.hidden.isEmpty && overflowWidth <= available {
            #expect(visibleWidth + overflowWidth <= available + 0.001, "available=\(available)")
        }
    }
}

@Test func overflowReservesRoomForTheControlBeforeFilling() {
    let workspaces = ["1", "2", "3", "4"].map { Workspace(id: WorkspaceID($0)) }
    let overflow = WorkspaceLayout.fit(workspaces,
                                       width: { _ in 30 },
                                       availableWidth: 100,
                                       spacing: 8,
                                       overflowWidth: 40)
    // Reserving the control's width costs a slot versus an unfitted row.
    #expect(overflow.visible.map(\.id.rawValue) == ["1"])
    #expect(!overflow.hidden.isEmpty)
    #expect(30 + 40 <= 100)
}

@Test func workspacesFilterStrictlyByScreenIDAndFallBackOnlyWithoutMapping() {
    let snapshot = sampleSnapshot()
    // Fixtures carry no screen index, so a requested filter falls back to all.
    #expect(WorkspaceLayout.workspaces(forScreensID: 1, in: snapshot, options: .init()).count == 4)
    #expect(WorkspaceLayout.workspaces(forScreensID: nil, in: snapshot, options: .init()).count == 4)

    let monitors = [
        Workspace(id: WorkspaceID("1"), monitor: WorkspaceMonitor(id: 1, name: "A", screensID: 1)),
        Workspace(id: WorkspaceID("2"), monitor: WorkspaceMonitor(id: 2, name: "B", screensID: 2))
    ]
    let withScreens = WorkspaceSnapshot(manager: .aerospace, workspaces: monitors)
    #expect(WorkspaceLayout.workspaces(forScreensID: 2, in: withScreens, options: .init()).map(\.id.rawValue) == ["2"])
    // A display with no mapping shows nothing rather than duplicating monitor 1.
    #expect(WorkspaceLayout.workspaces(forScreensID: 9, in: withScreens, options: .init()).isEmpty)
}

@Test func unknownOccupancyIsNeverMislabeledAsEmpty() {
    let occupiedApp = WorkspaceApp(identity: .init(bundleID: "com.apple.Safari", name: "Safari"), pid: 1, windowID: 1)
    let workspaces = [
        Workspace(id: WorkspaceID("1")),
        Workspace(id: WorkspaceID("2"), apps: [occupiedApp])
    ]
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces, appsAvailable: false)
    #expect(snapshot.occupancy(of: workspaces[0]) == .unknown)
    #expect(snapshot.occupancy(of: workspaces[1]) == .unknown)

    // With windows unread, an empty-workspace filter must not drop a workspace
    // it cannot judge.
    let groups = WorkspaceLayout.groups(snapshot: snapshot, options: .init(showEmpty: false))
    #expect(groups.flatMap(\.workspaces).count == 2)

    let known = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces, appsAvailable: true)
    #expect(known.occupancy(of: workspaces[0]) == .empty)
    #expect(known.occupancy(of: workspaces[1]) == .occupied)
}

// MARK: - Feed state machine

@Test func staleGenerationResultsAreDropped() {
    var machine = WorkspaceFeedStateMachine()
    let first = machine.begin()
    let acceptedAvailability = machine.accept(availability: .available(WorkspaceCapabilities.none), generation: first)
    #expect(acceptedAvailability)

    let second = machine.begin()
    // A slow read from the superseded adapter must not overwrite fresh state.
    let staleAccepted = machine.accept(snapshot: sampleSnapshot(), generation: first)
    let freshAccepted = machine.accept(snapshot: sampleSnapshot(), generation: second)
    #expect(!staleAccepted)
    #expect(freshAccepted)
    #expect(machine.state.snapshot != nil)
}

@Test func unavailableErrorClearsSnapshotAndAvailability() {
    var machine = WorkspaceFeedStateMachine()
    let generation = machine.begin()
    _ = machine.accept(availability: .available(WorkspaceCapabilities.none), generation: generation)
    _ = machine.accept(snapshot: sampleSnapshot(), generation: generation)
    _ = machine.accept(error: .unavailable(.managerNotRunning), generation: generation)
    #expect(machine.state.availability == .unavailable(.managerNotRunning))
    #expect(machine.state.snapshot == nil)
}

@Test func optionsChangeIsReflectedInGroupsWithoutAReload() {
    var machine = WorkspaceFeedStateMachine()
    let generation = machine.begin()
    _ = machine.accept(snapshot: sampleSnapshot(), generation: generation)
    machine.setOptions(.init(showEmpty: false))
    #expect(machine.state.groups.flatMap(\.workspaces).map(\.id.rawValue) == ["1", "3", "M"])
}

@Test func unavailableStateNeverFabricatesWorkspaces() {
    let state = WorkspaceFeedState()
    #expect(!state.isAvailable)
    #expect(state.snapshot == nil)
    #expect(state.groups.isEmpty)
    #expect(state.statusSummary == WorkspaceUnavailabilityReason.managerNotInstalled.summary)
}
