import Foundation
import CoreAudio
import IOKit.ps
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
    private var changeHandler: (@Sendable (BatterySnapshot?) -> Void)?
    private var cancels = 0

    var snapshotValue: BatterySnapshot? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }

    var cancelCount: Int { lock.lock(); defer { lock.unlock() }; return cancels }

    func snapshot() -> BatterySnapshot? { snapshotValue }

    func observeChanges(_ handler: @escaping @Sendable (BatterySnapshot?) -> Void) -> any ProviderSubscription {
        lock.lock(); changeHandler = handler; lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.cancels += 1; self.lock.unlock()
        }
    }

    func fire() {
        lock.lock()
        let handler = changeHandler
        let value = self.value
        lock.unlock()
        handler?(value)
    }
}

/// A keep-awake state the test can flip, so the battery provider's fold-in is
/// checked without holding a real power assertion.
private final class MockKeepAwake: KeepAwakeObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    private var handler: (@Sendable (Bool) -> Void)?
    private var cancels = 0

    var isActive: Bool { lock.lock(); defer { lock.unlock() }; return value }
    var cancelCount: Int { lock.lock(); defer { lock.unlock() }; return cancels }

    func observe(_ handler: @escaping @Sendable (Bool) -> Void) -> any ProviderSubscription {
        lock.lock(); self.handler = handler; lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.cancels += 1; self.lock.unlock()
        }
    }

    func set(_ newValue: Bool) {
        lock.lock(); value = newValue; let handler = self.handler; lock.unlock()
        handler?(newValue)
    }
}

private final class MockNetworkReading: NetworkReading, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (NetworkSnapshot) -> Void)?
    private var cancels = 0

    var cancelCount: Int { lock.lock(); defer { lock.unlock() }; return cancels }

    func observe(readWifiName: Bool, handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription {
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
    // The clock split into date and time (#0033). The default bar shows time;
    // date is provider-backed too, once the user places it. Neither is the old
    // combined clock.
    #expect(ids == [.frontApp, .battery, .network, .volume, .time])
    #expect(!ids.contains(.clock))
    // Workspaces is the workspace-adapter milestone and is intentionally absent
    // rather than faked with numbered spaces.
    #expect(!ids.contains(.workspaces))
    // Every default right-side item is supplied by a provider.
    for item in BarLayout.default.right {
        #expect(ids.contains(item))
    }
    // Placing the date item gives it a provider as well.
    var withDate = DivotConfiguration.default
    withDate.move(.date, to: .right)
    #expect(DefaultWidgetProviders.placedProviderIDs(in: withDate).contains(.date))
}

@Test func clockProviderActivationKeyReflectsItsOptions() {
    // A changed clock option must be a changed activation so reconfigure
    // restarts the ticker instead of keeping the old resolution.
    #expect(ClockProvider(seconds: true).activationKey != ClockProvider(seconds: false).activationKey)
    #expect(ClockProvider(seconds: true).activationKey == ClockProvider(seconds: true).activationKey)
    #expect(ClockProvider().activationKey == ClockProvider(seconds: false).activationKey)
}

@MainActor
@Test func defaultProviderActivationsAreStableAcrossCalls() {
    // A fresh default set must compare equal to the running one, so a reconfigure
    // does not needlessly restart every provider.
    let first = DefaultWidgetProviders.make()
    let second = DefaultWidgetProviders.make()
    #expect(first.map(\.activationKey) == second.map(\.activationKey))
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
    guard case .battery(let charging)? = collector.contents.last else {
        Issue.record("expected a charging battery snapshot")
        return
    }
    #expect(charging.isCharging)
    #expect(charging.percentage == 41)

    subscription.cancel()
    #expect(reading.cancelCount == 1)
}

@Test func batteryProviderFollowsFakePowerSourcePlugInAndUnplug() {
    // A fake power source drives a full plug-in then unplug transition. The
    // provider must read the charging flag on each notification and emit it, so
    // the bolt appears on plug-in and disappears on unplug rather than waiting
    // for a percentage change.
    let reading = MockBatteryReading()
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 60,
                                  isCharging: false, isPluggedIn: false)
    let collector = ContentCollector()
    let subscription = BatteryProvider(reading: reading).start { collector.append($0) }
    #expect(collector.contents.count == 1)

    // Plug in: the state may be read before the charging flag flips, then a
    // bounded re-check catches it.
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 60,
                                  isCharging: false, isPluggedIn: true)
    reading.fire()
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 60,
                                  isCharging: true, isPluggedIn: true)
    reading.fire()
    guard case .battery(let charging)? = collector.contents.last else {
        Issue.record("expected a charging battery snapshot")
        return
    }
    #expect(charging.isCharging)
    #expect(charging.isPluggedIn)

    // Unplug: the flag clears at once.
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 60,
                                  isCharging: false, isPluggedIn: false)
    reading.fire()
    guard case .battery(let unplugged)? = collector.contents.last else {
        Issue.record("expected an unplugged battery snapshot")
        return
    }
    #expect(!unplugged.isCharging)
    #expect(!unplugged.isPluggedIn)
    #expect(collector.contents.count == 4)

    subscription.cancel()
}

