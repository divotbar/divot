import Foundation
import CoreGraphics
import Testing
@testable import DivotCore

// MARK: - Geometry derivation

@Test func notchFreeVisibleFrameRevealsMenuBar() {
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 976),
                           safeAreaTop: 0)
    #expect(!g.isNotched)
    #expect(g.housingTop == 0)
    #expect(g.menuBarInset == 24)
    #expect(NativeMenuBarDetector.detect(geometry: g) == .visible(inset: 24))
}

@Test func notchFreeHiddenMenuBarUsesTopEdge() {
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                           safeAreaTop: 0)
    #expect(g.menuBarInset == 0)
    #expect(NativeMenuBarDetector.detect(geometry: g) == .hidden)
}

@Test func notchFreeDockOnLeftDoesNotLookLikeAMenuBar() {
    // Dock on the left only shrinks visibleFrame.width; the top band stays 0.
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                           visibleFrame: CGRect(x: 64, y: 0, width: 1536, height: 1000),
                           safeAreaTop: 0)
    #expect(g.menuBarInset == 0)
    #expect(NativeMenuBarDetector.detect(geometry: g) == .hidden)
}

@Test func notchedDisplayMasksTheMenuBarBand() {
    // Matches the observed macOS 26.5.2 built-in display: topBand == housingTop,
    // so a hidden and a revealed bar are indistinguishable from geometry alone.
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                           visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                           safeAreaTop: 33,
                           auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                           auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
    #expect(g.isNotched)
    #expect(g.housingTop == 33)
    #expect(g.topBand == 33)
    #expect(g.menuBarInset == 0)
    #expect(NativeMenuBarDetector.detect(geometry: g) == .indeterminate(.notchedHousingMasksMenuBar))
}

@Test func thirdPartyBarSharedHousingBandIsNotAVisibleNativeBar() {
    // a-bar (AeroSpace) occupies the top band on a notched display. The public
    // inset can read zero while the housing's auxiliary regions remain, so the
    // larger top band is NOT a revealed native menu bar. Before the housing
    // fallback this read as `.visible(inset: 66)` and stacked Divot below a-bar.
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1041),
                           safeAreaTop: 0,
                           auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                           auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
    #expect(g.isNotched)
    #expect(g.housingTop == 33)
    #expect(g.topBand == 66)
    #expect(g.menuBarInset == 33)
    #expect(NativeMenuBarDetector.detect(geometry: g)
        == .indeterminate(.notchedHousingMasksMenuBar))
}

@Test func notchedConfiguredAlwaysVisibleClearsWholeBand() {
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
                           safeAreaTop: 33)
    let signal = NativeMenuBarSignal(configuredAlwaysVisible: true)
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: signal) == .visible(inset: 33))
}

@Test func accessibilitySignalOverridesAmbiguousGeometry() {
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
                           safeAreaTop: 33)
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: .init(accessibilityVisible: true))
        == .visible(inset: 33))
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: .init(accessibilityVisible: false))
        == .hidden)
}

@Test func accessibilityNeverOverridesNotchFreeGeometry() {
    // Notch-free display whose own visibleFrame already decides. A system-wide
    // AX sample must not flip the result either way.
    let shown = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                               visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 976),
                               safeAreaTop: 0)
    let hidden = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                safeAreaTop: 0)
    #expect(NativeMenuBarDetector.detect(geometry: shown, signal: .init(accessibilityVisible: false))
        == .visible(inset: 24))
    #expect(NativeMenuBarDetector.detect(geometry: hidden, signal: .init(accessibilityVisible: true))
        == .hidden)
}

@Test func configuredAlwaysVisibleWinsOnNotchedGeometry() {
    let g = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
                           safeAreaTop: 33)
    // Explicit configuration is authoritative even if a probe says hidden.
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: .init(accessibilityVisible: false,
                                                                     configuredAlwaysVisible: true))
        == .visible(inset: 33))
}

// MARK: - Cursor reveal and the visible-frame cross-check

private func notchedGeometry() -> ScreenGeometry {
    ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                   visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                   safeAreaTop: 33,
                   auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                   auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
}

private func flatGeometry(menuBarInset: CGFloat) -> ScreenGeometry {
    ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                   visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000 - menuBarInset),
                   safeAreaTop: 0)
}

