import Foundation
import CoreGraphics
import Testing
@testable import DivotCore

// MARK: - Fixtures

private let notchedID = DisplayBarID(1)
private let flatID = DisplayBarID(2)

private func notchedScreen(hidden: Bool = true) -> ScreenGeometry {
    // Built-in notched display observed in task 0009: the camera housing
    // excludes the whole top band whether or not the native bar shows.
    ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                   visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                   safeAreaTop: 33,
                   auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                   auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
}

private func flatScreen(menuBarShown: Bool) -> ScreenGeometry {
    let height: CGFloat = menuBarShown ? 976 : 1000
    return ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                          visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: height),
                          safeAreaTop: 0)
}

/// Notched display whose top band is shared with a third-party bar (a-bar on
/// AeroSpace). `safeAreaInsets.top` reads zero while the housing's auxiliary
/// regions remain, so the band must not be read as a visible native menu bar.
private func aBarNotchedScreen() -> ScreenGeometry {
    ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                   visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1041),
                   safeAreaTop: 0,
                   auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                   auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
}

// MARK: - Content gap policy

@Test func belowBarPolicyDropsNotchGapAndHonorsEdgeMargin() {
    let policy = BarContentPolicy(height: 32, clearance: 10, edgeMargin: 8)
    let screen = notchedScreen()
    let placement = BarPlacementResolver.placement(screen: screen,
                                                   visibility: .visible(inset: 33),
                                                   policy: policy)
    let g = try! #require(placement?.geometry)
    // Inset below the native bar, not off the top of the screen.
    #expect(g.left.maxY == 1074)
    // Deliberately no 185pt housing hole in this row: a 20pt center seam.
    #expect(g.right.minX - g.left.maxX == 20)
    #expect(g.left.minX == 8)
    #expect(g.right.maxX == 1702)
}

@Test func topEdgePolicyStillSplitsAroundTheNotch() {
    let screen = notchedScreen()
    let placement = BarPlacementResolver.placement(screen: screen, visibility: .hidden)
    #expect(placement?.mode == .topEdge)
    let g = try! #require(placement?.geometry)
    // Bar now hugs the notch with zero gap (#0028)
    #expect(g.left.maxX == 763)
    #expect(g.right.minX == 948)
    #expect(g.left.maxY == 1107)
}

@Test func topEdgePolicyIgnoresClearanceSoTheNotchGapStaysZero() {
    // The removed notch padding cannot be reintroduced through the policy's
    // clearance: the notched top-edge split always hugs the housing (#0028).
    let policy = BarContentPolicy(height: 32, clearance: 12, edgeMargin: 0)
    let placement = BarPlacementResolver.placement(screen: notchedScreen(),
                                                   visibility: .hidden,
                                                   policy: policy)
    let g = try! #require(placement?.geometry)
    #expect(g.left.maxX == 763)
    #expect(g.right.minX == 948)
    #expect(g.hasNotch)
}

@Test func indeterminateVisibilityHasNoResolvedGeometry() {
    let placement = BarPlacementResolver.placement(screen: notchedScreen(),
                                                   visibility: .indeterminate(.notchedHousingMasksMenuBar))
    #expect(placement == nil)
}

@Test func segmentsNeverOverlapAndStayOnScreen() {
    for visibility: NativeMenuBarVisibility in [.hidden, .visible(inset: 33)] {
        let screen = notchedScreen()
        let g = try! #require(BarPlacementResolver.placement(screen: screen, visibility: visibility)?.geometry)
        #expect(g.left.maxX <= g.right.minX)
        #expect(g.left.minX >= screen.frame.minX)
        #expect(g.right.maxX <= screen.frame.maxX)
        #expect(g.left.minY >= screen.frame.minY)
        #expect(g.right.minY >= screen.frame.minY)
        if case .visible(let inset) = visibility {
            // No vertical overlap with the native bar band.
            #expect(g.left.maxY <= screen.frame.maxY - inset)
        }
    }
}

// MARK: - Multi-display coordination

@Test func multipleDisplaysResolveIndependently() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    let updates = coordinator.update(readings: [
        DisplayReading(id: notchedID, geometry: notchedScreen()),
        DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))
    ], at: 0)

    #expect(coordinator.displayIDs == [notchedID, flatID])
    let notched = try! #require(updates.first { $0.id == notchedID })
    #expect(notched.visibility == .indeterminate(.notchedHousingMasksMenuBar))
    // Never hidden: an unresolved notched display still gets a top-edge placement.
    #expect(notched.placement?.mode == .topEdge)

    let flat = try! #require(updates.first { $0.id == flatID })
    #expect(flat.visibility == .visible(inset: 24))
    #expect(flat.placement?.mode == .belowNativeBar(inset: 24))
}