@Test func batteryProviderDoesNotReemitAnUnchangedSnapshot() {
    // The bounded re-check can read the same state several times; only a real
    // change should reach the pipeline, so the bar does not redraw needlessly.
    let reading = MockBatteryReading()
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 42, isCharging: true)
    let collector = ContentCollector()
    let subscription = BatteryProvider(reading: reading).start { collector.append($0) }
    #expect(collector.contents.count == 1)

    reading.fire()
    reading.fire()
    #expect(collector.contents.count == 1)

    // A real change still emits.
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 43, isCharging: true)
    reading.fire()
    #expect(collector.contents.count == 2)

    subscription.cancel()
}

@Test func batteryProviderReportsFailureInsteadOfGuessing() {
    let reading = MockBatteryReading()
    reading.snapshotValue = nil
    let collector = ContentCollector()
    _ = BatteryProvider(reading: reading).start { collector.append($0) }
    let content = collector.contents.first
    #expect(content?.isUnavailable == true)
}

@Test func batteryProviderCarriesKeepAwakeAndFollowsToggle() {
    let reading = MockBatteryReading()
    reading.snapshotValue = .init(presence: .internalBattery, percentage: 42)
    let keepAwake = MockKeepAwake()
    let collector = ContentCollector()
    let subscription = BatteryProvider(reading: reading, keepAwake: keepAwake).start { collector.append($0) }

    guard case .battery(let first)? = collector.contents.first else {
        Issue.record("expected an initial battery snapshot")
        return
    }
    #expect(first.percentage == 42)
    #expect(!first.isKeepingAwake)

    keepAwake.set(true)
    guard case .battery(let second)? = collector.contents.last, collector.contents.count == 2 else {
        Issue.record("expected a keep-awake emission")
        return
    }
    #expect(second.isKeepingAwake)
    #expect(second.percentage == 42)

    keepAwake.set(false)
    guard case .battery(let third)? = collector.contents.last, collector.contents.count == 3 else {
        Issue.record("expected a keep-awake-off emission")
        return
    }
    #expect(!third.isKeepingAwake)

    subscription.cancel()
    #expect(reading.cancelCount == 1)
    #expect(keepAwake.cancelCount == 1)
}

