import Foundation
import Testing
@testable import DivotCore

/// A controllable provider for pipeline tests. It records whether `start` ran on
/// the main thread and exposes the emit closure so a test can simulate a slow
/// completion arriving after the item was disabled.
private final class TestProvider: WidgetProvider, @unchecked Sendable {
    let id: BarItemID
    private let lock = NSLock()
    private var emitClosure: (@Sendable (WidgetContent) -> Void)?
    private var _startedOnMain = false
    private var _cancelCount = 0
    private var _startCount = 0

    init(id: BarItemID) { self.id = id }

    func start(emit: @escaping @Sendable (WidgetContent) -> Void) -> any ProviderSubscription {
        lock.lock()
        emitClosure = emit
        _startedOnMain = Thread.isMainThread
        _startCount += 1
        lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self._cancelCount += 1; self.lock.unlock()
        }
    }

    var startedOnMain: Bool { lock.lock(); defer { lock.unlock() }; return _startedOnMain }
    var cancelCount: Int { lock.lock(); defer { lock.unlock() }; return _cancelCount }
    var startCount: Int { lock.lock(); defer { lock.unlock() }; return _startCount }

    func capturedEmit() -> (@Sendable (WidgetContent) -> Void)? {
        lock.lock(); defer { lock.unlock() }; return emitClosure
    }
}

/// Records delivered batches and whether every delivery happened on the main
/// actor.
@MainActor
private final class DeliverySpy {
    private(set) var batches: [[WidgetChange]] = []
    private(set) var allOnMain = true

    func record(_ changes: [WidgetChange]) {
        allOnMain = allOnMain && Thread.isMainThread
        batches.append(changes)
    }
}