@Test func newUndecidableDisplayRestsAtTopEdgeWithNoAnimation() {
    var coordinator = DisplayBarCoordinator()
    let updates = coordinator.update(readings: [
        DisplayReading(id: notchedID, geometry: notchedScreen())
    ], at: 0)
    let update = try! #require(updates.first)
    #expect(update.animated == false)
    #expect(update.cancelAnimations == true)
    #expect(update.placement?.mode == .topEdge)
    #expect(update.ambiguity == .notchedHousingMasksMenuBar)
}

@Test func grantedAccessibilityOnANotchedDisplayStillYieldsAPlacement() {
    // Regression for #0020. When the probe cannot provide a decisive visibility
    // (not trusted, missing attributes, or otherwise unavailable), the decisive
    // `accessibilityVisible` is nil and a notched display stays indeterminate.
    // That indeterminate visibility is the input that makes the raw resolver
    // return nil; the coordinator must still place the bar at the top edge so
    // the panels get a frame. A silent hold here is the bug.
    let signal = NativeMenuBarSignal(accessibilityVisible: nil)
    let visibility = NativeMenuBarDetector.detect(geometry: notchedScreen(), signal: signal)
    #expect(visibility == .indeterminate(.notchedHousingMasksMenuBar))
    #expect(BarPlacementResolver.placement(screen: notchedScreen(), visibility: visibility) == nil)

    var coordinator = DisplayBarCoordinator()
    let update = try! #require(coordinator.update(readings: [
        DisplayReading(id: notchedID, geometry: notchedScreen(), signal: signal)
    ], at: 0).first)
    #expect(update.placement != nil)
    #expect(update.placement?.mode == .topEdge)
    #expect(update.ambiguity == .notchedHousingMasksMenuBar)
    #expect(update.animated == false)
}

@Test func rapidTogglesConvergePerDisplayWithoutDraggingOthers() {
    var coordinator = DisplayBarCoordinator()  // default settle delay
    _ = coordinator.update(readings: [
        DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))
    ], at: 0)

    // The flat display is in the top-edge state; oscillate it rapidly.
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0.01)
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0.03)
    let pending = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0.05)
    #expect(pending.contains { $0.cancelAnimations })
    #expect(coordinator.isSettling(flatID))

    // Nothing commits before the deadline.
    #expect(coordinator.advance(at: 0.10).isEmpty)
    let settled = coordinator.advance(at: 0.30)
    let update = try! #require(settled.first { $0.id == flatID })
    #expect(update.placement?.mode == .belowNativeBar(inset: 24))
    #expect(update.animated == true)
    #expect(!coordinator.isSettling(flatID))
}

@Test func reducedMotionRepositionsImmediatelyPerDisplay() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0)
    let updates = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)
    let update = try! #require(updates.first)
    #expect(update.animated == false)
    #expect(update.placement?.mode == .belowNativeBar(inset: 24))
    #expect(!coordinator.isSettling(flatID))
}

@Test func hiddenBarAlwaysReturnsToTheTopEdge() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)
    let updates = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0)
    let update = try! #require(updates.first)
    #expect(update.placement?.mode == .topEdge)
    // There is no hide action: the only resting positions are top and below-bar.
    #expect(update.visibility == .hidden)
}

@Test func revealWithGeometryChangeAppliesImmediately() {
    var coordinator = DisplayBarCoordinator()  // default settle delay
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0)

    // A notch-free reveal changes both `visibleFrame` and the detected
    // visibility in one reading. The new placement must be applied now, not the
    // stale committed top-edge state, or the panels overlap the bar until settle.
    let revealed = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0.01)
    let update = try! #require(revealed.first { $0.id == flatID })
    #expect(update.animated == false)
    #expect(update.cancelAnimations == true)
    #expect(update.visibility == .visible(inset: 24))
    #expect(update.placement?.mode == .belowNativeBar(inset: 24))
}

@Test func hideWithGeometryChangeReturnsToTopEdgeImmediately() {
    var coordinator = DisplayBarCoordinator()  // default settle delay
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)

    // The matching hide also changes `visibleFrame`; it must return to the top
    // edge now rather than staying below a bar that has gone away.
    let hidden = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0.01)
    let update = try! #require(hidden.first { $0.id == flatID })
    #expect(update.animated == false)
    #expect(update.visibility == .hidden)
    #expect(update.placement?.mode == .topEdge)
}