/// The cup means "Divot is holding its own assertion right now", never "some
/// app is keeping the Mac awake". The battery provider never inspects system
/// sleep state: its only keep-awake input is Divot's own controller, so a
/// power-source refresh (the kind that arrives while a call holds the mic and
/// speaker sleep assertions) still leaves the item cup-free until Divot's own
/// assertion is on.
@Test func batteryProviderShowsTheCupOnlyForDivotsOwnAssertion() {
    let reading = MockBatteryReading()
    // A plugged-in, charging power source is typical of an active call and is
    // the state during which other apps' sleep assertions appear.
    reading.snapshotValue = .init(presence: .internalBattery,
                                  percentage: 63,
                                  isCharging: true,
                                  isPluggedIn: true)
    let keepAwake = MockKeepAwake()
    let collector = ContentCollector()
    let subscription = BatteryProvider(reading: reading, keepAwake: keepAwake)
        .start { collector.append($0) }

    // Toggle off: no cup, even though the machine may be held awake elsewhere.
    guard case .battery(let off)? = collector.contents.last else {
        Issue.record("expected an initial battery snapshot")
        return
    }
    #expect(!off.isKeepingAwake)
    #expect(WidgetPresenter.present(id: .battery,
                                    state: WidgetState(id: .battery, revision: 1, content: .battery(off)))
        .indicator == nil)

    // A power-source notification (another app's assertion changing) must not
    // draw the cup while Divot's own toggle is off.
    reading.fire()
    guard case .battery(let stillOff)? = collector.contents.last else {
        Issue.record("expected a battery snapshot after the power notification")
        return
    }
    #expect(!stillOff.isKeepingAwake)

    // Divot's own assertion on: the cup appears.
    keepAwake.set(true)
    guard case .battery(let on)? = collector.contents.last else {
        Issue.record("expected a keep-awake emission")
        return
    }
    #expect(on.isKeepingAwake)
    let presentation = WidgetPresenter.present(id: .battery,
                                               state: WidgetState(id: .battery, revision: 1, content: .battery(on)))
    #expect(presentation.indicator?.role == .keepAwakeActive)

    subscription.cancel()
    #expect(reading.cancelCount == 1)
    #expect(keepAwake.cancelCount == 1)
}

