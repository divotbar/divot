import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The bar panels sit *below* the notification-banner layer (#0080), so a
/// banner draws over the bar and its title/body are never tucked under it,
/// while the bar stays above ordinary app content and below the native menu bar
/// so system menus, which are their own higher layers, still open above Divot.
@MainActor
@Test func barPanelsSitBelowNotificationBannersButAboveAppWindows() {
    let level = NSPanelBarSurface.panelLevel.rawValue

    // Above ordinary app windows.
    #expect(level > NSWindow.Level.normal.rawValue)
    // Below the measured notification-banner layer (21 on macOS 26.5); see
    // docs/evidence/0075-notification-banner-overlap.md.
    #expect(level < 21)
    // Below the native menu bar and its pop-up menus.
    #expect(level < NSWindow.Level.mainMenu.rawValue)
    #expect(level < NSWindow.Level.popUpMenu.rawValue)
}

/// The optional bottom shadow (#0025) is drawn by enlarging the panel and
/// placing a gradient strip below the bar, so it never rims the other edges.
@MainActor
@Test func panelContainerPinsTheBarToTheTopAboveTheShadowStrip() {
    let content = BarContentView(side: .right, items: [.clock])
    let container = BarPanelContainer(content: content, shadowHeight: 6)
    container.frame = NSRect(x: 0, y: 0, width: 400, height: 38) // bar 32 + strip 6
    container.layout()

    // y-up: the bar keeps its full height at the top, the shadow is below it.
    #expect(content.frame == NSRect(x: 0, y: 6, width: 400, height: 32))

    let gradient = try! #require(container.layer?.sublayers?.first { $0 is CAGradientLayer } as? CAGradientLayer)
    #expect(gradient.frame == NSRect(x: 0, y: 0, width: 400, height: 6))
    #expect(gradient.colors?.count == 2)
}

@MainActor
@Test func panelContainerReattachesTheShadowGradientAfterLayoutIfItWasRemoved() {
    let content = BarContentView(side: .right, items: [.clock])
    let container = BarPanelContainer(content: content, shadowHeight: 6)
    container.frame = NSRect(x: 0, y: 0, width: 400, height: 38)
    container.layout()

    let gradient = try! #require(container.layer?.sublayers?.first { $0 is CAGradientLayer } as? CAGradientLayer)
    gradient.removeFromSuperlayer()
    #expect(container.layer?.sublayers?.contains { $0 is CAGradientLayer } != true)

    container.layout()

    let restored = try! #require(container.layer?.sublayers?.first { $0 is CAGradientLayer } as? CAGradientLayer)
    #expect(restored === gradient)
    #expect(restored.frame == NSRect(x: 0, y: 0, width: 400, height: 6))
}

@MainActor
@Test func panelContainerWithoutAShadowGivesTheWholeHeightToTheBar() {
    let content = BarContentView(side: .right, items: [.clock])
    let container = BarPanelContainer(content: content, shadowHeight: 0)
    container.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    container.layout()

    #expect(content.frame == NSRect(x: 0, y: 0, width: 400, height: 32))
    #expect(container.layer?.sublayers?.contains { $0 is CAGradientLayer } != true)
}

/// The enlarged panel keeps the bar flush with the top, left, and right edges.
@MainActor
@Test func panelFrameReservesTheShadowStripOnlyBelowTheBar() {
    let bar = CGRect(x: 0, y: 1075, width: 763, height: 32)

    // Off: the panel is exactly the bar rect.
    #expect(NSPanelBarSurface.panelFrame(for: bar, shadowHeight: 0) == bar)

    // On: the panel grows downward, so top/left/right stay flush.
    let expanded = NSPanelBarSurface.panelFrame(for: bar, shadowHeight: 6)
    #expect(expanded.minX == bar.minX)
    #expect(expanded.maxX == bar.maxX)
    #expect(expanded.maxY == bar.maxY)
    #expect(expanded.minY == bar.minY - 6)
    #expect(expanded.height == bar.height + 6)
}

/// The notch-side edge extends 6 points into the notch area to cover the
/// rounded corners of the housing (#0028).
@MainActor
@Test func notchExtensionCoversRoundedCorners() {
    let left = CGRect(x: 0, y: 950, width: 680, height: 32)
    let right = CGRect(x: 832, y: 950, width: 680, height: 32)

    let leftExtended = NSPanelBarSurface.extendFrameIntoNotch(left, side: .left)
    let rightExtended = NSPanelBarSurface.extendFrameIntoNotch(right, side: .right)

    // Left extends 6 points to the right
    #expect(leftExtended.maxX == left.maxX + 6)
    #expect(leftExtended.width == left.width + 6)
    // Right extends 6 points to the left
    #expect(rightExtended.minX == right.minX - 6)
    #expect(rightExtended.width == right.width + 6)
}

/// A notch-free top-edge layout with a centre seam is *not* a notch: the
/// extension must not apply even though the segments are separated by a gap.
/// This is the guard against inferring the notch from the segment gap alone.
@MainActor
@Test(.windowless)
func notchExtensionDoesNotApplyToATopEdgeSeamWithoutAHousing() {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    // A positive clearance gives this fallback row a real centre seam.
    let geometry = BarContentPolicy(height: 32, clearance: 10, edgeMargin: 0)
        .geometry(screen: ScreenGeometry(frame: screen,
                                         visibleFrame: screen,
                                         safeAreaTop: 0),
                  nativeMenuBarInset: 0)
    #expect(geometry.left.maxX < geometry.right.minX) // there is a seam ...
    #expect(!geometry.hasNotch)                       // ... but no housing

    let presenter = RecordingWindowPresenter()
    let surface = NSPanelBarSurface(id: DisplayBarID(7), on: screen, presenter: presenter)
    surface.apply(DisplayBarUpdate(id: DisplayBarID(7),
                                   placement: BarPlacement(mode: .topEdge, geometry: geometry),
                                   animated: false,
                                   cancelAnimations: false,
                                   visibility: .hidden),
                  reduceMotion: false)

    // The presenter saw both panels; neither was ordered onto the screen (#0091).
    #expect(presenter.orderFrontRegardlessCount == 2)
    #expect(presenter.orderedWindows.allSatisfy { !$0.isVisible })

    let frames = try! #require(surface.appliedPanelFrames)
    // No 6pt extension: the panels are exactly the geometry's segments.
    #expect(frames.left == geometry.left)
    #expect(frames.right == geometry.right)
}

/// Below the native bar there is no camera housing alongside the row, so the
/// extension never applies even though the notched display has one above.
@MainActor
@Test(.windowless)
func notchExtensionDoesNotApplyBelowNativeBar() {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1107)
    let notched = ScreenGeometry(
        frame: screen,
        visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
        safeAreaTop: 33,
        auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
        auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33))
    let policy = BarContentPolicy(height: 32, clearance: 10, edgeMargin: 0)
    let placement = try! #require(BarPlacementResolver.placement(
        screen: notched, visibility: .visible(inset: 33), policy: policy))
    #expect(placement.mode == .belowNativeBar(inset: 33))
    #expect(!placement.geometry.hasNotch)

    let presenter = RecordingWindowPresenter()
    let surface = NSPanelBarSurface(id: DisplayBarID(8), on: screen, presenter: presenter)
    surface.apply(DisplayBarUpdate(id: DisplayBarID(8),
                                   placement: placement,
                                   animated: false,
                                   cancelAnimations: false,
                                   visibility: .visible(inset: 33)),
                  reduceMotion: false)

    #expect(presenter.orderFrontRegardlessCount == 2)
    #expect(presenter.orderedWindows.allSatisfy { !$0.isVisible })

    let frames = try! #require(surface.appliedPanelFrames)
    #expect(frames.left == placement.geometry.left)
    #expect(frames.right == placement.geometry.right)
}

