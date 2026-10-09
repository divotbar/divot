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

/// Counts snapshot reads so a test can prove an event caused a refresh.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class CountingAdapter: WorkspaceAdapting, @unchecked Sendable {
    let kind: WorkspaceManagerKind = .aerospace
    private let counter = Counter()
    private let snapshotValue: WorkspaceSnapshot

    init(snapshot: WorkspaceSnapshot) {
        self.snapshotValue = snapshot
    }

    func capabilities() async -> WorkspaceAvailability { .available(.full) }

    func snapshot() async throws -> WorkspaceSnapshot {
        counter.increment()
        return snapshotValue
    }

    func activate(_ workspace: WorkspaceID) async throws {}
    func stop() async {}

    var snapshotCount: Int { counter.count }
}

/// Records `stop()` so lifecycle tests can prove the feed releases adapters.
private final class StoppableAdapter: WorkspaceAdapting, @unchecked Sendable {
    let kind: WorkspaceManagerKind = .aerospace
    private let counter = Counter()

    func capabilities() async -> WorkspaceAvailability { .available(.full) }

    func snapshot() async throws -> WorkspaceSnapshot {
        WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")])
    }

    func activate(_ workspace: WorkspaceID) async throws {}
    func stop() async { counter.increment() }

    var stopCount: Int { counter.count }
}

/// A one-shot event source backed by an `AsyncStream`.
private final class FakeEventSource: WorkspaceEventSource, @unchecked Sendable {
    private let continuation: AsyncStream<WorkspaceEvent>.Continuation
    private let stream: AsyncStream<WorkspaceEvent>
    private let lock = NSLock()
    private var stopped = false

    init() {
        var captured: AsyncStream<WorkspaceEvent>.Continuation!
        stream = AsyncStream { captured = $0 }
        continuation = captured
    }

    func events() -> AsyncStream<WorkspaceEvent> { stream }

    func stop() async { finish() }

    func send(_ event: WorkspaceEvent) { continuation.yield(event) }
    func finish() {
        lock.lock()
        let alreadyStopped = stopped
        stopped = true
        lock.unlock()
        if !alreadyStopped { continuation.finish() }
    }
}

/// A one-shot gate that lets a test hold a snapshot read open across `stop()`.
private final class SnapshotGate: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var released = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        lock.lock()
        started = true
        let continuation = startedContinuation
        startedContinuation = nil
        lock.unlock()
        continuation?.resume()
    }

    func waitForStart() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if started {
                lock.unlock()
                continuation.resume()
            } else {
                startedContinuation = continuation
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        released = true
        let continuation = releaseContinuation
        releaseContinuation = nil
        lock.unlock()
        continuation?.resume()
    }

    func waitForRelease() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if released {
                lock.unlock()
                continuation.resume()
            } else {
                releaseContinuation = continuation
                lock.unlock()
            }
        }
    }
}

/// A snapshot read that stays open until the test releases the gate, so a
/// completion can be made to land deterministically after `stop()`. The first
/// `immediateReads` reads (the feed's own startup read) return at once.
private final class GatedSnapshotAdapter: WorkspaceAdapting, @unchecked Sendable {
    let kind: WorkspaceManagerKind = .aerospace
    private let snapshotValue: WorkspaceSnapshot
    private let gate: SnapshotGate
    private let lock = NSLock()
    private var remainingImmediateReads: Int

    init(snapshot: WorkspaceSnapshot, gate: SnapshotGate, immediateReads: Int = 0) {
        self.snapshotValue = snapshot
        self.gate = gate
        self.remainingImmediateReads = immediateReads
    }

    func capabilities() async -> WorkspaceAvailability { .available(WorkspaceCapabilities.none) }

    func snapshot() async throws -> WorkspaceSnapshot {
        if claimImmediateRead() { return snapshotValue }
        gate.markStarted()
        await gate.waitForRelease()
        return snapshotValue
    }

    /// Synchronous so the lock is never held across an `await`.
    private func claimImmediateRead() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard remainingImmediateReads > 0 else { return false }
        remainingImmediateReads -= 1
        return true
    }

    func activate(_ workspace: WorkspaceID) async throws {}
    func stop() async {}
}

/// Records announced states so a test can prove a stale completion did not
/// notify observers.
private final class StateRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var states: [WorkspaceFeedState] = []

    func record(_ state: WorkspaceFeedState) {
        lock.lock()
        states.append(state)
        lock.unlock()
    }

    var last: WorkspaceFeedState? {
        lock.lock()
        defer { lock.unlock() }
        return states.last
    }
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
@Test func reconfigureStopsTheSupersededAdapter() async {
    let feed = WorkspaceFeed(debounce: .zero)
    let first = StoppableAdapter()
    feed.start(adapter: first, eventSource: nil, options: .default)
    await feed.waitForPendingWork()
    #expect(first.stopCount == 0)

    let second = StoppableAdapter()
    feed.start(adapter: second, eventSource: nil, options: .default)
    await feed.waitForPendingWork()
    // The replaced adapter is released; the current one is not.
    #expect(first.stopCount == 1)
    #expect(second.stopCount == 0)
}

