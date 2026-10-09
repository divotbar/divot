import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

/// Thread-safe sink for emissions from a provider's background task.
private final class ContentCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [WidgetContent] = []

    func append(_ content: WidgetContent) {
        lock.lock(); items.append(content); lock.unlock()
    }

    var contents: [WidgetContent] {
        lock.lock(); defer { lock.unlock() }
        return items
    }
}

private func waitUntil(_ condition: @Sendable () -> Bool, timeout: TimeInterval = 2) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
}

// MARK: - Mocks

private final class MockBatteryReading: BatteryReading, @unchecked Sendable {
    private let lock = NSLock()
    private var value: BatterySnapshot?
    private var changeHandler: (@Sendable () -> Void)?
    private var cancels = 0

    var snapshotValue: BatterySnapshot? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }

    var cancelCount: Int { lock.lock(); defer { lock.unlock() }; return cancels }

    func snapshot() -> BatterySnapshot? { snapshotValue }

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription {
        lock.lock(); changeHandler = handler; lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.cancels += 1; self.lock.unlock()
        }
    }

    func fire() {
        lock.lock(); let handler = changeHandler; lock.unlock()
        handler?()
    }
}

private final class MockNetworkReading: NetworkReading, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (NetworkSnapshot) -> Void)?
    private var cancels = 0

    var cancelCount: Int { lock.lock(); defer { lock.unlock() }; return cancels }

    func observe(_ handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription {
        lock.lock(); self.handler = handler; lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.cancels += 1; self.lock.unlock()
        }
    }

    func emit(_ snapshot: NetworkSnapshot) {
        lock.lock(); let handler = self.handler; lock.unlock()
        handler?(snapshot)
    }
}

private final class MockVolumeReading: VolumeReading, @unchecked Sendable {
    private let lock = NSLock()
    private var value: VolumeSnapshot?
    private var handler: (@Sendable () -> Void)?

    var snapshotValue: VolumeSnapshot? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }

    func snapshot() -> VolumeSnapshot? { snapshotValue }

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription {
        lock.lock(); self.handler = handler; lock.unlock()
        return CallbackSubscription {}
    }

    func fire() {
        lock.lock(); let handler = self.handler; lock.unlock()
        handler?()
    }
}

/// A clock source that advances through fixed instants and ends after a few
/// sleeps, so the loop terminates deterministically without real waiting.
private final class TestClockSource: ClockSource, @unchecked Sendable {
    private let dates: [Date]
    private var index = 0
    private var sleepCount = 0
    private(set) var sleeps: [TimeInterval] = []

    init(dates: [Date]) { self.dates = dates }

    func now() -> Date {
        dates[min(index, dates.count - 1)]
    }

    func sleep(seconds: TimeInterval) async throws {
        sleeps.append(seconds)
        sleepCount += 1
        index += 1
        if sleepCount >= 3 { throw CancellationError() }
    }
}

@MainActor
private final class MockFrontAppReading: FrontAppReading {
    var snapshotValue: FrontAppSnapshot?
    var changeHandler: (@MainActor @Sendable () -> Void)?

    func snapshot() -> FrontAppSnapshot? { snapshotValue }

    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> any ProviderSubscription {
        changeHandler = handler
        return CallbackSubscription {}
    }
}

// MARK: - Provider tests

@MainActor
@Test func defaultProvidersCoverEveryStatusItemExceptWorkspaces() {
    let ids = Set(DefaultWidgetProviders.make().map(\.id))
    #expect(ids == [.frontApp, .battery, .network, .volume, .clock])
    // Workspaces is the workspace-adapter milestone and is intentionally absent
    // rather than faked with numbered spaces.
    #expect(!ids.contains(.workspaces))
    // Every default right-side item is supplied by a provider.
    for item in BarLayout.default.right {
        #expect(ids.contains(item))
    }
}

