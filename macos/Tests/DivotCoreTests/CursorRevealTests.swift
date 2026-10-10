import CoreGraphics
import Testing
@testable import DivotCore

private func display(id: UInt32, frame: CGRect) -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(id),
                          geometry: ScreenGeometry(frame: frame, visibleFrame: frame, safeAreaTop: 0))
}

@Test func topStripIsTheBandAtTheTopEdge() {
    let frame = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    #expect(CursorMenuBarReveal.isInTopStrip(mouseY: 1000, screenFrame: frame))
    #expect(CursorMenuBarReveal.isInTopStrip(mouseY: 997, screenFrame: frame))
    #expect(!CursorMenuBarReveal.isInTopStrip(mouseY: 995, screenFrame: frame))
    #expect(!CursorMenuBarReveal.isInTopStrip(mouseY: 1001, screenFrame: frame))
}

@Test func engagedDisplaysSelectTheDisplayUnderThePointer() {
    let left = display(id: 1, frame: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    let right = display(id: 2, frame: CGRect(x: 1600, y: 0, width: 1600, height: 1000))

    #expect(CursorMenuBarReveal.engagedDisplayIDs(mouseLocation: CGPoint(x: 100, y: 999),
                                                  displays: [left, right]) == [DisplayBarID(1)])
    #expect(CursorMenuBarReveal.engagedDisplayIDs(mouseLocation: CGPoint(x: 2000, y: 1000),
                                                  displays: [left, right]) == [DisplayBarID(2)])
    // Away from every strip: no display engages.
    #expect(CursorMenuBarReveal.engagedDisplayIDs(mouseLocation: CGPoint(x: 100, y: 500),
                                                  displays: [left, right]).isEmpty)
}

@Test func nonFinitePointerNeverEngages() {
    let screen = display(id: 1, frame: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    #expect(CursorMenuBarReveal.engagedDisplayIDs(mouseLocation: CGPoint(x: CGFloat.nan, y: CGFloat.nan),
                                                  displays: [screen]).isEmpty)
}
