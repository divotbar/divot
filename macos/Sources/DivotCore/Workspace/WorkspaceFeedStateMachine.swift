import Foundation

/// Pure state machine behind `WorkspaceFeed`.
///
/// Every accepted result is stamped with the generation that produced it, so a
/// completion from a superseded adapter (reconfiguration, disconnect, manager
/// switch) is dropped instead of overwriting fresher state. Keeping this pure
/// makes stale-completion handling deterministic to test without any timers or
/// subprocesses.
public struct WorkspaceFeedStateMachine: Sendable {
    public private(set) var state: WorkspaceFeedState
    public private(set) var generation: UInt64

    public init(state: WorkspaceFeedState = WorkspaceFeedState()) {
        self.state = state
        self.generation = 0
    }

    /// Start a new generation. Any result stamped with an older generation is
    /// stale and will be rejected.
    public mutating func begin() -> UInt64 {
        generation &+= 1
        return generation
    }

    public func isCurrent(_ candidate: UInt64) -> Bool {
        candidate == generation
    }

    @discardableResult
    public mutating func accept(availability: WorkspaceAvailability, generation candidate: UInt64) -> Bool {
        guard candidate == generation else { return false }
        state.availability = availability
        if !availability.isAvailable { state.snapshot = nil }
        return true
    }

    @discardableResult
    public mutating func accept(snapshot: WorkspaceSnapshot, generation candidate: UInt64) -> Bool {
        guard candidate == generation else { return false }
        state.snapshot = snapshot
        state.lastError = nil
        return true
    }

    @discardableResult
    public mutating func accept(error: WorkspaceAdapterError, generation candidate: UInt64) -> Bool {
        guard candidate == generation else { return false }
        state.lastError = error
        if case .unavailable(let reason) = error {
            state.availability = .unavailable(reason)
            state.snapshot = nil
        }
        return true
    }

    public mutating func setOptions(_ options: WorkspaceDisplayOptions) {
        state.options = options
    }

    /// Drop the snapshot but keep the availability, used when a feed stops.
    public mutating func clearSnapshot() {
        state.snapshot = nil
    }
}
