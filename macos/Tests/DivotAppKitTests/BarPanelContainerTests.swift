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
