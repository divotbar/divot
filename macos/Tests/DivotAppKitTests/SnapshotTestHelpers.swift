import AppKit
import DivotCore

/// Shared utilities for rendering views offscreen to PNG and performing pixel assertions.
/// Used by PopoverSnapshotTests and BarSnapshotTests to avoid duplication.
@MainActor
struct SnapshotTestHelpers {

    /// Render a view offscreen using AppKit's bitmap cache API.
    /// Returns the bitmap rep or nil if rendering cannot occur (e.g., headless environment).
    static func renderView(_ view: NSView, size: NSSize) -> NSBitmapImageRep? {
        view.layout()

        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: NSRect(origin: .zero, size: size)) else {
            return nil
        }

        view.cacheDisplay(in: NSRect(origin: .zero, size: size), to: bitmapRep)

        guard let data = bitmapRep.bitmapData else { return nil }

        let checkSize = min(1000, bitmapRep.bytesPerRow * bitmapRep.pixelsHigh)
        for i in 0..<checkSize {
            if data[i] != 0 {
                return bitmapRep
            }
        }

        return nil
    }

    /// Write a bitmap image as PNG to the snapshot directory. Throws on error.
    static func writeBitmapToPNG(name: String, rep: NSBitmapImageRep, directory: URL) throws {
        guard let tiffData = rep.tiffRepresentation else {
            throw SnapshotError.tiffConversionFailed
        }
        let image = NSImage(data: tiffData)
        guard let image,
              let pngData = image.tiffRepresentation.flatMap({ rep in
                  NSBitmapImageRep(data: rep)?.representation(using: .png, properties: [:])
              }) else {
            throw SnapshotError.pngEncodingFailed
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        try pngData.write(to: url)
    }

    enum SnapshotError: Error {
        case tiffConversionFailed
        case pngEncodingFailed
    }

    /// Extract RGBA components from a pixel in a bitmap image rep.
    static func pixelColor(in rep: NSBitmapImageRep, x: Int, y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard x >= 0, x < rep.pixelsWide, y >= 0, y < rep.pixelsHigh else { return nil }
        guard let data = rep.bitmapData else { return nil }

        let bytesPerPixel = rep.bitsPerPixel / 8
        let bytesPerRow = rep.bytesPerRow
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)

        let r = CGFloat(data[offset]) / 255.0
        let g = CGFloat(data[offset + 1]) / 255.0
        let b = CGFloat(data[offset + 2]) / 255.0
        let a = bytesPerPixel >= 4 ? CGFloat(data[offset + 3]) / 255.0 : 1.0

        return (r, g, b, a)
    }
}