/// The raw IOKit power-source read must never infer keep-awake: only the
/// provider merges Divot's own assertion. If this ever flips, the cup would
/// light up for any app that prevents sleep.
@Test func batteryReadingNeverInfersKeepAwakeFromSystemPowerState() {
    let description: [String: Any] = [
        kIOPSCurrentCapacityKey: 80,
        kIOPSMaxCapacityKey: 100,
        kIOPSIsChargingKey: true,
        kIOPSIsChargedKey: false,
        kIOPSPowerSourceStateKey: kIOPSACPowerValue,
    ]
    let snapshot = IOKitBatteryReading.snapshot(from: description)
    #expect(snapshot.presence == .internalBattery)
    #expect(snapshot.isCharging)
    #expect(!snapshot.isKeepingAwake)
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

@Test func networkProviderShowsWifiNameWhenAuthorized() {
    let reading = MockNetworkReading()
    let collector = ContentCollector()
    let subscription = NetworkProvider(reading: reading, readWifiName: true).start { collector.append($0) }

    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", wifiName: "MyNetwork", locationAuthorizationStatus: "authorizedWhenInUse"))
    #expect(collector.contents.count == 1)
    guard case .network(let snapshot)? = collector.contents.last else {
        Issue.record("expected a network snapshot")
        return
    }
    #expect(snapshot.wifiName == "MyNetwork")
    #expect(snapshot.locationAuthorizationStatus == "authorizedWhenInUse")

    subscription.cancel()
    #expect(reading.cancelCount == 1)
}

@Test func networkProviderHidesWifiNameWhenDenied() {
    let reading = MockNetworkReading()
    let collector = ContentCollector()
    let subscription = NetworkProvider(reading: reading, readWifiName: true).start { collector.append($0) }

    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", wifiName: nil, locationAuthorizationStatus: "denied"))
    #expect(collector.contents.count == 1)
    guard case .network(let snapshot)? = collector.contents.last else {
        Issue.record("expected a network snapshot")
        return
    }
    #expect(snapshot.wifiName == nil)
    #expect(snapshot.locationAuthorizationStatus == "denied")

    subscription.cancel()
}

@Test func networkProviderShowsNotDeterminedState() {
    let reading = MockNetworkReading()
    let collector = ContentCollector()
    let subscription = NetworkProvider(reading: reading, readWifiName: true).start { collector.append($0) }

    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", wifiName: nil, locationAuthorizationStatus: "notDetermined"))
    #expect(collector.contents.count == 1)
    guard case .network(let snapshot)? = collector.contents.last else {
        Issue.record("expected a network snapshot")
        return
    }
    #expect(snapshot.wifiName == nil)
    #expect(snapshot.locationAuthorizationStatus == "notDetermined")

    subscription.cancel()
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

@Test func timeProviderEmitsImmediatelyThenAtBoundaries() async {
    let base = Date(timeIntervalSinceReferenceDate: 0)
    let source = TestClockSource(dates: [base, base, base.addingTimeInterval(60),
                                         base.addingTimeInterval(60), base.addingTimeInterval(120)])
    let collector = ContentCollector()
    let subscription = TimeProvider(source: source).start { collector.append($0) }

    await waitUntil { collector.contents.count >= 3 }
    subscription.cancel()

    let contents = collector.contents
    #expect(contents.count >= 2, "expected the initial snapshot plus a boundary tick")
    guard case .time(let first)? = contents.first else {
        Issue.record("expected a time snapshot on start")
        return
    }
    #expect(first.date == base)
    // Every emission is a time payload; the provider never falls back to noData.
    for content in contents {
        #expect(!content.isUnavailable, "TimeProvider must never emit noData")
        guard case .time = content else {
            Issue.record("expected only .time content")
            return
        }
    }
    // The default time item wakes at the next minute boundary.
    #expect(source.sleeps.first == 60)
}

@Test func timeProviderWithSecondsWakesEverySecondBoundary() async {
    let base = Date(timeIntervalSinceReferenceDate: 0)
    let source = TestClockSource(dates: [base, base, base.addingTimeInterval(1)])
    let collector = ContentCollector()
    let subscription = TimeProvider(seconds: true, source: source).start { collector.append($0) }

    await waitUntil { collector.contents.count >= 2 }
    subscription.cancel()

    guard case .time? = collector.contents.first else {
        Issue.record("expected a time snapshot")
        return
    }
    #expect(source.sleeps.first == 1)
}

@Test func dateProviderEmitsImmediatelyAndWakesAtTheDayBoundary() async {
    let base = Date(timeIntervalSinceReferenceDate: 0)
    let source = TestClockSource(dates: [base, base, base.addingTimeInterval(86400)])
    let collector = ContentCollector()
    let subscription = DateProvider(source: source).start { collector.append($0) }

    await waitUntil { collector.contents.count >= 2 }
    subscription.cancel()

    let contents = collector.contents
    #expect(contents.count >= 2, "expected the initial snapshot plus a day-boundary tick")
    guard case .date(let first)? = contents.first else {
        Issue.record("expected a date snapshot on start")
        return
    }
    #expect(first.date == base)
    // Every emission is a date payload; the provider never falls back to noData.
    for content in contents {
        #expect(!content.isUnavailable, "DateProvider must never emit noData")
        guard case .date = content else {
            Issue.record("expected only .date content")
            return
        }
    }
    // A date changes once a day, so the loop must not wake every minute.
    #expect((source.sleeps.first ?? 0) > 60 * 60)
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

// MARK: - Volume watcher cancellation

/// Records Core Audio listener registrations and can replay a callback that was
/// queued before cancellation.
private final class MockAudioBackend: AudioPropertyListening, @unchecked Sendable {
    private let lock = NSLock()
    private var deviceValue: AudioDeviceID? = 101
    private var registrations: [(object: AudioObjectID, token: AudioListenerToken)] = []
    private var everHandlers: [(object: AudioObjectID, handler: @Sendable () -> Void)] = []
    private var adds = 0
    private var removes = 0
    /// Property elements the mock device exposes, per selector. Defaults to the
    /// main element, matching a device with a master volume/mute control.
    private var supportedElements: [AudioObjectPropertySelector: Set<AudioObjectPropertyElement>] = [
        kAudioDevicePropertyVolumeScalar: [kAudioObjectPropertyElementMain],
        kAudioDevicePropertyMute: [kAudioObjectPropertyElementMain],
    ]

    var addCount: Int { lock.lock(); defer { lock.unlock() }; return adds }
    var removeCount: Int { lock.lock(); defer { lock.unlock() }; return removes }

    var registeredAddresses: [AudioObjectPropertyAddress] {
        lock.lock(); defer { lock.unlock() }
        return registrations.map(\.token.address)
    }

    /// Models a device that only exposes per-channel controls (no main element).
    func setSupportedElements(_ elements: Set<AudioObjectPropertyElement>,
                              for selector: AudioObjectPropertySelector) {
        lock.lock(); supportedElements[selector] = elements; lock.unlock()
    }

    var device: AudioDeviceID? {
        get { lock.lock(); defer { lock.unlock() }; return deviceValue }
        set { lock.lock(); deviceValue = newValue; lock.unlock() }
    }

    func defaultOutputDevice() -> AudioDeviceID? { device }

    func hasProperty(on object: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return supportedElements[address.mSelector]?.contains(address.mElement) ?? false
    }

    func addListener(on object: AudioObjectID,
                     address: AudioObjectPropertyAddress,
                     queue: DispatchQueue,
                     handler: @escaping @Sendable () -> Void) -> AudioListenerToken {
        lock.lock()
        adds += 1
        let token = AudioListenerToken(address: address, block: { _, _ in })
        registrations.append((object, token))
        everHandlers.append((object, handler))
        lock.unlock()
        return token
    }

    func removeListener(_ token: AudioListenerToken, on object: AudioObjectID, queue: DispatchQueue) {
        lock.lock()
        removes += 1
        registrations.removeAll { $0.token === token }
        lock.unlock()
    }

    func fireSystemHandlersEver() { fire { $0 == AudioObjectID(kAudioObjectSystemObject) } }
    func fireDeviceHandlersEver() { fire { $0 != AudioObjectID(kAudioObjectSystemObject) } }

    private func fire(_ matches: (AudioObjectID) -> Bool) {
        lock.lock()
        let handlers = everHandlers.filter { matches($0.object) }.map(\.handler)
        lock.unlock()
        for handler in handlers { handler() }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

@Test func volumeWatcherReinstallsOnDeviceSwitchButNotAfterStop() {
    let backend = MockAudioBackend()
    let fires = Counter()
    let watcher = CoreAudioVolumeWatcher(backend: backend) { fires.increment() }
    watcher.start()
    // System listener + volume + mute on the current default device.
    #expect(backend.addCount == 3)

    // A live default-device switch replaces the two device listeners.
    backend.fireSystemHandlersEver()
    #expect(backend.addCount == 5)
    #expect(backend.removeCount == 2)
    #expect(fires.count == 1)

    watcher.stop()
    let removesAtStop = backend.removeCount
    #expect(removesAtStop == 5)

    // Callbacks already queued at cancellation must be ignored and must not
    // install new listeners or fire the handler.
    backend.fireSystemHandlersEver()
    backend.fireDeviceHandlersEver()
    #expect(fires.count == 1)
    #expect(backend.addCount == 5)
    #expect(backend.removeCount == removesAtStop)

    // Cancellation is idempotent.
    watcher.stop()
    #expect(backend.removeCount == removesAtStop)
}

@Test func volumeWatcherObservesPerChannelControlsWhenMainElementIsAbsent() {
    let backend = MockAudioBackend()
    // A device with no main-element control exposes volume on the two front
    // channels and mute on channel 1. The watcher must observe those elements,
    // or the displayed value goes stale after a volume or mute change.
    backend.setSupportedElements([1, 2], for: kAudioDevicePropertyVolumeScalar)
    backend.setSupportedElements([1], for: kAudioDevicePropertyMute)

    let fires = Counter()
    let watcher = CoreAudioVolumeWatcher(backend: backend) { fires.increment() }
    watcher.start()

    // System listener + per-channel volume (1, 2) + per-channel mute (1).
    #expect(backend.addCount == 4)
    let volumeElements = Set(backend.registeredAddresses
        .filter { $0.mSelector == kAudioDevicePropertyVolumeScalar }
        .map(\.mElement))
    #expect(volumeElements == [1, 2])
    let muteElements = Set(backend.registeredAddresses
        .filter { $0.mSelector == kAudioDevicePropertyMute }
        .map(\.mElement))
    #expect(muteElements == [1])

    backend.fireDeviceHandlersEver()
    // All three observed channel listeners deliver a change callback.
    #expect(fires.count == 3)

    watcher.stop()
}

@Test func volumeWatcherPrefersTheMainElementWhenTheDeviceExposesIt() {
    let backend = MockAudioBackend()
    let watcher = CoreAudioVolumeWatcher(backend: backend) { }
    watcher.start()

    // Default mock exposes only the main element for both controls.
    let elements = backend.registeredAddresses
        .filter { $0.mSelector == kAudioDevicePropertyVolumeScalar || $0.mSelector == kAudioDevicePropertyMute }
        .map(\.mElement)
    #expect(elements == [kAudioObjectPropertyElementMain, kAudioObjectPropertyElementMain])
    watcher.stop()
}

@Test func volumeReadingReportsNoOutputWhenThereIsNoDevice() {
    let backend = MockAudioBackend()
    backend.device = nil
    #expect(CoreAudioVolumeReading(backend: backend).snapshot() == .noOutput)
}

@Test func networkReadingRequestsLocationOnlyWhenWifiNameIsRead() {
    // The permission request is tied to `readWifiName` — the same value as the
    // Wi-Fi name toggle — so a provider that does not read the name never asks.
    let off = StubLocationTracker(status: .notDetermined)
    let readingOff = NWPathNetworkReading(locationTracker: off)
    let offSubscription = readingOff.observe(readWifiName: false) { _ in }
    #expect(off.requestCount == 0)
    offSubscription.cancel()

    let on = StubLocationTracker(status: .notDetermined)
    let readingOn = NWPathNetworkReading(locationTracker: on)
    let onSubscription = readingOn.observe(readWifiName: true) { _ in }
    #expect(on.requestCount == 1)
    onSubscription.cancel()
}

@Test func networkProviderTracksAllAuthorizationStates() {
    let reading = MockNetworkReading()
    let collector = ContentCollector()
    let subscription = NetworkProvider(reading: reading, readWifiName: true).start { collector.append($0) }
    
    // Test notDetermined state
    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", locationAuthorizationStatus: "notDetermined"))
    guard case .network(let snapshot1)? = collector.contents.last else {
        Issue.record("expected a network snapshot for notDetermined")
        return
    }
    #expect(snapshot1.locationAuthorizationStatus == "notDetermined")
    #expect(snapshot1.wifiName == nil)
    
    // Test denied state
    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", locationAuthorizationStatus: "denied"))
    guard case .network(let snapshot2)? = collector.contents.last else {
        Issue.record("expected a network snapshot for denied")
        return
    }
    #expect(snapshot2.locationAuthorizationStatus == "denied")
    #expect(snapshot2.wifiName == nil)
    
    // Test authorizedWhenInUse state
    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", wifiName: "Network1", locationAuthorizationStatus: "authorizedWhenInUse"))
    guard case .network(let snapshot3)? = collector.contents.last else {
        Issue.record("expected a network snapshot for authorizedWhenInUse")
        return
    }
    #expect(snapshot3.locationAuthorizationStatus == "authorizedWhenInUse")
    #expect(snapshot3.wifiName == "Network1")
    
    // Test authorizedAlways state
    reading.emit(.init(isConnected: true, kind: .wifi, interfaceName: "en0", wifiName: "Network2", locationAuthorizationStatus: "authorizedAlways"))
    guard case .network(let snapshot4)? = collector.contents.last else {
        Issue.record("expected a network snapshot for authorizedAlways")
        return
    }
    #expect(snapshot4.locationAuthorizationStatus == "authorizedAlways")
    #expect(snapshot4.wifiName == "Network2")
    
    subscription.cancel()
    #expect(reading.cancelCount == 1)
}
