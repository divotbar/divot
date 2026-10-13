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

    /// True when `url` is somewhere git ignores: a path inside a `.build` directory or ending in `snapshots`,
    /// or the RepoOS shot directory (`REPOOS_SHOT_DIR`, under the gitignored
    /// `work/.attachments/`) when `DIVOT_SNAPSHOT_DIR` points exactly at it.
    static func isIgnoredLocation(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let components = url.standardizedFileURL.pathComponents
        if components.contains(".build") || components.last == "snapshots" { return true }
        guard let shot = ProcessInfo.processInfo.environment["REPOOS_SHOT_DIR"], !shot.isEmpty else {
            return false
        }
        let shotPath = URL(fileURLWithPath: shot).standardizedFileURL.path
        return path == shotPath && shotPath.contains("/.attachments/")
    }

    /// The snapshot output directory: `DIVOT_SNAPSHOT_DIR` if set (it must be an
    /// ignored location, so rendered images can never be committed), otherwise
    /// `macos/.build/snapshots/`. `testFile` is the calling test's `#filePath`.
    static func snapshotDirectory(testFile: String = #filePath) -> URL {
        if let env = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_DIR"] {
            let url = URL(fileURLWithPath: env)
            if !isIgnoredLocation(url) {
                preconditionFailure("DIVOT_SNAPSHOT_DIR must be under an ignored path (be inside '.build', end in 'snapshots', or be REPOOS_SHOT_DIR)")
            }
            return url
        }
        let macosDir = URL(fileURLWithPath: testFile)
            .deletingLastPathComponent()  // DivotAppKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // macos
        return macosDir.appendingPathComponent(".build").appendingPathComponent("snapshots")
    }

    /// Whether `name` belongs in this run's output. The full matrix is written
    /// unless `DIVOT_SNAPSHOT_SET=shots`, which keeps a small representative set
    /// for RepoOS evidence: native light and dark at the default text size, the
    /// bar with chips off and chips on (translucent), Gruvbox popovers (non-bar)
    /// light and dark, and each popover. Assertions run for every name either way.
    static func wantsPNG(named name: String) -> Bool {
        guard ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_SET"] == "shots" else { return true }
        // Native or (Gruvbox non-bar only), light and dark, at the default size.
        guard name.contains("-native-") || (name.contains("-gruvbox-") && !name.hasPrefix("bar-")),
              name.contains("-default") else { return false }
        if !name.hasPrefix("bar-") { return true }
        // For bar renders, include chips-off and chips-on (translucent); exclude chips-solid
        return name.hasSuffix("-chips-off") || name.hasSuffix("-chips-on")
    }

    /// Write a bitmap as PNG into `directory` (created if needed). Skipped when
    /// the reduced set excludes `name`.
    static func writePNG(name: String, rep: NSBitmapImageRep, directory: URL) throws {
        guard wantsPNG(named: name) else { return }
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