@Test func batteryProviderEmitsInitialValueChangeAndCancels() {
    let reading = MockBatteryReading()
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 42)
    let collector = ContentCollector()
    let provider = BatteryProvider(reading: reading)

    let subscription = provider.start { collector.append($0) }
    #expect(collector.contents.count == 1)
    guard case .battery(let first)? = collector.contents.first else {
        Issue.record("expected a battery snapshot")
        return
    }
    #expect(first.percentage == 42)

    reading.snapshotValue = .init(presence: .internalBattery, percentage: 41, isCharging: true)
    reading.fire()
    #expect(collector.contents.count == 2)

    subscription.cancel()
    #expect(reading.cancelCount == 1)
}

@Test func batteryProviderReportsFailureInsteadOfGuessing() {
    let reading = MockBatteryReading()
    reading.snapshotValue = nil
    let collector = ContentCollector()
    _ = BatteryProvider(reading: reading).start { collector.append($0) }
    let content = collector.contents.first
    #expect(content?.isUnavailable == true)
}

@Test func networkProviderForwardsPathSnapshots() {
    let reading = MockNetworkReading()
    let collector = ContentCollector()
    let subscription = NetworkProvider(reading: reading).start { collector.append($0) }

    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0"))
    #expect(collector.contents.count == 1)
    guard case .network(let snapshot)? = collector.contents.first else {
        Issue.record("expected a network snapshot")
        return
    }
    #expect(snapshot.kind == .wifi)
    #expect(snapshot.interfaceName == "en0")

    subscription.cancel()
    #expect(reading.cancelCount == 1)
}

@Test func volumeProviderEmitsAndFollowsChanges() {
    let reading = MockVolumeReading()
    reading.snapshotValue = .init(hasOutputDevice: true, level: 0.3)
    let collector = ContentCollector()
    _ = VolumeProvider(reading: reading).start { collector.append($0) }
    #expect(collector.contents.count == 1)

    reading.snapshotValue = .init(hasOutputDevice: true, level: 0.9, isMuted: true)
    reading.fire()
    #expect(collector.contents.count == 2)
}

@Test func clockProviderEmitsImmediatelyThenAtBoundaries() async {
    let base = Date(timeIntervalSinceReferenceDate: 0)
    let source = TestClockSource(dates: [base, base, base.addingTimeInterval(60),
                                         base.addingTimeInterval(60), base.addingTimeInterval(120)])
    let collector = ContentCollector()
    let subscription = ClockProvider(source: source).start { collector.append($0) }

    await waitUntil { collector.contents.count >= 3 }
    subscription.cancel()

    let contents = collector.contents
    #expect(contents.count >= 1)
    guard case .clock? = contents.first else {
        Issue.record("expected a clock snapshot")
        return
    }
    // A minute clock wakes ~60s out, never a zero-length or frame-rate poll.
    #expect(source.sleeps.first == 60)
}

@MainActor
@Test func frontAppProviderEmitsOnMainAndOnChange() async {
    let reading = MockFrontAppReading()
    reading.snapshotValue = FrontAppSnapshot(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
    let collector = ContentCollector()
    let subscription = FrontAppProvider(reading: reading).start { collector.append($0) }

    await waitUntil({ collector.contents.count >= 1 }, timeout: 2)
    guard case .frontApp(let first)? = collector.contents.first else {
        Issue.record("expected a front-app snapshot")
        subscription.cancel()
        return
    }
    #expect(first.name == "Xcode")

    reading.snapshotValue = FrontAppSnapshot(name: "Safari", bundleIdentifier: "com.apple.Safari")
    reading.changeHandler?()
    await waitUntil { collector.contents.count >= 2 }
    #expect(collector.contents.count >= 2)
    subscription.cancel()
}

@MainActor
@Test func frontAppProviderDegradesWhenNothingIsFrontmost() async {
    let reading = MockFrontAppReading()
    reading.snapshotValue = nil
    let collector = ContentCollector()
    let subscription = FrontAppProvider(reading: reading).start { collector.append($0) }

    await waitUntil { !collector.contents.isEmpty }
    #expect(collector.contents.first?.isUnavailable == true)
    subscription.cancel()
}
