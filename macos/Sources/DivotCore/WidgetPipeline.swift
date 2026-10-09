import Foundation

// MARK: - Provider protocol

/// Cancels one provider activation. Cancelling is idempotent and tears down
/// every observer, timer, and connection that activation created.
public protocol ProviderSubscription: Sendable {
    func cancel()
}

/// A subscription that runs a `@Sendable` closure on cancel. Handy for
/// wrapping platform handles and for test doubles.
public struct CallbackSubscription: ProviderSubscription {
    private let onCancel: @Sendable () -> Void
    public init(_ onCancel: @escaping @Sendable () -> Void) { self.onCancel = onCancel }
    public func cancel() { onCancel() }
}

/// A subscription that cancels a task.
public struct TaskSubscription: ProviderSubscription {
    private let task: Task<Void, Never>
    public init(_ task: Task<Void, Never>) { self.task = task }
    public func cancel() { task.cancel() }
}

/// Holds several subscriptions and cancels them together.
///
/// `add` after `cancel` cancels the newcomer immediately, closing the race where
/// a provider registers its observation on another actor and `stop` arrives
/// before that registration has happened.
public final class SubscriptionBag: ProviderSubscription, @unchecked Sendable {
    private let lock = NSLock()
    private var subscriptions: [any ProviderSubscription] = []
    private var cancelled = false

    public init() {}

    public func add(_ subscription: any ProviderSubscription) {
        lock.lock()
        if cancelled {
            lock.unlock()
            subscription.cancel()
            return
        }
        subscriptions.append(subscription)
        lock.unlock()
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        let all = subscriptions
        subscriptions.removeAll()
        lock.unlock()
        for subscription in all { subscription.cancel() }
    }
}

/// One delivered change: a fresh value, or a removal because the item's
/// provider was stopped or reconfigured away. The removal is what tells the bar
/// to stop showing a value that is no longer being kept current.
public enum WidgetChange: Equatable, Sendable {
    case update(WidgetState)
    case removed(BarItemID)

    public var id: BarItemID {
        switch self {
        case .update(let state): return state.id
        case .removed(let id): return id
        }
    }
}

/// A provider that knows when one widget's data changes.
///
/// `start` is invoked away from the main thread and must do its collection on
/// bounded background work, never by blocking the caller. It returns a
/// subscription immediately; the provider calls `emit` with small immutable
/// snapshots whenever the value changes.
public protocol WidgetProvider: Sendable {
    var id: BarItemID { get }
    func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription
}

// MARK: - Store

/// Pure per-item state with generation tracking.
///
/// Each activation of an item gets a fresh generation; an emission only applies
/// while it matches the item's current generation, so a late result from a
/// disabled or reconfigured provider is ignored instead of overwriting fresh
/// data. Revisions are assigned here, monotonically, so the renderer can skip
/// unchanged values.
public struct WidgetStore: Equatable, Sendable {
    private struct Slot: Equatable, Sendable {
        var generation: UInt64
        var state: WidgetState?
    }

    private var slots: [BarItemID: Slot] = [:]
    private var nextRevision: UInt64 = 1
    /// Generations are global and monotonic so that a late completion from
    /// before a deactivation can never match the item's next generation.
    private var nextGeneration: UInt64 = 1

    public init() {}

    /// Begin (or restart) an item's provider slot. Returns the new generation.
    /// Starting an already-active item bumps its generation and clears its
    /// state, so in-flight completions from the previous activation are stale.
    public mutating func activate(_ id: BarItemID) -> UInt64 {
        let generation = nextGeneration
        nextGeneration &+= 1
        slots[id] = Slot(generation: generation, state: nil)
        return generation
    }

    /// Remove an item's slot entirely; later emissions are rejected.
    public mutating func deactivate(_ id: BarItemID) {
        slots.removeValue(forKey: id)
    }

    public func isActive(_ id: BarItemID) -> Bool { slots[id] != nil }

    public func generation(of id: BarItemID) -> UInt64? { slots[id]?.generation }

    public func state(for id: BarItemID) -> WidgetState? { slots[id]?.state }

    /// All current states, ordered by item identifier for stable rendering.
    public var states: [WidgetState] {
        slots.values.compactMap(\.state).sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Apply an emission, but only when `generation` is the item's current one
    /// and the content fits the item. Returns whether it was accepted.
    @discardableResult
    public mutating func apply(_ content: WidgetContent,
                               for id: BarItemID,
                               generation: UInt64) -> Bool {
        guard var slot = slots[id], slot.generation == generation else { return false }
        guard content.isCompatible(with: id) else { return false }
        let revision = nextRevision
        nextRevision &+= 1
        slot.state = WidgetState(id: id, revision: revision, content: content)
        slots[id] = slot
        return true
    }
}

// MARK: - Coalescing

/// Collects the set of changed items so a burst of emissions is delivered to
/// the UI as one batch. Last write wins because the store holds the value.
public struct WidgetUpdateCoalescer: Equatable, Sendable {
    private var pending: Set<BarItemID> = []

