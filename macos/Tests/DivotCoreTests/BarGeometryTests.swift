import Foundation
import CoreGraphics
import Testing
@testable import DivotCore

@Test func notchZeroGapNoSeam() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let g = BarGeometry(screen: screen,
        topLeft: CGRect(x: 0, y: 950, width: 680, height: 32),
        topRight: CGRect(x: 832, y: 950, width: 680, height: 32),
        height: 40, gap: 0)
    #expect(g.left == CGRect(x: 0, y: 950, width: 680, height: 32))
    #expect(g.right == CGRect(x: 832, y: 950, width: 680, height: 32))
    #expect(g.left.maxX == 680 && g.right.minX == 832)
}

@Test func externalDisplayWithNegativeOrigin() {
    let g = BarGeometry(screen: CGRect(x: -1920, y: -200, width: 1920, height: 1080))
    let h = BarMetrics.default.height
    // With gap=0, the middle gap is 0, so each half is exactly 960 (1920/2)
    #expect(g.left == CGRect(x: -1920, y: 1080 - 200 - h, width: 960, height: h))
    #expect(g.right == CGRect(x: -960, y: 1080 - 200 - h, width: 960, height: h))
}

@Test func largeGapDoesNotCreateNegativeWidth() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 20, height: 10), height: 40, gap: 100)
    #expect(g.left.width == 0 && g.right.width == 0)
    #expect(g.left.height == 10 && g.right.height == 10)
}

@Test func oneMissingAuxiliaryRegionFallsBack() {
    let s = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let g = BarGeometry(screen: s, topLeft: CGRect(x: 0, y: 768, width: 400, height: 32))
    // Missing right auxiliary region, uses fallback. With gap=0, each half = 500.
    #expect(g.left.width == 500 && g.right.minX == 500)
}

@Test func invalidAuxiliaryRegionsFallBack() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
        topLeft: CGRect(x: 0, y: 900, width: 400, height: 32),
        topRight: CGRect(x: 600, y: 900, width: 400, height: 32))
    // Auxiliary regions are invalid (outside screen), uses fallback. With gap=0, width = 500.
    #expect(g.left.maxY == 800 && g.left.width == 500)
}

@Test func nonfiniteParametersUseDefaults() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 800), height: .nan, gap: .infinity)
    // Nonfinite gap falls back to default 0, so width = 500 (half the screen)
    #expect(g.left.height == BarMetrics.default.height && g.left.width == 500)
}

@Test func belowNativeBarSpansWidthWithoutNotchGap() {
    // Same notched display as the top-edge case, but the native bar is revealed,
    // so the bar moves below the 33pt band and closes the notch gap.
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1107)
    let g = BarGeometry(screen: screen,
        topLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
        topRight: CGRect(x: 948, y: 1074, width: 762, height: 33),
        height: 32, gap: 10, nativeMenuBarInset: 33)
    #expect(g.left == CGRect(x: 0, y: 1042, width: 845, height: 32))
    #expect(g.right == CGRect(x: 865, y: 1042, width: 845, height: 32))
    // 20pt seam, not the 185pt housing gap.
    #expect(g.right.minX - g.left.maxX == 20)
}

@Test func belowNativeBarDoesNotFallOffScreen() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 100, height: 40),
        height: 32, gap: 10, nativeMenuBarInset: 1000)
    #expect(g.left.minY == 0 && g.left.height == 0)
    #expect(g.right.minY == 0)
}

@Test func nonfiniteInsetFallsBackToTopEdge() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 800), height: 32,
        gap: 10, nativeMenuBarInset: .nan)
    #expect(g.left.maxY == 800)
}