@Test func cursorInTheTopStripRevealsAMaskedDisplay() {
    // The camera housing masks the band, so the pointer observation decides.
    let g = notchedGeometry()
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: .init(cursorRevealsMenuBar: true))
        == .visible(inset: 33))
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: .init(cursorRevealsMenuBar: false))
        == .hidden)
}

@Test func cursorReadingDoesNotOverrideATrustedAccessibilityProbe() {
    // When the Accessibility opt-in is on it decides; the cursor reading only
    // fills the masked case where geometry alone cannot (#0023).
    let g = notchedGeometry()
    let signal = NativeMenuBarSignal(accessibilityVisible: false, cursorRevealsMenuBar: true)
    #expect(NativeMenuBarDetector.detect(geometry: g, signal: signal) == .hidden)
}

@Test func visibleFrameCrossChecksADisagreeingCursorReading() {
    // Notch-free display: `visibleFrame` decides, so a cursor reading that
    // disagrees is corrected rather than followed, in both directions.
    let hidden = flatGeometry(menuBarInset: 0)
    let shown = flatGeometry(menuBarInset: 24)
    #expect(NativeMenuBarDetector.detect(geometry: hidden, signal: .init(cursorRevealsMenuBar: true))
        == .hidden)
    #expect(NativeMenuBarDetector.detect(geometry: shown, signal: .init(cursorRevealsMenuBar: false))
        == .visible(inset: 24))
}

@Test func alwaysBelowFallbackIsAuthoritative() {
    // Escape hatch for a Mac where the cursor reveal does not line up: sit below
    // by the housing band (notched) or the nominal bar (notch-free).
    #expect(NativeMenuBarDetector.detect(geometry: notchedGeometry(),
                                         signal: .init(alwaysBelowMenuBar: true)) == .visible(inset: 33))
    #expect(NativeMenuBarDetector.detect(geometry: flatGeometry(menuBarInset: 0),
                                         signal: .init(alwaysBelowMenuBar: true)) == .visible(inset: 24))
}

// MARK: - Coalescing controller

@Test func hiddenBarReturnsToTopEdgeInsteadOfHiding() {
    var c = MenuBarInsetController(initial: .visible(inset: 24),
                                   policy: .init(reducedMotion: true))
    #expect(c.observe(.hidden, at: 0) == [.reposition(inset: 0, animated: false)])
    #expect(c.committed == .hidden)
}

@Test func reducedMotionRepositionsImmediately() {
    var c = MenuBarInsetController(initial: .hidden, policy: .init(settleDelay: 0.15, reducedMotion: true))
    #expect(c.observe(.visible(inset: 24), at: 0) == [.reposition(inset: 24, animated: false)])
    #expect(!c.isSettling)
}

@Test func rapidTogglesConvergeToLatestObservation() {
    var c = MenuBarInsetController(initial: .hidden)
    c.observe(.visible(inset: 24), at: 0)
    c.observe(.hidden, at: 0.02)
    c.observe(.visible(inset: 24), at: 0.05)
    c.observe(.hidden, at: 0.09)
    // Nothing commits before the settle deadline.
    #expect(c.advance(to: 0.10) == [])
    let settled = c.advance(to: 0.30)
    #expect(settled == [.reposition(inset: 0, animated: true)])
    #expect(c.committed == .hidden)
}

@Test func supersededTransitionCancelsAnimation() {
    var c = MenuBarInsetController(initial: .hidden)
    let first = c.observe(.visible(inset: 24), at: 0)
    #expect(first == [.cancelAnimations])
    let second = c.observe(.hidden, at: 0.01)
    #expect(second == [.cancelAnimations])
}

@Test func indeterminateHoldsPlacementAndIsSurfaced() {
    var c = MenuBarInsetController(initial: .visible(inset: 24))
    c.observe(.indeterminate(.notchedHousingMasksMenuBar), at: 0)
    let settled = c.advance(to: 1)
    #expect(settled == [.indeterminate(.notchedHousingMasksMenuBar)])
    #expect(c.committed.isIndeterminate)
    // The only reposition values ever produced are explicit insets; there is no
    // hide action for a no-signal state to fall back to.
    #expect(c.committed.inset == nil)
}

@Test func repeatedIdenticalObservationDoesNotRestart() {
    var c = MenuBarInsetController(initial: .visible(inset: 24))
    c.observe(.visible(inset: 24), at: 0)
    #expect(!c.isSettling)
    #expect(c.advance(to: 10) == [])
}
