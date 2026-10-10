import AppKit
import Testing
@testable import DivotAppKit

@MainActor
@Test func menuBarMarkLoadsAsVectorTemplateImage() throws {
    let image = try #require(DivotMenuBarMark.image(pointSize: 18))
    #expect(image.isTemplate)
    #expect(image.size == NSSize(width: 18, height: 18))
    // A PDF representation keeps the mark sharp at any backing scale.
    #expect(image.representations.contains { $0 is NSPDFImageRep })
}

@MainActor
@Test func menuBarMarkDrawsGlyphWithTransparentPadding() throws {
    let image = try #require(DivotMenuBarMark.image(pointSize: 18))
    let pixels = 36
    let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: pixels,
                                            pixelsHigh: pixels,
                                            bitsPerSample: 8,
                                            samplesPerPixel: 4,
                                            hasAlpha: true,
                                            isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0,
                                            bitsPerPixel: 0))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    var opaque = 0
    for x in 0..<pixels {
        for y in 0..<pixels where rep.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.5 {
            opaque += 1
        }
    }
    // The glyph must actually draw, and dropping the tile must leave clear space.
    #expect(opaque > 0)
    #expect(opaque < pixels * pixels)
}
