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

private func notchedReading() -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(1),
                          geometry: ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                                                   visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                                                   safeAreaTop: 33))
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
@Test func sampledProbeFeedsVisibilityAndPermission() {
    for visible in [true, false] {
        let adapter = MenuBarObservationAdapter(
            provider: MockScreenProvider(readings: [notchedReading()]),
            probe: MockMenuBarProbe(state: .sampled(visible: visible, description: "test")))
        let observation = adapter.observe()
        #expect(observation.readings.first?.signal.accessibilityVisible == visible)
        #expect(observation.accessibilityPermissionGranted)
    }
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
@Test func signalIsSharedAcrossEveryDisplay() {
    let second = ScreenGeometryReading(id: DisplayBarID(2),
                                       geometry: ScreenGeometry(frame: CGRect(x: 1710, y: 0, width: 1600, height: 1000),
                                                                visibleFrame: CGRect(x: 1710, y: 0, width: 1600, height: 976),
                                                                safeAreaTop: 0))
    let adapter = MenuBarObservationAdapter(
        provider: MockScreenProvider(readings: [notchedReading(), second]),
        probe: MockMenuBarProbe(state: .sampled(visible: true, description: "test")))
    let observation = adapter.observe()
    #expect(observation.readings.count == 2)
    #expect(observation.readings.allSatisfy { $0.signal.accessibilityVisible == true })
}