@Test func settledFollowUpDoesNotRegressTheImmediateReveal() {
    var coordinator = DisplayBarCoordinator()  // default settle delay
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0)

    // The reveal applies immediately and still queues a settle observation.
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0.01)
    #expect(coordinator.isSettling(flatID))

    // When that observation commits it must re-apply the same below-bar
    // placement, never fall back to the stale top edge. This is the
    // regression guard for the geometry+visibility fix above: the follow-up
    // `advance` may reposition, but it must not undo the immediate reveal.
    let settled = coordinator.advance(at: 0.30)
    if let update = settled.first(where: { $0.id == flatID }) {
        #expect(update.placement?.mode == .belowNativeBar(inset: 24))
    }
    #expect(!coordinator.isSettling(flatID))
}

@Test func displayGeometryChangeRepositionsImmediately() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)

    // Same visibility, different resolution: recompute without animation.
    let resized = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                                 visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1416),
                                 safeAreaTop: 0)
    let updates = coordinator.update(readings: [DisplayReading(id: flatID, geometry: resized)], at: 0)
    let update = try! #require(updates.first)
    #expect(update.animated == false)
    #expect(update.cancelAnimations == true)
    let g = try! #require(update.placement?.geometry)
    #expect(g.right.maxX == 2560)
    #expect(g.left.maxY == 1416)
}

@Test func hotUnplugDropsTheDisplay() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    _ = coordinator.update(readings: [
        DisplayReading(id: notchedID, geometry: notchedScreen()),
        DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))
    ], at: 0)
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)
    #expect(coordinator.displayIDs == [flatID])
    #expect(coordinator.reading(for: notchedID) == nil)
}

@Test func accessibilitySignalOverridesNotchedAmbiguity() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    let signal = NativeMenuBarSignal(accessibilityVisible: true)
    let updates = coordinator.update(readings: [
        DisplayReading(id: notchedID, geometry: notchedScreen(), signal: signal)
    ], at: 0)
    let update = try! #require(updates.first)
    #expect(update.visibility == .visible(inset: 33))
    #expect(update.placement?.mode == .belowNativeBar(inset: 33))
}

@Test func notchedPlacementFollowsRevealAndHideInBothDirections() {
    // #0021: on the notched display a decisive AX signal must move Divot below
    // a revealed native bar and back to the top edge when it hides — in both
    // directions. The geometry is masked either way, so the signal is the only
    // input that changes.
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    func reading(_ visible: Bool) -> DisplayReading {
        DisplayReading(id: notchedID, geometry: notchedScreen(),
                       signal: NativeMenuBarSignal(accessibilityVisible: visible))
    }

    let shown = try! #require(coordinator.update(readings: [reading(true)], at: 0).first)
    #expect(shown.visibility == .visible(inset: 33))
    #expect(shown.placement?.mode == .belowNativeBar(inset: 33))

    let hidden = try! #require(coordinator.update(readings: [reading(false)], at: 0).first)
    #expect(hidden.visibility == .hidden)
    #expect(hidden.placement?.mode == .topEdge)
    #expect(hidden.animated == false)

    let revealedAgain = try! #require(coordinator.update(readings: [reading(true)], at: 0).first)
    #expect(revealedAgain.visibility == .visible(inset: 33))
    #expect(revealedAgain.placement?.mode == .belowNativeBar(inset: 33))
}

@Test func thirdPartyTopBandKeepsDivotAtTheTopEdge() {
    // Regression (task 0015): the a-bar-occupied top band on a notched display
    // must not resolve to `belowNativeBar`. Detection stays indeterminate and
    // Divot rests at the top edge instead of stacking as a second row.
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    let updates = coordinator.update(readings: [
        DisplayReading(id: notchedID, geometry: aBarNotchedScreen())
    ], at: 0)
    let update = try! #require(updates.first)
    #expect(update.visibility == .indeterminate(.notchedHousingMasksMenuBar))
    #expect(update.ambiguity == .notchedHousingMasksMenuBar)
    #expect(update.placement?.mode == .topEdge)
    #expect(update.animated == false)
}

@Test func genuinelyRevealedNativeBarStillResolvesBelow() {
    // 0009 behavior preserved: a notch-free display with no camera housing and a
    // non-zero top band is a revealed native bar, so Divot still moves below it.
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    let updates = coordinator.update(readings: [
        DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))
    ], at: 0)
    let update = try! #require(updates.first)
    #expect(update.visibility == .visible(inset: 24))
    #expect(update.placement?.mode == .belowNativeBar(inset: 24))
}

