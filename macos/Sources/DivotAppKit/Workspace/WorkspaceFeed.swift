import Foundation
import DivotCore

/// Owns one workspace adapter's lifecycle and turns manager events into
/// coalesced snapshot refreshes.
///
/// It is the AppKit-facing provider: the renderer reads `state`, and every
/// lifecycle transition (start, reconfigure, stop) begins a new generation so a
/// slow read from a superseded adapter can never overwrite fresher state. A new
/// generation also tears down the previous event subscription.
@MainActor
public final class WorkspaceFeed {
    private var machine: WorkspaceFeedStateMachine

    /// Called on the main actor whenever the state changes.
    public var onChange: ((WorkspaceFeedState) -> Void)?

    private var observers: [UUID: (WorkspaceFeedState) -> Void] = [:]

    /// The current immutable view state.
    public var state: WorkspaceFeedState { machine.state }

    private var adapter: WorkspaceAdapting?
    /// Produces a fresh event source per subscription attempt so a dropped
    /// connection can be re-established.
    private var eventSourceProvider: (@MainActor () -> WorkspaceEventSource?)?
    private var probeTask: Task<Void, Never>?
    private var watchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    /// Serializes `adapter.stop()` calls so a superseded stateful adapter is
    /// always released, in order, when the feed reconfigures or stops.
    private var teardownTask: Task<Void, Never>?
    private var pendingRefresh = false
    private let debounce: Duration
    private let reconnectDelay: @MainActor (Int) -> Duration

    public init(state: WorkspaceFeedState = WorkspaceFeedState(),
                debounce: Duration = .milliseconds(40),
                reconnectDelay: @escaping @MainActor (Int) -> Duration = { attempt in
                    .milliseconds(min(attempt, 10) * 500)
                }) {
        self.machine = WorkspaceFeedStateMachine(state: state)
        self.debounce = debounce
        self.reconnectDelay = reconnectDelay
    }

    // MARK: Observation

    /// Register a state observer. The current state is delivered immediately.
    @discardableResult
    public func addObserver(_ observer: @escaping @MainActor (WorkspaceFeedState) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(machine.state)
        return id
    }

    public func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    // MARK: Lifecycle

    /// Begin (or restart) reading from an adapter with a one-shot event source.
    /// Pass `nil` for both when no supported manager exists; the state becomes
    /// the honest unavailable state.
    public func start(adapter: WorkspaceAdapting?,
                      eventSource: WorkspaceEventSource?,
                      options: WorkspaceDisplayOptions) {
        var remaining = eventSource
        start(adapter: adapter,
              eventSourceProvider: {
                  defer { remaining = nil }
                  return remaining
              },
              options: options)
    }

    /// Begin (or restart) reading, reconnecting through `eventSourceProvider`
    /// when a subscription drops.
    public func start(adapter: WorkspaceAdapting?,
                      eventSourceProvider: (@MainActor () -> WorkspaceEventSource?)?,
                      options: WorkspaceDisplayOptions) {
        cancelWork()
        // Release the superseded adapter's resources; its in-flight work is
        // already cancelled and generation checks drop any stale completion.
        let superseded = self.adapter
        self.adapter = adapter
        self.eventSourceProvider = eventSourceProvider
        teardown(superseded)
        machine.setOptions(options)
        let generation = machine.begin()

        guard let adapter else {
            machine.accept(availability: .unavailable(.managerNotInstalled), generation: generation)
            announce()
            return
        }

        probeTask = Task { [weak self] in
            let availability = await adapter.capabilities()
            guard let self, self.machine.isCurrent(generation) else { return }
            self.machine.accept(availability: availability, generation: generation)
            self.announce()
            guard availability.isAvailable else { return }
            // Subscribe *before* the first read so a change during that read is
            // captured and triggers a coalesced refresh instead of being missed.
            if availability.capabilities?.supportsSubscription == true {
                self.watch(at: generation)
            }
            await self.refresh(at: generation)
        }
    }

    /// Update the display options without re-probing the manager.
    public func setOptions(_ options: WorkspaceDisplayOptions) {
        machine.setOptions(options)
        announce()
    }

    /// Read a fresh snapshot for the current generation.
    public func refresh() async {
        await refresh(at: machine.generation)
    }

