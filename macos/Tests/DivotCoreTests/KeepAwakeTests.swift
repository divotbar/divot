import Foundation
import Testing
@testable import DivotCore

/// Records assertion lifecycles without touching the machine's power state.
private final class RecordingAssertionCreator: PowerAssertionCreating, @unchecked Sendable {
    private let lock = NSLock()
    private var acquires = 0
    private var releases = 0
    private var allowsAcquire = true
    private let reasonBox = ReasonBox()

    var acquireCount: Int { lock.lock(); defer { lock.unlock() }; return acquires }
    var releaseCount: Int { lock.lock(); defer { lock.unlock() }; return releases }
    var lastReason: String? { reasonBox.value }

    func disallowAcquire() { lock.lock(); allowsAcquire = false; lock.unlock() }

    func acquireAssertion(reason: String) -> (any PowerAssertionHandle)? {
        reasonBox.value = reason
        lock.lock()
        defer { lock.unlock() }
        guard allowsAcquire else { return nil }
        acquires += 1
        return RecordingAssertionHandle { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.releases += 1; self.lock.unlock()
        }
    }
}

private final class ReasonBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?
    var value: String? {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

private final class RecordingAssertionHandle: PowerAssertionHandle, @unchecked Sendable {
    private let onRelease: @Sendable () -> Void
    init(_ onRelease: @escaping @Sendable () -> Void) { self.onRelease = onRelease }
    func release() { onRelease() }
}

@Test func keepAwakeStartsOff() {
    let creator = RecordingAssertionCreator()
    let controller = KeepAwakeController(creator: creator)
    #expect(!controller.isActive)
    #expect(creator.acquireCount == 0)
}

@Test func turningOnAcquiresAndTurningOffReleasesTheAssertion() {
    let creator = RecordingAssertionCreator()
    let controller = KeepAwakeController(creator: creator)

    #expect(controller.setActive(true))
    #expect(controller.isActive)
    #expect(creator.acquireCount == 1)
    #expect(creator.releaseCount == 0)
    #expect(creator.lastReason?.contains("awake") == true)

    #expect(controller.setActive(false))
    #expect(!controller.isActive)
    #expect(creator.acquireCount == 1)
    #expect(creator.releaseCount == 1)
}

@Test func settingTheCurrentStateIsIdempotent() {
    let creator = RecordingAssertionCreator()
    let controller = KeepAwakeController(creator: creator)

    controller.setActive(true)
    controller.setActive(true)
    #expect(creator.acquireCount == 1)

    controller.setActive(false)
    controller.setActive(false)
    #expect(creator.releaseCount == 1)
}

@Test func aRefusedAssertionLeavesKeepAwakeOff() {
    let creator = RecordingAssertionCreator()
    creator.disallowAcquire()
    let controller = KeepAwakeController(creator: creator)

    #expect(!controller.setActive(true))
    #expect(!controller.isActive)
    #expect(creator.acquireCount == 0)
}

@Test func quitReleasesAHeldAssertion() {
    let creator = RecordingAssertionCreator()
    let controller = KeepAwakeController(creator: creator)
    controller.setActive(true)

    controller.releaseAll()

    #expect(!controller.isActive)
    #expect(creator.releaseCount == 1)
    // A later release is a no-op rather than a double free.
    controller.releaseAll()
    #expect(creator.releaseCount == 1)
}

@Test func observersSeeChangesUntilTheyCancel() {
    let creator = RecordingAssertionCreator()
    let controller = KeepAwakeController(creator: creator)
    let box = ObservingBox()

    let subscription = controller.observe { box.append($0) }
    controller.setActive(true)
    controller.setActive(false)
    subscription.cancel()
    controller.setActive(true)

    #expect(box.values == [true, false])
}

private final class ObservingBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Bool] = []
    func append(_ value: Bool) { lock.lock(); items.append(value); lock.unlock() }
    var values: [Bool] { lock.lock(); defer { lock.unlock() }; return items }
}

// MARK: - Contrast math

@Test func contrastRatioMatchesKnownReferencePairs() {
    let black = SRGBColor(red: 0, green: 0, blue: 0)
    let white = SRGBColor(red: 1, green: 1, blue: 1)
    #expect(abs(ContrastAudit.ratio(black, white) - 21.0) < 0.01)
    #expect(abs(ContrastAudit.ratio(white, white) - 1.0) < 0.01)
}

@Test func hexParsingIsStrict() {
    #expect(SRGBColor(hex: "#FFFFFF") == SRGBColor(red: 1, green: 1, blue: 1))
    #expect(SRGBColor(hex: "#000000") == SRGBColor(red: 0, green: 0, blue: 0))
    #expect(SRGBColor(hex: "FFFFFF") == nil)
    #expect(SRGBColor(hex: "#FFF") == nil)
    #expect(SRGBColor(hex: "#GGGGGG") == nil)
}

@Test func chipBlendAndOutlineFallbackUseTheAuditedMath() {
    let black = SRGBColor(red: 0, green: 0, blue: 0)
    let white = SRGBColor(red: 1, green: 1, blue: 1)
    // The outline is whichever of black/white contrasts more with the backdrop.
    #expect(KeepAwakeIndicatorPalette.outline(for: black) == white)
    #expect(KeepAwakeIndicatorPalette.outline(for: white) == black)
    // Blending a colour over itself leaves it unchanged; a half blend of white
    // over black lands at mid grey.
    #expect(white.blended(over: white, alpha: 0.5) == white)
    let grey = white.blended(over: black, alpha: 0.5)
    #expect(abs(grey.red - 0.5) < 1e-9)
    // An out-of-range alpha is clamped, not extrapolated.
    #expect(white.blended(over: black, alpha: 2) == white)
}