@Test func repeatedIdenticalReadingIsQuiet() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)
    let updates = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 1)
    #expect(updates.isEmpty)
}

@Test func enablingReducedMotionUpdatesExistingControllers() {
    var coordinator = DisplayBarCoordinator()  // default settle delay
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0)
    // A normal change would settle rather than commit immediately.
    _ = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0.01)
    #expect(coordinator.isSettling(flatID))

    // Turning on Reduced Motion mid-run must reach the existing controller, so
    // the next visibility change repositions immediately.
    coordinator.setReducedMotion(true)
    let updates = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false))], at: 0.02)
    let update = try! #require(updates.first { $0.id == flatID })
    #expect(update.animated == false)
    #expect(update.placement?.mode == .topEdge)
    #expect(!coordinator.isSettling(flatID))
}

@Test func resetReemitsPlacementForEveryDisplay() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    let first = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 0)
    #expect(!first.isEmpty)
    // Retained state makes an identical reading a no-op.
    #expect(coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 1).isEmpty)

    // After a teardown the same reading must re-emit a placement, otherwise
    // recreated panels would stay at their initial frame.
    coordinator.reset()
    #expect(coordinator.displayIDs.isEmpty)
    let restarted = coordinator.update(readings: [DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: true))], at: 2)
    let update = try! #require(restarted.first)
    #expect(update.placement?.mode == .belowNativeBar(inset: 24))
    #expect(update.cancelAnimations == true)
    #expect(update.animated == false)
}

// MARK: - Cursor reveal (#0023)

/// The masked display's visibility comes from the pointer observation only, so
/// the geometry is identical across the transition and the signal is the only
/// input that changes.
private func cursorReading(_ engaged: Bool) -> DisplayReading {
    DisplayReading(id: notchedID, geometry: notchedScreen(),
                   signal: NativeMenuBarSignal(cursorRevealsMenuBar: engaged))
}

@Test func cursorRevealEntersDwellsAndLeavesOnAMaskedDisplay() {
    var coordinator = DisplayBarCoordinator()  // default settle delay (dwell)

    // The pointer is away: Divot rests at the top edge.
    let resting = try! #require(coordinator.update(readings: [cursorReading(false)], at: 0).first)
    #expect(resting.visibility == .hidden)
    #expect(resting.placement?.mode == .topEdge)

    // Enter: a pending observation cancels any in-flight transition.
    let entering = coordinator.update(readings: [cursorReading(true)], at: 0.10)
    #expect(entering.contains { $0.cancelAnimations })
    #expect(coordinator.isSettling(notchedID))

    // Dwell: nothing commits before the settle deadline.
    #expect(coordinator.advance(at: 0.20).isEmpty)
    let revealed = try! #require(coordinator.advance(at: 0.30).first)
    #expect(revealed.visibility == .visible(inset: 33))
    #expect(revealed.placement?.mode == .belowNativeBar(inset: 33))
    #expect(revealed.animated == true)

    // Leave: back to the top edge once the dwell passes.
    _ = coordinator.update(readings: [cursorReading(false)], at: 0.40)
    #expect(coordinator.advance(at: 0.50).isEmpty)
    let hidden = try! #require(coordinator.advance(at: 0.60).first)
    #expect(hidden.visibility == .hidden)
    #expect(hidden.placement?.mode == .topEdge)
}

@Test func cursorRevealRespectsReducedMotion() {
    var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(reducedMotion: true))
    _ = coordinator.update(readings: [cursorReading(false)], at: 0)
    // With Reduced Motion on, the reveal commits immediately and without
    // animation, like every other visibility change.
    let updates = coordinator.update(readings: [cursorReading(true)], at: 0)
    let update = try! #require(updates.first)
    #expect(update.animated == false)
    #expect(update.placement?.mode == .belowNativeBar(inset: 33))
    #expect(!coordinator.isSettling(notchedID))
}

@Test func cursorRevealIsCrossCheckedByANotchFreeVisibleFrame() {
    // Disagreement case: the pointer is in the top strip, but the notch-free
    // display's own `visibleFrame` says the native bar is not there. The geometry
    // corrects the reading, so Divot stays at the top edge rather than sliding
    // below a bar that is not shown.
    var coordinator = DisplayBarCoordinator()
    let reading = DisplayReading(id: flatID, geometry: flatScreen(menuBarShown: false),
                                 signal: NativeMenuBarSignal(cursorRevealsMenuBar: true))
    let update = try! #require(coordinator.update(readings: [reading], at: 0).first)
    #expect(update.visibility == .hidden)
    #expect(update.placement?.mode == .topEdge)
}