    /// Activate a workspace for the current generation. A stale completion is
    /// dropped, so clicking an indicator during a manager switch is safe.
    public func activate(_ workspace: WorkspaceID) async {
        guard let adapter else { return }
        let generation = machine.generation
        do {
            try await adapter.activate(workspace)
            await refresh(at: generation)
        } catch {
            guard machine.isCurrent(generation) else { return }
            machine.accept(error: Self.adapterError(from: error), generation: generation)
            announce()
        }
    }

    /// Await the in-flight probe and refresh work. Used by the first snapshot
    /// path and by tests that want a deterministic point to assert on.
    public func waitForPendingWork() async {
        await teardownTask?.value
        await probeTask?.value
        await refreshTask?.value
    }

    /// Await event processing until the event stream ends. Only meaningful when
    /// the provider is finite (tests); a long-lived subscription never returns.
    public func waitForEventProcessing() async {
        await teardownTask?.value
        await probeTask?.value
        await watchTask?.value
        await refreshTask?.value
    }

    /// Stop reading and release the subscription and the adapter. Idempotent.
    ///
    /// The generation is invalidated *before* cancellation and resetting, so a
    /// snapshot already in flight when `stop()` is called fails its `isCurrent`
    /// check and is dropped: it can neither repopulate the cleared state nor
    /// notify observers with stale data.
    public func stop() {
        _ = machine.begin()
        cancelWork()
        let previous = adapter
        adapter = nil
        eventSourceProvider = nil
        machine.clearSnapshot()
        announce()
        teardown(previous)
    }

    // MARK: - Private

    private func refresh(at generation: UInt64) async {
        guard let adapter, machine.isCurrent(generation) else { return }
        do {
            let snapshot = try await adapter.snapshot()
            guard machine.isCurrent(generation) else { return }
            machine.accept(snapshot: snapshot, generation: generation)
        } catch {
            guard machine.isCurrent(generation) else { return }
            machine.accept(error: Self.adapterError(from: error), generation: generation)
        }
        announce()
    }

    /// Consume events for the current generation, reconnecting with a backoff
    /// when a subscription ends. The provider returning `nil` ends the loop.
    private func watch(at generation: UInt64) {
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            guard let self else { return }
            var attempt = 0
            while true {
                guard !Task.isCancelled, self.machine.isCurrent(generation) else { return }
                guard let source = self.eventSourceProvider?() else { return }

                for await event in source.events() {
                    guard !Task.isCancelled, self.machine.isCurrent(generation) else {
                        await source.stop()
                        return
                    }
                    if event.requiresSnapshotRefresh {
                        self.scheduleRefresh(at: generation)
                    }
                }
                await source.stop()

                guard !Task.isCancelled, self.machine.isCurrent(generation) else { return }
                // The stream ended while the feed is still live: surface it and
                // retry so later workspace changes are not silently unobserved.
                attempt += 1
                self.machine.accept(error: .malformedOutput(detail: "workspace event subscription ended; reconnecting"),
                                    generation: generation)
                self.announce()
                try? await Task.sleep(for: self.reconnectDelay(attempt))
            }
        }
    }

    /// Coalesce a burst of events (e.g. several windows detected at once) into
    /// one read instead of one query per event.
    private func scheduleRefresh(at generation: UInt64) {
        pendingRefresh = true
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.debounce)
            guard !Task.isCancelled, self.machine.isCurrent(generation), self.pendingRefresh else { return }
            self.pendingRefresh = false
            await self.refresh(at: generation)
        }
    }

    private func cancelWork() {
        probeTask?.cancel()
        probeTask = nil
        watchTask?.cancel()
        watchTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        pendingRefresh = false
    }

    /// Release an adapter that is no longer the feed's current one. Calls are
    /// chained so an earlier stop always completes before a later one begins,
    /// and so a rapid reconfigure cannot drop a stateful adapter's cleanup.
    private func teardown(_ adapter: WorkspaceAdapting?) {
        guard let adapter else { return }
        let previous = teardownTask
        teardownTask = Task {
            await previous?.value
            await adapter.stop()
        }
    }

    private func announce() {
        onChange?(machine.state)
        for observer in observers.values { observer(machine.state) }
    }

    private static func adapterError(from error: Error) -> WorkspaceAdapterError {
        if let adapterError = error as? WorkspaceAdapterError { return adapterError }
        return .malformedOutput(detail: "\(error)")
    }
}
