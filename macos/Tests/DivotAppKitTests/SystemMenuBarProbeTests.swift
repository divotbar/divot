import CoreGraphics
import Testing
import DivotCore
@testable import DivotAppKit

// MARK: - Missing / invalid AX attributes

@Test func completeSampleIsProvisionalUntilValidated() {
    let description = "position=(0.0, 0.0) size=(1710.0, 33.0) hidden=false onScreen=true"
    let shown = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                         size: CGSize(width: 1710, height: 33),
                                         hidden: false)
    #expect(shown == .provisional(visible: true, description: description))
    // A complete but unvalidated sample must never be decisive: it would move
    // panels on a false visibility claim.
    #expect(shown.accessibilityVisible == nil)
    #expect(shown.rawDerivedVisible == true)
    #expect(shown.isProvisional)
    #expect(shown.permissionGranted)

    // Only an explicitly validated sample is a decisive visibility.
    let validated = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                             size: CGSize(width: 1710, height: 33),
                                             hidden: false,
                                             validated: true)
    #expect(validated == .sampled(visible: true, description: description))
    #expect(validated.accessibilityVisible == true)
    #expect(!validated.isProvisional)
}

@Test func provisionalHiddenSampleStaysIndeterminate() {
    let hidden = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                          size: CGSize(width: 1710, height: 33),
                                          hidden: true)
    #expect(hidden.accessibilityVisible == nil)
    #expect(hidden.rawDerivedVisible == false)

    let validated = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                             size: CGSize(width: 1710, height: 33),
                                             hidden: true,
                                             validated: true)
    #expect(validated.accessibilityVisible == false)
}

@Test func missingAttributesStayIndeterminate() {
    let size = CGSize(width: 1710, height: 33)
    let position = CGPoint(x: 0, y: 0)

    #expect(SystemMenuBarProbe.state(position: nil, size: size, hidden: false).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: position, size: nil, hidden: false).accessibilityVisible == nil)
    // A missing `hidden` must not default to `false` (which would claim visible).
    #expect(SystemMenuBarProbe.state(position: position, size: size, hidden: nil).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: nil, size: size, hidden: true).accessibilityVisible == nil)
}

@Test func emptyAreaIsIndeterminateNotHidden() {
    let position = CGPoint(x: 0, y: 0)
    #expect(SystemMenuBarProbe.state(position: position, size: .zero, hidden: false).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: position,
                                     size: CGSize(width: 0, height: 33),
                                     hidden: false).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: position,
                                     size: CGSize(width: 1710, height: 0),
                                     hidden: true).accessibilityVisible == nil)
}

@Test func unavailableStateReportsPermissionSeparately() {
    let state = SystemMenuBarProbe.state(position: nil, size: nil, hidden: nil)
    if case .unavailable = state {} else { Issue.record("expected unavailable, got \(state)") }
    // Trusted, just unusable: that is not the same as missing permission.
    #expect(state.permissionGranted)
}

// MARK: - Auto-hidden vs revealed: the reported signal

/// The signal that used to report "visible" while the native bar was
/// auto-hidden is `kAXHiddenAttribute`: it stays `false` because an auto-hidden
/// bar is slid off the top, not AX-hidden. The bar's own frame distinguishes the
/// two — revealed sits at `y == 0`, auto-hidden sits above the screen at a
/// negative `y` — which is the signal `SystemMenuBarProbe` now uses (#0021).
@Test func autoHiddenBarIsNotReportedVisible() {
    let revealed = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                            size: CGSize(width: 1710, height: 33),
                                            hidden: false,
                                            validated: true)
    let autoHidden = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: -33),
                                              size: CGSize(width: 1710, height: 33),
                                              hidden: false,
                                              validated: true)

    #expect(revealed.accessibilityVisible == true)
    #expect(autoHidden.accessibilityVisible == false)
    // Both samples carry `hidden=false`; only the frame tells them apart.
    #expect(revealed.sampleDescription.contains("hidden=false"))
    #expect(autoHidden.sampleDescription.contains("hidden=false"))
    #expect(revealed.sampleDescription.contains("onScreen=true"))
    #expect(autoHidden.sampleDescription.contains("onScreen=false"))
}

/// Acceptance for #0021: on a notched screen a decisive probe sample resolves a
/// hidden bar to `.hidden` (Divot rests at the top edge) and a revealed bar to
/// `.visible(inset:)` (Divot moves below it).
@Test func notchedRevealAndHideResolveFromTheProbeSample() {
    let notched = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                                 visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                                 safeAreaTop: 33,
                                 auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                                 auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
    let revealed = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                            size: CGSize(width: 1710, height: 33),
                                            hidden: false, validated: true)
    let autoHidden = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: -33),
                                              size: CGSize(width: 1710, height: 33),
                                              hidden: false, validated: true)

    let revealedSignal = NativeMenuBarSignal(accessibilityVisible: revealed.accessibilityVisible)
    let hiddenSignal = NativeMenuBarSignal(accessibilityVisible: autoHidden.accessibilityVisible)
    #expect(NativeMenuBarDetector.detect(geometry: notched, signal: revealedSignal)
        == .visible(inset: 33))
    #expect(NativeMenuBarDetector.detect(geometry: notched, signal: hiddenSignal) == .hidden)
}
