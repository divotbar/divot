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

    /// The current immutable view state.
    public var state: WorkspaceFeedState { machine.state }

    private var adapter: WorkspaceAdapting?
    private var eventSource: WorkspaceEventSource?
    private var probeTask: Task<Void, Never>?
    private var watchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var pendingRefresh = false
    private let debounce: Duration

    public init(state: WorkspaceFeedState = WorkspaceFeedState(),
                debounce: Duration = .milliseconds(40)) {
        self.machine = WorkspaceFeedStateMachine(state: state)
        self.debounce = debounce
    }

    /// Begin (or restart) reading from an adapter. Pass `nil` when no supported
    /// manager exists; the state becomes the honest unavailable state.
    public func start(adapter: WorkspaceAdapting?,
                      eventSource: WorkspaceEventSource?,
                      options: WorkspaceDisplayOptions) {
        cancelWork()
        self.adapter = adapter
        self.eventSource = eventSource
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
            await self.refresh(at: generation)
            if let eventSource { self.watch(eventSource, at: generation) }
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
        await probeTask?.value
        await refreshTask?.value
    }

    /// Stop reading and release the subscription. Idempotent.
    public func stop() {
        cancelWork()
        adapter = nil
        eventSource = nil
        machine.clearSnapshot()
        announce()
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

    private func watch(_ source: WorkspaceEventSource, at generation: UInt64) {
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            for await event in source.events() {
                guard let self, !Task.isCancelled, self.machine.isCurrent(generation) else { return }
                guard event.requiresSnapshotRefresh else { continue }
                self.scheduleRefresh(at: generation)
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

    private func announce() {
        onChange?(machine.state)
    }

    private static func adapterError(from error: Error) -> WorkspaceAdapterError {
        if let adapterError = error as? WorkspaceAdapterError { return adapterError }
        return .malformedOutput(detail: "\(error)")
    }
}
