import AppKit
import DivotCore

/// An sRGB colour with 0–1 channels, used for expected-vs-sampled comparisons.
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    var srgb: SRGBColor { SRGBColor(red: r, green: g, blue: b) }

    /// Largest per-channel difference.
    func delta(_ other: RGB) -> Double {
        max(abs(r - other.r), abs(g - other.g), abs(b - other.b))
    }

    /// `self` drawn over `background` at `alpha`.
    func blended(over background: RGB, alpha: Double) -> RGB {
        RGB(r: background.r * (1 - alpha) + r * alpha,
            g: background.g * (1 - alpha) + g * alpha,
            b: background.b * (1 - alpha) + b * alpha)
    }
}

/// A rendered bitmap converted to a known layout: 8-bit sRGB RGBA, row 0 at the
/// top. Converting once makes sampling independent of the display's colour
/// space and of the source rep's pixel format.
struct PixelBuffer {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ rep: NSBitmapImageRep) {
        guard let image = rep.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drew = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }
        self.width = width
        self.height = height
        self.bytes = data
    }

    func color(_ x: Int, _ y: Int) -> RGB {
        let offset = (y * width + x) * 4
        return RGB(r: Double(bytes[offset]) / 255,
                   g: Double(bytes[offset + 1]) / 255,
                   b: Double(bytes[offset + 2]) / 255)
    }

    func alpha(_ x: Int, _ y: Int) -> Double {
        Double(bytes[(y * width + x) * 4 + 3]) / 255
    }
}

/// Shared offscreen-render and PNG helpers for the snapshot suites.
@MainActor
enum SnapshotTestHelpers {

    /// Render a view with AppKit's bitmap cache API. Returns `nil` when nothing
    /// was drawn (no usable graphics context).
    static func render(_ view: NSView, size: NSSize) -> NSBitmapImageRep? {
        view.layoutSubtreeIfNeeded()
        let rect = NSRect(origin: .zero, size: size)
        guard let cacheRep = view.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        // Draw in sRGB rather than the display's colour space: alpha blends (the
        // translucent chips) differ by several percent between the two.
        let rep = cacheRep.retagging(with: .sRGB) ?? cacheRep
        view.cacheDisplay(in: rect, to: rep)
        guard let buffer = PixelBuffer(rep) else { return nil }
        for y in stride(from: 0, to: buffer.height, by: max(1, buffer.height / 4)) {
            for x in stride(from: 0, to: buffer.width, by: max(1, buffer.width / 8))
            where buffer.alpha(x, y) > 0 {
                return rep
            }
        }
        return nil
    }

    /// Write a bitmap as PNG into `directory` (created if needed).
    static func writePNG(name: String, rep: NSBitmapImageRep, directory: URL) throws {
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw SnapshotError.pngEncodingFailed
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    enum SnapshotError: Error {
        case pngEncodingFailed
    }

    /// Resolve a (possibly dynamic) colour under an appearance, as sRGB.
    static func rgb(_ color: NSColor, in appearance: NSAppearance) -> RGB {
        var result = RGB(r: 0, g: 0, b: 0)
        appearance.performAsCurrentDrawingAppearance {
            if let srgb = color.usingColorSpace(.sRGB) {
                result = RGB(r: Double(srgb.redComponent),
                             g: Double(srgb.greenComponent),
                             b: Double(srgb.blueComponent))
            }
        }
        return result
    }
}