    public init() {}

    public var isEmpty: Bool { pending.isEmpty }

    public mutating func mark(_ id: BarItemID) { pending.insert(id) }

    /// Return and clear the pending set, in stable identifier order.
    public mutating func drain() -> [BarItemID] {
        let ids = pending.sorted { $0.rawValue < $1.rawValue }
        pending.removeAll()
        return ids
    }
}

// MARK: - Pipeline

/// Owns provider activations and delivers coalesced, generation-checked
/// snapshots to a main-actor sink.
///
/// It is an actor so `start`/`stop`/`configure` and incoming emissions serialize
/// on one executor that is never the main thread; providers therefore start off
/// the main thread and one slow provider cannot block the others. The sink is
/// `@MainActor`: the bar's views are only ever touched there.
public actor WidgetPipeline {
    /// Delivered on the main actor with the changed items, batched. A removal
    /// means the item's provider is gone and the bar must clear its value.
    public typealias UpdateSink = @MainActor @Sendable ([WidgetChange]) -> Void

    private var providers: [BarItemID: any WidgetProvider] = [:]
    private var subscriptions: [BarItemID: any ProviderSubscription] = [:]
    private var store = WidgetStore()
    private var coalescer = WidgetUpdateCoalescer()
    private var drainScheduled = false
    private let sink: UpdateSink
    /// When false, emissions are buffered until `drain()` is called explicitly.
    /// Production always uses the scheduled drain; tests turn it off so batching
    /// is deterministic instead of racing the scheduled task.
    private let autoDrain: Bool

    public init(sink: @escaping UpdateSink) {
        self.init(sink: sink, autoDrain: true)
    }

    init(sink: @escaping UpdateSink, autoDrain: Bool) {
        self.sink = sink
        self.autoDrain = autoDrain
    }

    /// All current states, for diagnostics and one-shot reads.
    public var states: [WidgetState] { store.states }

    public func isRunning(_ id: BarItemID) -> Bool { subscriptions[id] != nil }

    public func generation(of id: BarItemID) -> UInt64? { store.generation(of: id) }

    /// Register a provider without starting it. Replacing a registered provider
    /// stops it first so its old observer cannot keep emitting.
    public func register(_ provider: any WidgetProvider) {
        stop(provider.id)
        providers[provider.id] = provider
    }

    /// Start every registered provider. New activations get fresh generations.
    public func start() {
        for id in providers.keys { start(id) }
    }

    /// Start one registered provider. Idempotent while it is already running.
    public func start(_ id: BarItemID) {
        guard subscriptions[id] == nil, let provider = providers[id] else { return }
        let generation = store.activate(id)
        let subscription = provider.start { [weak self] content in
            guard let self else { return }
            Task { await self.ingest(content, for: id, generation: generation) }
        }
        subscriptions[id] = subscription
    }

    /// Stop every provider and clear its state.
    public func stop() {
        for id in Array(subscriptions.keys) { stop(id) }
    }

    /// Stop one provider: cancel its subscription, drop its slot so any
    /// in-flight completion is stale, and tell the bar to clear the value.
    public func stop(_ id: BarItemID) {
        let wasActive = store.isActive(id)
        subscriptions.removeValue(forKey: id)?.cancel()
        store.deactivate(id)
        guard wasActive else { return }
        coalescer.mark(id)
        scheduleDrain()
    }

    /// Replace the whole provider set. Providers that are gone are stopped;
    /// new ones are registered and started; unchanged ones keep running.
    public func configure(_ newProviders: [any WidgetProvider]) {
        let wanted = Set(newProviders.map(\.id))
        for id in Array(providers.keys) where !wanted.contains(id) {
            stop(id)
            providers.removeValue(forKey: id)
        }
        for provider in newProviders {
            if providers[provider.id] == nil {
                providers[provider.id] = provider
                start(provider.id)
            }
        }
    }

    /// Apply one emission. Rejected (silently, correctly) when its generation is
    /// stale, the item is not active, or the content does not fit the item.
    func ingest(_ content: WidgetContent, for id: BarItemID, generation: UInt64) {
        guard store.apply(content, for: id, generation: generation) else { return }
        coalescer.mark(id)
        scheduleDrain()
    }

    private func scheduleDrain() {
        guard autoDrain else { return }
        guard !drainScheduled else { return }
        drainScheduled = true
        Task { await self.drain() }
    }

    /// Deliver the coalesced batch to the main-actor sink. Exposed for tests,
    /// which drive it synchronously instead of racing the scheduled drain.
    func drain() async {
        drainScheduled = false
        let ids = coalescer.drain()
        guard !ids.isEmpty else { return }
        let changes = ids.map { id -> WidgetChange in
            // A live value wins over a pending removal: a provider that was
            // stopped and restarted before the drain must show its new value,
            // not a cleared item.
            if let state = store.state(for: id) { return .update(state) }
            return .removed(id)
        }
        await sink(changes)
    }
}
