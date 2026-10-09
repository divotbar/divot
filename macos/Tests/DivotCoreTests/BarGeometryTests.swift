import Foundation
import CoreGraphics
import Testing
@testable import DivotCore

@Test func notchClearanceAndHeightClamping() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let g = BarGeometry(screen: screen,
        topLeft: CGRect(x: 0, y: 950, width: 680, height: 32),
        topRight: CGRect(x: 832, y: 950, width: 680, height: 32),
        height: 40, gap: 10)
    #expect(g.left == CGRect(x: 0, y: 950, width: 670, height: 32))
    #expect(g.right == CGRect(x: 842, y: 950, width: 670, height: 32))
    #expect(g.left.maxX < 680 && g.right.minX > 832)
}

@Test func externalDisplayWithNegativeOrigin() {
    let g = BarGeometry(screen: CGRect(x: -1920, y: -200, width: 1920, height: 1080))
    #expect(g.left == CGRect(x: -1920, y: 848, width: 950, height: 32))
    #expect(g.right == CGRect(x: -950, y: 848, width: 950, height: 32))
}

@Test func largeGapDoesNotCreateNegativeWidth() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 20, height: 10), height: 40, gap: 100)
    #expect(g.left.width == 0 && g.right.width == 0)
    #expect(g.left.height == 10 && g.right.height == 10)
}

@Test func oneMissingAuxiliaryRegionFallsBack() {
    let s = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let g = BarGeometry(screen: s, topLeft: CGRect(x: 0, y: 768, width: 400, height: 32))
    #expect(g.left.width == 490 && g.right.minX == 510)
}

@Test func invalidAuxiliaryRegionsFallBack() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
        topLeft: CGRect(x: 0, y: 900, width: 400, height: 32),
        topRight: CGRect(x: 600, y: 900, width: 400, height: 32))
    #expect(g.left.maxY == 800 && g.left.width == 490)
}

@Test func nonfiniteParametersUseDefaults() {
    let g = BarGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 800), height: .nan, gap: .infinity)
    #expect(g.left.height == 32 && g.left.width == 490)
}
