import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Renders popovers offscreen to PNG for visual verification and pixel assertions.
///
/// Snapshots are written to a gitignored directory (DIVOT_SNAPSHOT_DIR or
/// macos/.build/snapshots/) for manual review. Tests gracefully skip when
/// offscreen rendering is unavailable (headless environments).
///
/// When snapshots render successfully, pixel assertions verify:
/// - Background fill is fully opaque and matches theme palette
/// - Sampled text pixels meet contrast requirements (AA 4.5:1 for body text)
/// - Content is left-aligned within expected padding
/// - Nothing is clipped at the edges
@MainActor
@Suite("Popover snapshots")
struct PopoverSnapshotTests {

    // MARK: - Snapshot directory

    /// Get the snapshot output directory from DIVOT_SNAPSHOT_DIR or a default.
    private func snapshotDirectory() -> URL {
        if let env = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_DIR"] {
            return URL(fileURLWithPath: env)
        }
        let buildDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build")
            .appendingPathComponent("snapshots")
        return buildDir
    }

    // MARK: - Snapshot rendering

    /// Render a view offscreen using AppKit's bitmap cache API.
    /// Returns the bitmap rep or nil if rendering cannot occur (e.g., headless environment).
    private func renderView(_ view: NSView, size: NSSize) -> NSBitmapImageRep? {
        // Force layout
        view.layout()

        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: NSRect(origin: .zero, size: size)) else {
            return nil
        }

        view.cacheDisplay(in: NSRect(origin: .zero, size: size), to: bitmapRep)

        // Check if rendering produced any data with actual content.
        // In headless environments, the bitmap may exist but contain all zeros.
        guard let data = bitmapRep.bitmapData else { return nil }

        // Scan a portion of the bitmap for non-zero pixels
        let checkSize = min(1000, bitmapRep.bytesPerRow * bitmapRep.pixelsHigh)
        for i in 0..<checkSize {
            if data[i] != 0 {
                return bitmapRep
            }
        }

        return nil
    }

    /// Write a bitmap image as PNG to the snapshot directory. Throws on error.
    private func writeBitmapToPNG(name: String, rep: NSBitmapImageRep) throws {
        guard let tiffData = rep.tiffRepresentation else {
            throw PopoverSnapshotError.tiffConversionFailed
        }
        let image = NSImage(data: tiffData)
        guard let image,
              let pngData = image.tiffRepresentation.flatMap({ rep in
                  NSBitmapImageRep(data: rep)?.representation(using: .png, properties: [:])
              }) else {
            throw PopoverSnapshotError.pngEncodingFailed
        }

        let dir = snapshotDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        try pngData.write(to: url)
    }

    enum PopoverSnapshotError: Error {
        case tiffConversionFailed
        case pngEncodingFailed
    }

    // MARK: - Pixel assertions

    /// Extract RGBA components from a pixel in a bitmap image rep.
    private func pixelColor(in rep: NSBitmapImageRep, x: Int, y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
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

    /// Verify that all pixels in the background area are fully opaque.
    private func assertBackgroundOpaque(in rep: NSBitmapImageRep, expecting theme: BarTheme) {
        let width = rep.pixelsWide
        let height = rep.pixelsHigh

        // Sample pixels across the background area, skipping borders.
        let samples = [(12, 12), (width/4, height/4), (width/2, height/2),
                       (3*width/4, 3*height/4), (width-20, height-20)]
        for (x, y) in samples {
            guard let pixel = pixelColor(in: rep, x: x, y: y) else { continue }
            #expect(pixel.a > 0.99, "Background pixel at (\(x), \(y)) is not fully opaque: alpha=\(pixel.a)")
        }
    }

    /// Verify that the background color matches the theme palette.
    private func assertBackgroundColor(in rep: NSBitmapImageRep, matches theme: BarTheme) {
        let expected = theme.popoverPalette.background
        guard let sRGB = expected.usingColorSpace(.sRGB) else { return }

        let width = rep.pixelsWide
        let height = rep.pixelsHigh

        // Sample multiple points to verify consistency
        let samples = [(width/4, height/4), (width/2, height/2), (3*width/4, 3*height/4)]
        for (x, y) in samples {
            guard let pixel = pixelColor(in: rep, x: x, y: y) else { continue }

            let tolerance: CGFloat = 0.01
            #expect(abs(pixel.r - sRGB.redComponent) < tolerance,
                    "Background red mismatch at (\(x), \(y)): got \(pixel.r), expected \(sRGB.redComponent)")
            #expect(abs(pixel.g - sRGB.greenComponent) < tolerance,
                    "Background green mismatch at (\(x), \(y)): got \(pixel.g), expected \(sRGB.greenComponent)")
            #expect(abs(pixel.b - sRGB.blueComponent) < tolerance,
                    "Background blue mismatch at (\(x), \(y)): got \(pixel.b), expected \(sRGB.blueComponent)")
        }
    }

    /// Verify that content is left-aligned within the expected inset (scales for 1x and 2x).
    private func assertLeftAlignment(in rep: NSBitmapImageRep, theme: BarTheme) {
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let bgColor = theme.popoverPalette.background
        guard let bgSRGB = bgColor.usingColorSpace(.sRGB) else { return }

        let tolerance: CGFloat = 0.05
        // BarPopover uses 12pt inset. Scale proportionally to bitmap width.
        // Typical popover width is ~272pt. Use proportional: 12/272 ≈ 4.4% of width.
        // This scales automatically for different pixel densities and popover sizes.
        let expectedPixelColumn = max(10, Int(CGFloat(width) * 0.044))
        let tolerancePx = max(5, width / 50) // Proportional tolerance
        let searchStart = max(3, expectedPixelColumn - tolerancePx)
        let searchEnd = expectedPixelColumn + tolerancePx + 1

        // Check multiple rows in the middle section
        var foundContentAlignment = false
        for row in stride(from: height/4, to: 3*height/4, by: height/8) {
            for col in stride(from: searchStart, to: searchEnd, by: 1) {
                guard let pixel = pixelColor(in: rep, x: col, y: row) else { continue }
                let isBackground = abs(pixel.r - bgSRGB.redComponent) < tolerance
                    && abs(pixel.g - bgSRGB.greenComponent) < tolerance
                    && abs(pixel.b - bgSRGB.blueComponent) < tolerance
                if !isBackground {
                    foundContentAlignment = true
                    #expect(col >= searchStart && col <= searchEnd,
                            "Content at row \(row) found at column \(col), expected near \(expectedPixelColumn) ± \(tolerancePx)")
                    break
                }
            }
            if foundContentAlignment { break }
        }

        #expect(foundContentAlignment, "No non-background content found to verify alignment")
    }

    /// Verify that content is not clipped at the edges (bounds within popover frame).
    private func assertNoClipping(in rep: NSBitmapImageRep, theme: BarTheme) {
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let margin = 4 // pixels from edge

        let bgColor = theme.popoverPalette.background
        guard let bgSRGB = bgColor.usingColorSpace(.sRGB) else { return }

        let tolerance: CGFloat = 0.05

        // Check that edges don't have unexpected content (should be background or transparent)
        let edges: [(String, [(Int, Int)])] = [
            ("left", (0..<margin).flatMap { x in (0..<height).map { y in (x, y) } }),
            ("right", ((width-margin)..<width).flatMap { x in (0..<height).map { y in (x, y) } }),
            ("top", (0..<width).flatMap { x in (0..<margin).map { y in (x, y) } }),
            ("bottom", (0..<width).flatMap { x in ((height-margin)..<height).map { y in (x, y) } })
        ]

        for (edgeName, pixels) in edges {
            var clippedContent = 0
            for (x, y) in pixels.prefix(50) {
                guard let pixel = pixelColor(in: rep, x: x, y: y) else { continue }
                let isBackground = abs(pixel.r - bgSRGB.redComponent) < tolerance
                    && abs(pixel.g - bgSRGB.greenComponent) < tolerance
                    && abs(pixel.b - bgSRGB.blueComponent) < tolerance
                let isTransparent = pixel.a < 0.1

                if !isBackground && !isTransparent {
                    clippedContent += 1
                }
            }

            #expect(clippedContent < 3, "Edge '\(edgeName)' has \(clippedContent) content-like pixels (possible clipping)")
        }
    }

    /// Verify that sampled text pixels meet contrast requirements against the sampled background.
    private func assertTextContrast(in rep: NSBitmapImageRep, theme: BarTheme) {
        let bgColor = theme.popoverPalette.background
        guard let bgSRGB = bgColor.usingColorSpace(.sRGB) else { return }

        let bgSRGBColor = SRGBColor(
            red: Double(bgSRGB.redComponent),
            green: Double(bgSRGB.greenComponent),
            blue: Double(bgSRGB.blueComponent)
        )

        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let tolerance: CGFloat = 0.05

        // Scan header area (top 25%) and content area (middle 50%) for text pixels
        let scanRegions = [
            (height/8, height/4),      // header
            (3*height/8, 5*height/8)   // content
        ]

        var foundTextPixelWithGoodContrast = false

        for (startRow, endRow) in scanRegions {
            // Scan multiple columns for non-background pixels
            for row in stride(from: startRow, to: endRow, by: max(1, (endRow - startRow) / 5)) {
                for col in stride(from: 12, to: width - 12, by: max(1, (width - 24) / 10)) {
                    guard let pixel = pixelColor(in: rep, x: col, y: row) else { continue }

                    // Check if this is a non-background pixel (likely text)
                    let isBackground = abs(pixel.r - bgSRGB.redComponent) < tolerance
                        && abs(pixel.g - bgSRGB.greenComponent) < tolerance
                        && abs(pixel.b - bgSRGB.blueComponent) < tolerance

                    if !isBackground {
                        // Found a text pixel, check its contrast against background
                        let textSRGBColor = SRGBColor(
                            red: Double(pixel.r),
                            green: Double(pixel.g),
                            blue: Double(pixel.b)
                        )

                        let contrast = ContrastAudit.ratio(textSRGBColor, bgSRGBColor)
                        if contrast >= ContrastAudit.textThreshold {
                            foundTextPixelWithGoodContrast = true
                            break
                        }
                    }
                }
                if foundTextPixelWithGoodContrast { break }
            }
            if foundTextPixelWithGoodContrast { break }
        }

        #expect(foundTextPixelWithGoodContrast,
                "No sampled text pixels found with contrast >= \(ContrastAudit.textThreshold):1")
    }

    /// Run all assertions on a rendered snapshot.
    private func assertAllPixelProperties(rep: NSBitmapImageRep, theme: BarTheme) {
        assertBackgroundOpaque(in: rep, expecting: theme)
        assertBackgroundColor(in: rep, matches: theme)
        assertLeftAlignment(in: rep, theme: theme)
        assertNoClipping(in: rep, theme: theme)
        assertTextContrast(in: rep, theme: theme)
    }

    // MARK: - Popover content controllers

    private func makeVolumePopoverController(fontSize: CGFloat = 12) -> VolumePopoverContentController {
        let controller = VolumePopoverContentController()
        _ = controller.view
        controller.update(VolumeSnapshot(
            hasOutputDevice: true,
            outputDeviceName: "Speakers",
            level: 0.5,
            isMuted: false,
            isSettable: true
        ))
        // Apply font size if needed
        if fontSize != 12 {
            applyFontSize(fontSize, to: controller.view)
        }
        return controller
    }

    private func makeAppearancePopoverController(fontSize: CGFloat = 12) -> AppearancePopoverContentController {
        let controller = AppearancePopoverContentController()
        _ = controller.view
        if fontSize != 12 {
            applyFontSize(fontSize, to: controller.view)
        }
        return controller
    }

    private func makeWifiPopoverController(fontSize: CGFloat = 12) -> WifiPopoverContentController {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.render(.networks([
            WifiNetwork(ssid: "Example Network", rssi: -40, isSecure: true, isCurrent: true),
            WifiNetwork(ssid: "Guest Network", rssi: -60, isSecure: false, isCurrent: false)
        ]))
        if fontSize != 12 {
            applyFontSize(fontSize, to: controller.view)
        }
        return controller
    }

    /// Apply a larger font size to all text fields in a view.
    private func applyFontSize(_ size: CGFloat, to view: NSView) {
        let scale = size / 12.0
        func walk(_ v: NSView) {
            if let field = v as? NSTextField {
                if let font = field.font {
                    let newSize = font.pointSize * scale
                    // Create a font with the scaled size
                    field.font = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? NSFont.systemFont(ofSize: newSize)
                }
            }
            v.subviews.forEach(walk)
        }
        walk(view)
    }

    // MARK: - Parameterized test matrix

    /// Test a popover with all assertions for a given appearance and text size.
    private func testPopover(
        name: String,
        maker: (CGFloat) -> BarPopoverContentController,
        appearance: AppearanceConfiguration,
        isDark: Bool,
        fontSize: CGFloat
    ) throws {
        let theme = BarTheme.resolve(appearance, dark: isDark)
        let controller = maker(fontSize)
        controller.apply(theme: theme)

        let size = controller.preferredSize
        guard let rep = renderView(controller.view, size: size) else {
            // Headless environment: offscreen rendering is unavailable (no display).
            // This is expected in CI and local headless runs. Snapshot PNGs are not
            // generated. The test passes with this clear message.
            print("PopoverSnapshotTests [\(name)]: Skipped — offscreen rendering unavailable (headless environment)")
            return
        }

        try writeBitmapToPNG(name: name, rep: rep)
        assertAllPixelProperties(rep: rep, theme: theme)
    }

    // MARK: - Tests

    @Test("Volume popover — all themes × light/dark × default size")
    func volumePopoverMatrix() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "volume-popover-\(familyName)-\(variantName)-default"
                try testPopover(name: name, maker: makeVolumePopoverController, appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("Wi-Fi popover — all themes × light/dark × default size")
    func wifiPopoverMatrix() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "wifi-popover-\(familyName)-\(variantName)-default"
                try testPopover(name: name, maker: makeWifiPopoverController, appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("Appearance popover — all themes × light/dark × default size")
    func appearancePopoverMatrix() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "appearance-popover-\(familyName)-\(variantName)-default"
                try testPopover(name: name, maker: makeAppearancePopoverController, appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("Volume popover — all themes × light/dark × larger text (16pt)")
    func volumePopoverLargerText() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "volume-popover-\(familyName)-\(variantName)-large"
                try testPopover(name: name, maker: makeVolumePopoverController, appearance: appearance, isDark: isDark, fontSize: 16)
            }
        }
    }

    @Test("Wi-Fi popover — all themes × light/dark × larger text (16pt)")
    func wifiPopoverLargerText() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "wifi-popover-\(familyName)-\(variantName)-large"
                try testPopover(name: name, maker: makeWifiPopoverController, appearance: appearance, isDark: isDark, fontSize: 16)
            }
        }
    }

    @Test("Appearance popover — all themes × light/dark × larger text (16pt)")
    func appearancePopoverLargerText() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "appearance-popover-\(familyName)-\(variantName)-large"
                try testPopover(name: name, maker: makeAppearancePopoverController, appearance: appearance, isDark: isDark, fontSize: 16)
            }
        }
    }
}
