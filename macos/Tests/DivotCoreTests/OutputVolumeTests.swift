import Foundation
import Testing
@testable import DivotCore

/// A fake output-volume seam that records writes and can replay an external
/// change, so the popover model is tested without touching a real device.
private final class FakeVolumeControl: OutputVolumeControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var value: VolumeSnapshot?
    private var handler: (@Sendable () -> Void)?
    private var levelWrites: [Double] = []
    private var muteWrites: [Bool] = []
    private let cancels = Counter()

    init(value: VolumeSnapshot?) { self.value = value }

    var snapshotValue: VolumeSnapshot? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }

    var writtenLevels: [Double] { lock.lock(); defer { lock.unlock() }; return levelWrites }
    var writtenMutes: [Bool] { lock.lock(); defer { lock.unlock() }; return muteWrites }
    var cancelCount: Int { cancels.value }

    func snapshot() -> VolumeSnapshot? { snapshotValue }

    func setLevel(_ level: Double) {
        lock.lock()
        levelWrites.append(level)
        // Model the device accepting the write and reporting it back, so the
        // model's post-write read sees the settled state.
        if let current = value {
            value = VolumeSnapshot(hasOutputDevice: current.hasOutputDevice,
                                   outputDeviceName: current.outputDeviceName,
                                   level: level,
                                   isMuted: current.isMuted,
                                   isSettable: current.isSettable)
        }
        lock.unlock()
    }

    func setMuted(_ muted: Bool) {
        lock.lock()
        muteWrites.append(muted)
        if let current = value {
            value = VolumeSnapshot(hasOutputDevice: current.hasOutputDevice,
                                   outputDeviceName: current.outputDeviceName,
                                   level: current.level,
                                   isMuted: muted,
                                   isSettable: current.isSettable)
        }
        lock.unlock()
    }

    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription {
        lock.lock(); self.handler = handler; lock.unlock()
        let cancels = self.cancels
        return CallbackSubscription { cancels.increment() }
    }

    /// Deliver an external change to the registered observer.
    func fire() {
        lock.lock(); let handler = self.handler; lock.unlock()
        handler?()
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

private func settable(_ level: Double, muted: Bool = false) -> VolumeSnapshot {
    VolumeSnapshot(hasOutputDevice: true, outputDeviceName: "Speakers",
                   level: level, isMuted: muted, isSettable: true)
}

private func unsettable() -> VolumeSnapshot {
    VolumeSnapshot(hasOutputDevice: true, outputDeviceName: "HDMI",
                   level: 1, isMuted: false, isSettable: false)
}

@Suite("Output volume level math")
struct OutputVolumeTests {
    @Test func clampedPinsTheUnitRange() {
        #expect(OutputVolume.clamped(-1) == 0)
        #expect(OutputVolume.clamped(0) == 0)
        #expect(OutputVolume.clamped(0.42) == 0.42)
        #expect(OutputVolume.clamped(1) == 1)
        #expect(OutputVolume.clamped(2) == 1)
    }

    @Test func clampedRejectsNonFiniteValues() {
        #expect(OutputVolume.clamped(.nan) == 0)
        #expect(OutputVolume.clamped(.infinity) == 0)
        #expect(OutputVolume.clamped(-.infinity) == 0)
    }

    @Test func percentRoundsToAWholeNumber() {
        #expect(OutputVolume.percent(0) == 0)
        #expect(OutputVolume.percent(0.5) == 50)
        #expect(OutputVolume.percent(0.505) == 51)
        #expect(OutputVolume.percent(2) == 100)
        #expect(OutputVolume.percent(-1) == 0)
    }
}

@Suite("Volume popover model")
@MainActor
struct VolumePopoverModelTests {
    @Test func readsTheCurrentStateOnRefresh() {
        let control = FakeVolumeControl(value: settable(0.4))
        let model = VolumePopoverModel(control: control)

        #expect(model.state == nil)
        model.refresh()
        #expect(model.state?.level == 0.4)
    }

    @Test func clampsALevelBeforeWritingIt() {
        let control = FakeVolumeControl(value: settable(0.5))
        let model = VolumePopoverModel(control: control)
        model.refresh()

        #expect(model.setLevel(1.5) == 1)
        #expect(model.setLevel(-0.2) == 0)
        #expect(control.writtenLevels == [1, 0])
        #expect(model.state?.level == 0)
    }

    @Test func setLevelPassesAValidValueThrough() {
        let control = FakeVolumeControl(value: settable(0.5))
        let model = VolumePopoverModel(control: control)
        model.refresh()

        #expect(model.setLevel(0.25) == 0.25)
        #expect(control.writtenLevels == [0.25])
        #expect(model.state?.level == 0.25)
    }

    @Test func muteToggleWritesAndReportsTheNewState() {
        let control = FakeVolumeControl(value: settable(0.5))
        let model = VolumePopoverModel(control: control)
        model.refresh()

        #expect(model.setMuted(true) == true)
        #expect(control.writtenMutes == [true])
        #expect(model.state?.isMuted == true)

        #expect(model.setMuted(false) == false)
        #expect(control.writtenMutes == [true, false])
        #expect(model.state?.isMuted == false)
    }

    @Test func anUnsettableOutputLeavesBothControlsInert() {
        let control = FakeVolumeControl(value: unsettable())
        let model = VolumePopoverModel(control: control)
        model.refresh()

        #expect(model.setLevel(0.3) == nil)
        #expect(model.setMuted(true) == nil)
        #expect(control.writtenLevels.isEmpty)
        #expect(control.writtenMutes.isEmpty)
    }

    @Test func noOutputDeviceWritesNothing() {
        let control = FakeVolumeControl(value: .noOutput)
        let model = VolumePopoverModel(control: control)
        model.refresh()

        #expect(model.setLevel(0.5) == nil)
        #expect(model.setMuted(true) == nil)
        #expect(control.writtenLevels.isEmpty)
        #expect(control.writtenMutes.isEmpty)
    }

    @Test func followsExternalChangesWhileOpen() async {
        let control = FakeVolumeControl(value: settable(0.2))
        let model = VolumePopoverModel(control: control)
        model.refresh()
        model.startObserving()

        // Another app (or the keyboard) changes the device; the model reloads.
        control.snapshotValue = settable(0.8)
        control.fire()
        await waitUntil { model.state?.level == 0.8 }
        #expect(model.state?.level == 0.8)
    }

    @Test func stoppingObservationCancelsTheSubscription() {
        let control = FakeVolumeControl(value: settable(0.2))
        let model = VolumePopoverModel(control: control)
        model.startObserving()
        model.startObserving()
        model.stopObserving()

        // The subscription is removed once, and observing again re-registers.
        #expect(control.cancelCount == 1)
        model.startObserving()
        model.stopObserving()
        #expect(control.cancelCount == 2)
    }
}

/// Poll a condition on the main actor until it holds or the timeout elapses.
@MainActor
private func waitUntil(_ condition: @escaping @MainActor () -> Bool,
                       timeout: TimeInterval = 2) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        await Task.yield()
    }
}