@MainActor
@Test func pipelineStartsProvidersOffTheMainThread() async {
    let provider = TestProvider(id: .battery)
    let pipeline = WidgetPipeline(sink: { _ in }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    // Provider setup (which may do I/O) must never block the main thread.
    #expect(provider.startedOnMain == false)
    await pipeline.stop()
}

@MainActor
@Test func stoppingAProviderCancelsItAndDropsItsState() async {
    let provider = TestProvider(id: .network)
    let pipeline = WidgetPipeline(sink: { _ in }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    let running = await pipeline.isRunning(.network)
    #expect(running)

    await pipeline.stop(.network)
    let stillRunning = await pipeline.isRunning(.network)
    #expect(stillRunning == false)
    #expect(provider.cancelCount == 1)
    let generation = await pipeline.generation(of: .network)
    #expect(generation == nil)
}

@MainActor
@Test func staleCompletionFromAnOldActivationIsIgnored() async {
    let spy = DeliverySpy()
    let provider = TestProvider(id: .battery)
    let pipeline = WidgetPipeline(sink: { states in spy.record(states) }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    let staleGeneration = await pipeline.generation(of: .battery)!

    // Disable and re-enable: a new generation, the old one is now stale.
    await pipeline.stop(.battery)
    await pipeline.start(.battery)
    let freshGeneration = await pipeline.generation(of: .battery)!
    #expect(freshGeneration > staleGeneration)

    // A late result tagged with the old generation never lands.
    await pipeline.ingest(.battery(.init(presence: .internalBattery, percentage: 7)),
                          for: .battery, generation: staleGeneration)
    await pipeline.drain()

    let states = await pipeline.states
    #expect(states.isEmpty)
    // Only the removal from the stop is delivered; the stale completion never
    // becomes an update.
    let updates = spy.batches.flatMap { $0 }.filter { if case .update = $0 { return true } else { return false } }
    #expect(updates.isEmpty)
}

@MainActor
@Test func lateCompletionThroughTheEmitClosureIsAlsoIgnored() async {
    let spy = DeliverySpy()
    let provider = TestProvider(id: .clock)
    let pipeline = WidgetPipeline(sink: { states in spy.record(states) }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    let oldEmit = provider.capturedEmit()

    await pipeline.stop(.clock)
    await pipeline.start(.clock)

    // The old activation's closure still fires with its captured generation.
    oldEmit?(.clock(ClockSnapshot(date: Date(timeIntervalSinceReferenceDate: 0))))
    // Give the injected ingest task a turn to (not) land.
    try? await Task.sleep(nanoseconds: 20_000_000)
    await pipeline.drain()

    let states = await pipeline.states
    #expect(states.isEmpty)
    let updates = spy.batches.flatMap { $0 }.filter { if case .update = $0 { return true } else { return false } }
    #expect(updates.isEmpty)
}

@MainActor
@Test func oneProviderFailureDoesNotStopTheOthers() async {
    let spy = DeliverySpy()
    let battery = TestProvider(id: .battery)
    let clock = TestProvider(id: .clock)
    let pipeline = WidgetPipeline(sink: { states in spy.record(states) }, autoDrain: false)
    await pipeline.register(battery)
    await pipeline.register(clock)
    await pipeline.start()
    let batteryGen = await pipeline.generation(of: .battery)!
    let clockGen = await pipeline.generation(of: .clock)!

    await pipeline.ingest(.unavailable(.init(kind: .failed, message: "battery read failed")),
                          for: .battery, generation: batteryGen)
    await pipeline.ingest(.clock(ClockSnapshot(date: Date(timeIntervalSinceReferenceDate: 0))),
                          for: .clock, generation: clockGen)
    await pipeline.drain()

    let states = await pipeline.states
    #expect(states.count == 2)
    #expect(states.first { $0.id == .battery }?.content.isUnavailable == true)
    #expect(states.first { $0.id == .clock } != nil)
    // The clock keeps its slot while the battery reports its own failure.
    let clockRunning = await pipeline.isRunning(.clock)
    #expect(clockRunning)
}

@MainActor
@Test func burstEmissionsArriveAsOneCoalescedBatchOnMain() async {
    let spy = DeliverySpy()
    let provider = TestProvider(id: .volume)
    let pipeline = WidgetPipeline(sink: { states in spy.record(states) }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    let generation = await pipeline.generation(of: .volume)!

    await pipeline.ingest(.volume(.init(hasOutputDevice: true, level: 0.1)), for: .volume, generation: generation)
    await pipeline.ingest(.volume(.init(hasOutputDevice: true, level: 0.2)), for: .volume, generation: generation)
    await pipeline.ingest(.volume(.init(hasOutputDevice: true, level: 0.9)), for: .volume, generation: generation)
    await pipeline.drain()

    #expect(spy.batches.count == 1)
    #expect(spy.allOnMain)
    let change = try! #require(spy.batches.first?.first)
    guard case .update(let state) = change else {
        Issue.record("expected an update, got \(change)")
        return
    }
    guard case .volume(let snapshot) = state.content else {
        Issue.record("expected volume content, got \(state.content)")
        return
    }
    #expect(snapshot.level == 0.9)
}

@MainActor
@Test func configureStopsRemovedProvidersAndStartsNewOnes() async {
    let battery = TestProvider(id: .battery)
    let network = TestProvider(id: .network)
    let pipeline = WidgetPipeline(sink: { _ in }, autoDrain: false)
    await pipeline.register(battery)
    await pipeline.start()
    #expect(battery.startCount == 1)

    await pipeline.configure([network])

    let batteryRunning = await pipeline.isRunning(.battery)
    let networkRunning = await pipeline.isRunning(.network)
    #expect(battery.cancelCount == 1)
    #expect(batteryRunning == false)
    #expect(networkRunning)
}

@MainActor
@Test func configureKeepsUnchangedProvidersRunning() async {
    let battery = TestProvider(id: .battery)
    let pipeline = WidgetPipeline(sink: { _ in }, autoDrain: false)
    await pipeline.register(battery)
    await pipeline.start()

    await pipeline.configure([battery])

    #expect(battery.startCount == 1)
    #expect(battery.cancelCount == 0)
    let running = await pipeline.isRunning(.battery)
    #expect(running)
}

@MainActor
@Test func stoppingAProviderTellsTheSinkToClearTheItem() async {
    let spy = DeliverySpy()
    let provider = TestProvider(id: .battery)
    let pipeline = WidgetPipeline(sink: { changes in spy.record(changes) }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    let generation = await pipeline.generation(of: .battery)!
    await pipeline.ingest(.battery(.init(presence: .internalBattery, percentage: 60)),
                          for: .battery, generation: generation)
    await pipeline.drain()
    #expect(spy.batches.count == 1)

    await pipeline.stop(.battery)
    await pipeline.drain()

    // A removal is delivered, so a widget that stays in the layout cannot keep
    // showing a value that is no longer being kept current.
    let change = try! #require(spy.batches.last?.first)
    #expect(change == .removed(.battery))
    let states = await pipeline.states
    #expect(states.isEmpty)
}

@MainActor
@Test func restartingBeforeTheDrainDeliversTheFreshValueNotARemoval() async {
    let spy = DeliverySpy()
    let provider = TestProvider(id: .battery)
    let pipeline = WidgetPipeline(sink: { changes in spy.record(changes) }, autoDrain: false)
    await pipeline.register(provider)
    await pipeline.start()
    let first = await pipeline.generation(of: .battery)!
    await pipeline.ingest(.battery(.init(presence: .internalBattery, percentage: 10)),
                          for: .battery, generation: first)

    // Stop and restart before any drain: the item is still in the layout.
    await pipeline.stop(.battery)
    await pipeline.start(.battery)
    let second = await pipeline.generation(of: .battery)!
    await pipeline.ingest(.battery(.init(presence: .internalBattery, percentage: 90)),
                          for: .battery, generation: second)
    await pipeline.drain()

    let change = try! #require(spy.batches.last?.first)
    guard case .update(let state) = change else {
        Issue.record("expected the fresh value, got \(change)")
        return
    }
    guard case .battery(let snapshot) = state.content else {
        Issue.record("expected battery content, got \(state.content)")
        return
    }
    #expect(snapshot.percentage == 90)
}

@Test func subscriptionBagCancelsLateAdditionsImmediately() {
    // A provider may register its observation on another actor. If `stop`
    // arrives first, the late subscription must still be cancelled, or it would
    // outlive the activation.
    final class Counter: @unchecked Sendable { var count = 0 }

    let late = Counter()
    let bag = SubscriptionBag()
    bag.cancel()
    bag.add(CallbackSubscription { late.count += 1 })
    #expect(late.count == 1)

    let early = Counter()
    let bag2 = SubscriptionBag()
    bag2.add(CallbackSubscription { early.count += 1 })
    #expect(early.count == 0)
    bag2.cancel()
    #expect(early.count == 1)
}