@MainActor
@Test func stopStopsTheCurrentAdapter() async {
    let feed = WorkspaceFeed(debounce: .zero)
    let adapter = StoppableAdapter()
    feed.start(adapter: adapter, eventSource: nil, options: .default)
    await feed.waitForPendingWork()

    feed.stop()
    await feed.waitForPendingWork()
    #expect(adapter.stopCount == 1)
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

@MainActor
@Test func subscriptionStartsBeforeTheInitialSnapshotSoAnEarlyEventIsNotMissed() async {
    let adapter = CountingAdapter(snapshot: WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")]))
    let source = FakeEventSource()
    // The event is buffered, so it is delivered as soon as the subscription is
    // iterated — the window the review flagged as a missed change.
    source.send(.focusChanged(workspace: WorkspaceID("2")))
    source.finish()

    var providerCalls = 0
    let feed = WorkspaceFeed(debounce: .zero, reconnectDelay: { _ in .zero })
    feed.start(adapter: adapter, eventSourceProvider: {
        providerCalls += 1
        return providerCalls == 1 ? source : nil
    }, options: .default)
    await feed.waitForEventProcessing()

    // One read from start plus at least one more from the buffered event.
    #expect(adapter.snapshotCount >= 2)
}

@MainActor
@Test func feedReconnectsAfterASubscriptionEnds() async {
    let adapter = CountingAdapter(snapshot: WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")]))
    let secondSource = FakeEventSource()
    secondSource.send(.focusedWorkspaceChanged(workspace: WorkspaceID("2"), previous: WorkspaceID("1")))
    secondSource.finish()

    var providerCalls = 0
    let feed = WorkspaceFeed(debounce: .zero, reconnectDelay: { _ in .zero })
    feed.start(adapter: adapter, eventSourceProvider: {
        providerCalls += 1
        switch providerCalls {
        case 1:
            let dropped = FakeEventSource()
            dropped.finish()  // simulate a subscription that ends immediately
            return dropped
        case 2:
            return secondSource
        default:
            return nil
        }
    }, options: .default)
    await feed.waitForEventProcessing()

    #expect(providerCalls >= 2)
    #expect(adapter.snapshotCount >= 2)
}

@MainActor
@Test func feedDoesNotSubscribeWhenTheCapabilityIsMissing() async {
    let adapter = FakeAdapter(availability: .available(WorkspaceCapabilities(
        supportsListWorkspaces: true,
        supportsListWindows: true,
        supportsSubscription: false,
        supportsCallbacks: true,
        supportsMonitorAssignment: true)),
        snapshotValue: WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")]),
        activation: nil)
    let source = FakeEventSource()
    source.finish()
    var providerCalls = 0
    let feed = WorkspaceFeed(debounce: .zero, reconnectDelay: { _ in .zero })
    feed.start(adapter: adapter, eventSourceProvider: {
        providerCalls += 1
        return source
    }, options: .default)
    await feed.waitForPendingWork()
    #expect(providerCalls == 0)
}

/// Regression: a snapshot already in flight when `stop()` is called must be
/// dropped, even though the read completes afterwards. Without invalidating the
/// generation in `stop()`, the delayed completion passes `isCurrent` and
/// repopulates the cleared state.
@MainActor
@Test func stopDropsASnapshotThatCompletesAfterwards() async {
    let gate = SnapshotGate()
    let adapter = GatedSnapshotAdapter(
        snapshot: WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace("1")]),
        gate: gate,
        immediateReads: 1)  // the feed's own startup read returns at once

    let recorder = StateRecorder()
    let feed = WorkspaceFeed(debounce: .zero)
    feed.onChange = { recorder.record($0) }

    feed.start(adapter: adapter, eventSource: nil, options: .default)
    await feed.waitForPendingWork()
    #expect(feed.state.snapshot != nil)

    // Begin a read and hold it open; then stop while it is still in flight.
    let inFlight = Task { await feed.refresh() }
    await gate.waitForStart()
    feed.stop()
    #expect(feed.state.snapshot == nil)

    // Release the delayed read. It must not repopulate state or re-notify.
    gate.release()
    await inFlight.value
    #expect(feed.state.snapshot == nil)
    #expect(recorder.last?.snapshot == nil)
}
