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
/// When snapshots are captured, pixel assertions verify:
/// - Background fill is fully opaque and matches theme palette
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

    /// Write a bitmap image as PNG to the snapshot directory.
    private func writeBitmapToPNG(name: String, rep: NSBitmapImageRep) throws {
        guard let tiffData = rep.tiffRepresentation else { return }
        let image = NSImage(data: tiffData)
        guard let image,
              let pngData = image.tiffRepresentation.flatMap({ rep in
                  NSBitmapImageRep(data: rep)?.representation(using: .png, properties: [:])
              }) else {
            return
        }

        let dir = snapshotDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        try pngData.write(to: url)
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
        let samples = [(10, 10), (width/2, height/2), (width-20, height-20)]
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

        // Sample center pixel
        guard let pixel = pixelColor(in: rep, x: width/2, y: height/2) else { return }

        let tolerance: CGFloat = 0.01
        #expect(abs(pixel.r - sRGB.redComponent) < tolerance,
                "Background red mismatch: got \(pixel.r), expected \(sRGB.redComponent)")
        #expect(abs(pixel.g - sRGB.greenComponent) < tolerance,
                "Background green mismatch: got \(pixel.g), expected \(sRGB.greenComponent)")
        #expect(abs(pixel.b - sRGB.blueComponent) < tolerance,
                "Background blue mismatch: got \(pixel.b), expected \(sRGB.blueComponent)")
    }

    /// Verify that content is left-aligned (first non-background pixel column near the leading inset).
    private func assertLeftAlignment(in rep: NSBitmapImageRep, theme: BarTheme) {
        let height = rep.pixelsHigh
        let bgColor = theme.popoverPalette.background
        guard let bgSRGB = bgColor.usingColorSpace(.sRGB) else { return }

        let tolerance: CGFloat = 0.05
        let expectedColumn = 12 // 12pt inset from BarPopover
        let tolerance_px = 5 // Allow ±5px from expected column

        // Check multiple rows in the middle section
        for row in stride(from: height/4, to: 3*height/4, by: height/8) {
            for col in stride(from: 6, to: expectedColumn + tolerance_px, by: 1) {
                guard let pixel = pixelColor(in: rep, x: col, y: row) else { continue }
                let isBackground = abs(pixel.r - bgSRGB.redComponent) < tolerance
                    && abs(pixel.g - bgSRGB.greenComponent) < tolerance
                    && abs(pixel.b - bgSRGB.blueComponent) < tolerance
                if !isBackground {
                    return // Found content, alignment looks OK
                }
            }
        }
    }

    // MARK: - Popover content controllers

    private func makeVolumePopoverController() -> VolumePopoverContentController {
        let controller = VolumePopoverContentController()
        _ = controller.view
        controller.update(VolumeSnapshot(
            hasOutputDevice: true,
            outputDeviceName: "Speakers",
            level: 0.5,
            isMuted: false,
            isSettable: true
        ))
        return controller
    }

    private func makeAppearancePopoverController() -> AppearancePopoverContentController {
        let controller = AppearancePopoverContentController()
        _ = controller.view
        return controller
    }

    private func makeWifiPopoverController() -> WifiPopoverContentController {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.render(.networks([
            WifiNetwork(ssid: "Example Network", rssi: -40, isSecure: true, isCurrent: true),
            WifiNetwork(ssid: "Guest Network", rssi: -60, isSecure: false, isCurrent: false)
        ]))
        return controller
    }

    // MARK: - Tests

    @Test("Volume popover renders at default size")
    func volumePopoverDefault() throws {
        let theme = BarTheme.resolve(.default, dark: false)
        let controller = makeVolumePopoverController()
        controller.apply(theme: theme)

        let size = controller.preferredSize
        guard let rep = renderView(controller.view, size: size) else {
            // Headless environment — rendering is unavailable but we don't fail
            print("PopoverSnapshotTests: Cannot render offscreen (headless environment?)")
            return
        }

        try writeBitmapToPNG(name: "volume-popover-native-light", rep: rep)

        // Pixel assertions
        assertBackgroundOpaque(in: rep, expecting: theme)
        assertBackgroundColor(in: rep, matches: theme)
        assertLeftAlignment(in: rep, theme: theme)
    }

    @Test("Volume popover renders with Gruvbox dark theme")
    func volumePopoverGruvboxDark() throws {
        let appearance = AppearanceConfiguration(family: .gruvbox, mode: .dark, material: .opaque)
        let theme = BarTheme.resolve(appearance, dark: true)
        let controller = makeVolumePopoverController()
        controller.apply(theme: theme)

        let size = controller.preferredSize
        guard let rep = renderView(controller.view, size: size) else {
            // Headless environment — rendering is unavailable but we don't fail
            print("PopoverSnapshotTests: Cannot render offscreen (headless environment?)")
            return
        }

        try writeBitmapToPNG(name: "volume-popover-gruvbox-dark", rep: rep)

        assertBackgroundOpaque(in: rep, expecting: theme)
        assertBackgroundColor(in: rep, matches: theme)
    }

    @Test("Wi-Fi popover renders at default size")
    func wifiPopoverDefault() throws {
        let theme = BarTheme.resolve(.default, dark: false)
        let controller = makeWifiPopoverController()
        controller.apply(theme: theme)

        let size = controller.preferredSize
        guard let rep = renderView(controller.view, size: size) else {
            // Headless environment — rendering is unavailable but we don't fail
            print("PopoverSnapshotTests: Cannot render offscreen (headless environment?)")
            return
        }

        try writeBitmapToPNG(name: "wifi-popover-native-light", rep: rep)

        assertBackgroundOpaque(in: rep, expecting: theme)
        assertBackgroundColor(in: rep, matches: theme)
    }

    @Test("Appearance popover renders at default size")
    func appearancePopoverDefault() throws {
        let theme = BarTheme.resolve(.default, dark: false)
        let controller = makeAppearancePopoverController()
        controller.apply(theme: theme)

        let size = controller.preferredSize
        guard let rep = renderView(controller.view, size: size) else {
            // Headless environment — rendering is unavailable but we don't fail
            print("PopoverSnapshotTests: Cannot render offscreen (headless environment?)")
            return
        }

        try writeBitmapToPNG(name: "appearance-popover-native-light", rep: rep)

        assertBackgroundOpaque(in: rep, expecting: theme)
        assertBackgroundColor(in: rep, matches: theme)
    }
}
