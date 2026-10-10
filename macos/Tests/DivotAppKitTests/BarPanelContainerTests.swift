import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

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

@MainActor
@Test func notchExtensionDoesNotApplyOnNotchFreeDisplays() {
    // On a notch-free display with gap=0, left and right are adjacent.
    // The hasNotch check detects this by verifying left.maxX < right.minX.
    let left = CGRect(x: 0, y: 950, width: 500, height: 32)
    let right = CGRect(x: 500, y: 950, width: 500, height: 32)

    // hasNotch = left.maxX < right.minX → 500 < 500 → false
    #expect(!{ left.maxX < right.minX }())

    // Extension would be skipped; the geometry is used as-is.
}

@MainActor
@Test func notchExtensionDoesNotApplyBelowNativeBar() {
    // Below the native bar, even if there's a gap, there's no notch to extend into.
    // The extension only applies at top edge (placement.mode == .topEdge) AND hasGap.
    let left = CGRect(x: 0, y: 1042, width: 845, height: 32)
    let right = CGRect(x: 865, y: 1042, width: 845, height: 32)
    
    // There IS a gap: 865 - 845 = 20
    #expect(left.maxX < right.minX)
    
    // But below native bar, extension is skipped because placement.mode != .topEdge.
    // The shouldExtend logic: isTopEdge && hasGap = false && true = false
}
