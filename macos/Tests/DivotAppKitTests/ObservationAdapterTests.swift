import CoreGraphics
import Testing
import DivotCore
@testable import DivotAppKit

/// A provider that returns fixed readings, so adapter behavior is testable
/// without a window server.
@MainActor
private struct MockScreenProvider: ScreenGeometryProviding {
    let readings: [ScreenGeometryReading]
    func screens() -> [ScreenGeometryReading] { readings }
}

private struct MockMenuBarProbe: SystemMenuBarProbing {
    let state: SystemMenuBarState
    func sample() -> SystemMenuBarState { state }
}

/// Counts samples so a test can prove the adapter never caches a probe result.
private final class ProbeCallCounter: @unchecked Sendable {
    var calls = 0
}

private struct CountingMenuBarProbe: SystemMenuBarProbing {
    let counter: ProbeCallCounter
    func sample() -> SystemMenuBarState {
        counter.calls += 1
        return .unavailable("counting")
    }
}

private func notchedReading() -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(1),
                          geometry: ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                                                   visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                                                   safeAreaTop: 33))
}

private func flatReading(id: UInt32, menuBarShown: Bool) -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(id),
                          geometry: ScreenGeometry(frame: CGRect(x: 1710, y: 0, width: 1600, height: 1000),
                                                   visibleFrame: CGRect(x: 1710, y: 0, width: 1600,
                                                                        height: menuBarShown ? 976 : 1000),
                                                   safeAreaTop: 0))
}

@MainActor
@Test func untrustedProbeNeverBecomesAVisibilityClaim() {
    let adapter = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [notchedReading()]),
                                            probe: MockMenuBarProbe(state: .notTrusted))
    let observation = adapter.observe()

    // The detector must not be handed a guessed visibility for a notched display.
    #expect(observation.readings.first?.signal.accessibilityVisible == nil)
    #expect(!observation.accessibilityPermissionGranted)
    let detected = NativeMenuBarDetector.detect(
        geometry: observation.readings[0].geometry,
        signal: observation.readings[0].signal)
    #expect(detected == .indeterminate(.notchedHousingMasksMenuBar))
}

@MainActor
@Test func singleMaskedDisplayUsesAValidatedAccessibilitySample() {
    for visible in [true, false] {
        let adapter = MenuBarObservationAdapter(
            provider: MockScreenProvider(readings: [notchedReading()]),
            probe: MockMenuBarProbe(state: .sampled(visible: visible, description: "validated test")))
        let observation = adapter.observe()
        #expect(observation.readings.first?.signal.accessibilityVisible == visible)
        #expect(observation.accessibilityPermissionGranted)
    }
}

@MainActor
@Test func everyObservationTakesAFreshProbeSample() {
    // A pointer-only reveal has no proven event trigger (see the 0009 evidence),
    // but whatever does trigger a refresh must re-read the AX menu bar rather
    // than reuse a cached sample, or a reveal could never be picked up.
    let counter = ProbeCallCounter()
    let probe = CountingMenuBarProbe(counter: counter)
    let adapter = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [notchedReading()]),
                                            probe: probe)
    _ = adapter.observe()
    _ = adapter.observe()
    #expect(counter.calls == 2)
}

@MainActor
@Test func provisionalAccessibilitySampleNeverDrivesPlacement() {
    // The real AX probe returns a provisional sample by default. Even with the
    // permission granted, an unvalidated heuristic must not move a panel.
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading()]),
        probe: MockMenuBarProbe(state: .provisional(visible: true, description: "unvalidated test")))
    let observation = adapter.observe()

    #expect(observation.readings.first?.signal.accessibilityVisible == nil)
    #expect(observation.accessibility.permissionGranted)
    #expect(observation.accessibility.isProvisional)
    let detected = NativeMenuBarDetector.detect(
        geometry: observation.readings[0].geometry,
        signal: observation.readings[0].signal)
    #expect(detected == .indeterminate(.notchedHousingMasksMenuBar))
}

@MainActor
@Test func accessibilityIsNotSharedAcrossDisplays() {
    // One notched (masked) + one notch-free display. The single system-wide
    // sample cannot be attributed to a display, so it must not be handed to
    // either one.
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading(), flatReading(id: 2, menuBarShown: false)]),
        probe: MockMenuBarProbe(state: .sampled(visible: true, description: "test")))
    let observation = adapter.observe()

    #expect(observation.readings.count == 2)
    #expect(observation.readings.allSatisfy { $0.signal.accessibilityVisible == nil })

    // The notch-free display still decides from its own geometry.
    let flat = observation.readings.first { $0.id == DisplayBarID(2) }!
    #expect(NativeMenuBarDetector.detect(geometry: flat.geometry, signal: flat.signal) == .hidden)
    // The masked display stays indeterminate rather than being misattributed.
    let notched = observation.readings.first { $0.id == DisplayBarID(1) }!
    #expect(NativeMenuBarDetector.detect(geometry: notched.geometry, signal: notched.signal)
        == .indeterminate(.notchedHousingMasksMenuBar))
}

@MainActor
@Test func multipleMaskedDisplaysStayIndeterminate() {
    let second = ScreenGeometryReading(id: DisplayBarID(2),
                                       geometry: ScreenGeometry(frame: CGRect(x: 1710, y: 0, width: 1710, height: 1107),
                                                                visibleFrame: CGRect(x: 1770, y: 0, width: 1650, height: 1074),
                                                                safeAreaTop: 33))
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading(), second]),
        probe: MockMenuBarProbe(state: .sampled(visible: true, description: "test")))
    let observation = adapter.observe()
    #expect(observation.readings.allSatisfy { $0.signal.accessibilityVisible == nil })
    #expect(observation.readings.allSatisfy {
        NativeMenuBarDetector.detect(geometry: $0.geometry, signal: $0.signal).isIndeterminate
    })
}

@MainActor
@Test func unavailableProbeIsTreatedLikeNoSignal() {
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading()]),
        probe: MockMenuBarProbe(state: .unavailable("no element")))
    let observation = adapter.observe()
    #expect(observation.readings.first?.signal.accessibilityVisible == nil)
    // Trusted but unusable: still not a claim of visibility.
    #expect(observation.accessibilityPermissionGranted)
}
