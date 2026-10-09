import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

// MARK: - Fakes

private func workspace(_ name: String, focused: Bool = false, occupied: Bool = false) -> Workspace {
    let apps = occupied
        ? [WorkspaceApp(identity: .init(bundleID: "com.apple.\(name)", name: name), pid: 1, windowID: 1)]
        : []
    return Workspace(id: WorkspaceID(name), isFocused: focused, apps: apps)
}

private final class ActivationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [WorkspaceID] = []

    func record(_ id: WorkspaceID) {
        lock.lock()
        ids.append(id)
        lock.unlock()
    }

    var all: [WorkspaceID] {
        lock.lock()
        defer { lock.unlock() }
        return ids
    }
}

private struct FakeAdapter: WorkspaceAdapting {
    let kind: WorkspaceManagerKind = .aerospace
    let availability: WorkspaceAvailability
    let snapshotValue: WorkspaceSnapshot?
    let activation: ActivationRecorder?

    func capabilities() async -> WorkspaceAvailability { availability }

    func snapshot() async throws -> WorkspaceSnapshot {
        guard let snapshotValue else {
            throw WorkspaceAdapterError.malformedOutput(detail: "no snapshot fixture")
        }
        return snapshotValue
    }

    func activate(_ workspace: WorkspaceID) async throws {
        activation?.record(workspace)
    }

    func stop() async {}
}

// MARK: - Feed orchestration

@MainActor
@Test func feedStartsAvailableAndPublishesSnapshot() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [workspace("1", focused: true), workspace("2", occupied: true)])
    let adapter = FakeAdapter(availability: .available(WorkspaceCapabilities.none),
                              snapshotValue: snapshot,
                              activation: nil)
    let feed = WorkspaceFeed(debounce: .zero)
    feed.start(adapter: adapter, eventSource: nil, options: .default)
    await feed.waitForPendingWork()

    #expect(feed.state.isAvailable)
    #expect(feed.state.snapshot?.focusedWorkspaceID == WorkspaceID("1"))
    #expect(feed.state.groups.flatMap(\.workspaces).count == 2)
}

@MainActor
@Test func feedWithoutAManagerIsHonestlyUnavailable() async {
    let feed = WorkspaceFeed()
    feed.start(adapter: nil, eventSource: nil, options: .default)
    await feed.waitForPendingWork()

    #expect(feed.state.availability == .unavailable(.managerNotInstalled))
    #expect(feed.state.snapshot == nil)
    #expect(feed.state.groups.isEmpty)
}

@MainActor
@Test func reconfigureDropsTheSupersededAdaptersState() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")])
    let feed = WorkspaceFeed(debounce: .zero)
    feed.start(adapter: FakeAdapter(availability: .available(WorkspaceCapabilities.none),
                                    snapshotValue: snapshot,
                                    activation: nil),
               eventSource: nil,
               options: .default)
    await feed.waitForPendingWork()
    #expect(feed.state.snapshot != nil)

    // Switching to an absent manager must not leave the old snapshot behind.
    feed.start(adapter: FakeAdapter(availability: .unavailable(.managerNotInstalled),
                                    snapshotValue: nil,
                                    activation: nil),
               eventSource: nil,
               options: .default)
    await feed.waitForPendingWork()
    #expect(!feed.state.isAvailable)
    #expect(feed.state.snapshot == nil)
}

@MainActor
@Test func optionsToggleFiltersEmptyWorkspacesWithoutAReload() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [workspace("1"), workspace("2", occupied: true)])
    let feed = WorkspaceFeed(debounce: .zero)
    feed.start(adapter: FakeAdapter(availability: .available(WorkspaceCapabilities.none),
                                    snapshotValue: snapshot,
                                    activation: nil),
               eventSource: nil,
               options: .init(showEmpty: true))
    await feed.waitForPendingWork()
    #expect(feed.state.groups.flatMap(\.workspaces).count == 2)

    feed.setOptions(.init(showEmpty: false))
    #expect(feed.state.groups.flatMap(\.workspaces).map(\.id.rawValue) == ["2"])
}

@MainActor
@Test func activateForwardsToTheSelectedAdapter() async {
    let recorder = ActivationRecorder()
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1"), workspace("2")])
    let feed = WorkspaceFeed(debounce: .zero)
    feed.start(adapter: FakeAdapter(availability: .available(WorkspaceCapabilities.none),
                                    snapshotValue: snapshot,
                                    activation: recorder),
               eventSource: nil,
               options: .default)
    await feed.waitForPendingWork()

    await feed.activate(WorkspaceID("2"))
    #expect(recorder.all == [WorkspaceID("2")])
}

@MainActor
@Test func stopClearsTheSnapshot() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")])
    let feed = WorkspaceFeed(debounce: .zero)
    feed.start(adapter: FakeAdapter(availability: .available(WorkspaceCapabilities.none),
                                    snapshotValue: snapshot,
                                    activation: nil),
               eventSource: nil,
               options: .default)
    await feed.waitForPendingWork()
    #expect(feed.state.snapshot != nil)

    feed.stop()
    #expect(feed.state.snapshot == nil)
}