/// The extension runs through the production placement path:
/// `apply(update:)` → `move()` → `extendFrameIntoNotch()` → `panel.setFrame()`.
/// The applied panel frames are asserted directly, so this fails if production
/// placement ever stops extending.
@MainActor
@Test(.windowless)
func notchExtensionAppliesCorrectFrameThroughPlacementPath() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let notched = ScreenGeometry(
        frame: screen,
        visibleFrame: screen,
        safeAreaTop: 32,
        auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 680, height: 32),
        auxiliaryTopRight: CGRect(x: 832, y: 950, width: 680, height: 32))
    let placement = try! #require(BarPlacementResolver.placement(screen: notched, visibility: .hidden))
    #expect(placement.mode == .topEdge)
    #expect(placement.geometry.hasNotch)

    let presenter = RecordingWindowPresenter()
    let surface = NSPanelBarSurface(id: DisplayBarID(9), on: screen, presenter: presenter)
    surface.apply(DisplayBarUpdate(id: DisplayBarID(9),
                                   placement: placement,
                                   animated: false,
                                   cancelAnimations: false,
                                   visibility: .hidden),
                  reduceMotion: false)

    #expect(presenter.orderFrontRegardlessCount == 2)
    #expect(presenter.orderedWindows.allSatisfy { !$0.isVisible })

    let frames = try! #require(surface.appliedPanelFrames)
    let g = placement.geometry
    // Left fill covers the housing's left edge plus the 6pt extension ...
    #expect(frames.left.maxX == g.left.maxX + 6)
    #expect(frames.left.width == g.left.width + 6)
    // ... and the right fill does the same from the other side.
    #expect(frames.right.minX == g.right.minX - 6)
    #expect(frames.right.width == g.right.width + 6)
    // The extension is exactly the 6pt budget the design calls for.
    #expect(frames.left.maxX - g.left.maxX == 6)
    #expect(g.right.minX - frames.right.minX == 6)
}
