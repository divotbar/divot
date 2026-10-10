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

/// A notched display whose top band is shared with a third-party bar (a-bar):
/// the public inset reads zero while the housing's auxiliary regions remain.
private func aBarReading() -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(1),
                          geometry: ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                                                   visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1041),
                                                   safeAreaTop: 0,
                                                   auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                                                   auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33)))
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
@Test func accessibilitySampleDrivesPlacementOnlyWhenOptedIn() {
    // The on-screen heuristic is hardware-sensitive, so the adapter withholds it
    // unless the configuration opts in (`menuBar.trustAccessibilityProbe`).
    for derivedVisible in [true, false] {
        let probe = MockMenuBarProbe(state: .provisional(visible: derivedVisible,
                                                         description: "on-screen test"))
        let withheld = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [notchedReading()]),
                                                 probe: probe)
        #expect(withheld.observe().readings.first?.signal.accessibilityVisible == nil)

        let trusted = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [notchedReading()]),
                                                probe: probe,
                                                trustsAccessibilityProbe: true)
        #expect(trusted.observe().readings.first?.signal.accessibilityVisible == derivedVisible)
    }
}

@MainActor
@Test func anUntrustedProbeStaysWithheldEvenWhenOptedIn() {
    let adapter = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [notchedReading()]),
                                            probe: MockMenuBarProbe(state: .notTrusted),
                                            trustsAccessibilityProbe: true)
    #expect(adapter.observe().readings.first?.signal.accessibilityVisible == nil)
}

@MainActor
@Test func optedInProbeResolvesRevealedAndHiddenOnANotchedDisplay() {
    func detection(derivedVisible: Bool) -> NativeMenuBarVisibility {
        let adapter = MenuBarObservationAdapter(
            provider: MockScreenProvider(readings: [notchedReading()]),
            probe: MockMenuBarProbe(state: .provisional(visible: derivedVisible, description: "test")),
            trustsAccessibilityProbe: true)
        let observation = adapter.observe()
        return NativeMenuBarDetector.detect(geometry: observation.readings[0].geometry,
                                            signal: observation.readings[0].signal)
    }
    #expect(detection(derivedVisible: true) == .visible(inset: 33))
    #expect(detection(derivedVisible: false) == .hidden)
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
@Test func optedInMultiDisplayStillWithholdsTheSystemWideSample() {
    // Known limitation (#0021 review): the AX menu bar is one system-wide
    // object that public APIs do not attribute to a display. Even with the
    // documented opt-in, the sample is only used when there is a single
    // display, so a notched built-in plus an external monitor stays
    // indeterminate and holds the top edge rather than risking a sample
    // misattributed to the other panel. Attributing across displays is an open
    // physical-validation item (docs/evidence/0003-app-shell.md).
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading(), flatReading(id: 2, menuBarShown: false)]),
        probe: MockMenuBarProbe(state: .provisional(visible: true, description: "test")),
        trustsAccessibilityProbe: true)
    let observation = adapter.observe()

    #expect(observation.readings.allSatisfy { $0.signal.accessibilityVisible == nil })
    let notched = observation.readings.first { $0.id == DisplayBarID(1) }!
    #expect(NativeMenuBarDetector.detect(geometry: notched.geometry, signal: notched.signal)
        == .indeterminate(.notchedHousingMasksMenuBar))
    // The notch-free display keeps deciding from its own geometry.
    let flat = observation.readings.first { $0.id == DisplayBarID(2) }!
    #expect(NativeMenuBarDetector.detect(geometry: flat.geometry, signal: flat.signal) == .hidden)
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

@MainActor
@Test func thirdPartyTopBandStaysIndeterminateThroughTheAdapter() {
    // Regression (task 0015): with no decisive probe, the a-bar-occupied top
    // band on a notched display must not become a `.visible(inset:)`. The
    // housing is detected from the auxiliary regions even though the public
    // inset reads zero, so the adapter leaves it indeterminate and Divot holds
    // the top edge instead of stacking under a-bar.
    let adapter = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [aBarReading()]),
                                            probe: MockMenuBarProbe(state: .notTrusted))
    let observation = adapter.observe()
    #expect(observation.readings.first?.signal.accessibilityVisible == nil)
    let detected = NativeMenuBarDetector.detect(
        geometry: observation.readings[0].geometry,
        signal: observation.readings[0].signal)
    #expect(detected == .indeterminate(.notchedHousingMasksMenuBar))
}

@MainActor
@Test func cursorEngagedDisplaysAreAttributedPerDisplay() {
    // The pointer is in one display's top strip; only that display's reading is
    // engaged, and a notch-free display still decides from its own visibleFrame.
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading(), flatReading(id: 2, menuBarShown: false)]),
        probe: MockMenuBarProbe(state: .notTrusted),
        cursorEngagedDisplays: [DisplayBarID(1)])
    let observation = adapter.observe()
    let notched = observation.readings.first { $0.id == DisplayBarID(1) }!
    let flat = observation.readings.first { $0.id == DisplayBarID(2) }!

    #expect(notched.signal.cursorRevealsMenuBar == true)
    #expect(flat.signal.cursorRevealsMenuBar == false)
    #expect(NativeMenuBarDetector.detect(geometry: notched.geometry, signal: notched.signal)
        == .visible(inset: 33))
    #expect(NativeMenuBarDetector.detect(geometry: flat.geometry, signal: flat.signal) == .hidden)
}

@MainActor
@Test func cursorSignalIsWithheldWhenTheSettingIsOff() {
    // `nil` means the "move below on cursor reveal" setting is off, so the
    // masked display stays indeterminate rather than being told hidden.
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading()]),
        probe: MockMenuBarProbe(state: .notTrusted),
        cursorEngagedDisplays: nil)
    let observation = adapter.observe()
    #expect(observation.readings.first?.signal.cursorRevealsMenuBar == nil)
    #expect(NativeMenuBarDetector.detect(geometry: observation.readings[0].geometry,
                                         signal: observation.readings[0].signal)
        == .indeterminate(.notchedHousingMasksMenuBar))
}

@MainActor
@Test func alwaysBelowFallbackReachesTheDetectorThroughTheAdapter() {
    let adapter = MenuBarObservationAdapter(provider: MockScreenProvider(readings: [flatReading(id: 1, menuBarShown: false)]),
                                            probe: MockMenuBarProbe(state: .notTrusted),
                                            alwaysBelowMenuBar: true)
    let observation = adapter.observe()
    #expect(NativeMenuBarDetector.detect(geometry: observation.readings[0].geometry,
                                         signal: observation.readings[0].signal)
        == .visible(inset: 24))
}
