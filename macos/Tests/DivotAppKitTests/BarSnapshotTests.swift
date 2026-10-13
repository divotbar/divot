import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Renders the menu bar offscreen to PNG for visual verification and pixel assertions.
///
/// Snapshots are written to a gitignored directory (DIVOT_SNAPSHOT_DIR or
/// macos/.build/snapshots/) for manual review. Tests gracefully skip when
/// offscreen rendering is unavailable (headless environments).
///
/// When snapshots render successfully, pixel assertions verify:
/// - Background color matches theme palette
/// - Right-edge inset of 17px is structurally defined in BarMetrics
/// - Text contrast meets WCAG AA when text is present
///
/// Known limitations (documented in docs/popover-snapshot-testing.md):
/// - No live provider data: battery/network/time widgets need WidgetPipeline emission
/// - Item spacing/gaps require multi-item layouts with injected test state
/// - Chip styling visual verification requires pixel-boundary analysis with known widget extents
@MainActor
@Suite("Bar snapshots")
struct BarSnapshotTests {

    private func snapshotDirectory() -> URL {
        if let env = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_DIR"] {
            let url = URL(fileURLWithPath: env)
            if !url.path.contains("snapshots") && !url.path.contains(".build") {
                preconditionFailure("DIVOT_SNAPSHOT_DIR must be under an ignored path (should contain 'snapshots' or '.build')")
            }
            return url
        }
        let macosDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildDir = macosDir.appendingPathComponent(".build").appendingPathComponent("snapshots")
        return buildDir
    }

    // MARK: - Pixel assertions

    private func assertBackgroundColor(in rep: NSBitmapImageRep, matches theme: BarTheme) {
        let expected = theme.background
        guard let sRGB = expected.usingColorSpace(.sRGB) else { return }

        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let centerY = height / 2
        let samples = [(width/4, centerY), (width/2, centerY)]

        var successCount = 0
        for (x, y) in samples {
            guard let pixel = SnapshotTestHelpers.pixelColor(in: rep, x: x, y: y) else { continue }

            let tolerance: CGFloat = 0.1
            let rMatch = abs(pixel.r - sRGB.redComponent) < tolerance
            let gMatch = abs(pixel.g - sRGB.greenComponent) < tolerance
            let bMatch = abs(pixel.b - sRGB.blueComponent) < tolerance

            if rMatch && gMatch && bMatch {
                successCount += 1
            }
        }

        #expect(successCount > 0, "No sampled pixels matched the background color")
    }

    private func assertRightEdgeInset(in rep: NSBitmapImageRep, theme: BarTheme) {
        #expect(BarMetrics.rightEdgeInset == 17, "BarMetrics.rightEdgeInset should be 17pt to reserve camera-indicator space")
    }

    private func assertTextContrast(in rep: NSBitmapImageRep, theme: BarTheme) {
        let bgColor = theme.background
        guard let bgSRGB = bgColor.usingColorSpace(.sRGB) else { return }

        let bgSRGBColor = SRGBColor(
            red: Double(bgSRGB.redComponent),
            green: Double(bgSRGB.greenComponent),
            blue: Double(bgSRGB.blueComponent)
        )

        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let tolerance: CGFloat = 0.15

        var foundTextPixel = false
        var textPixelsWithBadContrast = 0
        var textPixelsWithGoodContrast = 0

        for row in stride(from: height / 4, to: 3 * height / 4, by: max(1, height / 10)) {
            for col in stride(from: width / 8, to: 7 * width / 8, by: max(1, width / 15)) {
                guard let pixel = SnapshotTestHelpers.pixelColor(in: rep, x: col, y: row) else { continue }

                let isBackground = abs(pixel.r - bgSRGB.redComponent) < tolerance
                    && abs(pixel.g - bgSRGB.greenComponent) < tolerance
                    && abs(pixel.b - bgSRGB.blueComponent) < tolerance

                if !isBackground && pixel.a > 0.1 {
                    foundTextPixel = true
                    let textSRGBColor = SRGBColor(
                        red: Double(pixel.r),
                        green: Double(pixel.g),
                        blue: Double(pixel.b)
                    )

                    let contrast = ContrastAudit.ratio(textSRGBColor, bgSRGBColor)
                    if contrast >= ContrastAudit.textThreshold {
                        textPixelsWithGoodContrast += 1
                    } else {
                        textPixelsWithBadContrast += 1
                    }
                }
            }
        }

        if foundTextPixel && textPixelsWithBadContrast > 0 {
            let ratio = Double(textPixelsWithGoodContrast) / Double(textPixelsWithBadContrast + textPixelsWithGoodContrast)
            #expect(ratio >= 0.8, "Most text pixels should meet contrast >= \(ContrastAudit.textThreshold):1 (found \(ratio * 100)% with good contrast)")
        }
    }

    private func assertAllPixelProperties(rep: NSBitmapImageRep, theme: BarTheme) {
        assertBackgroundColor(in: rep, matches: theme)
        assertRightEdgeInset(in: rep, theme: theme)
        assertTextContrast(in: rep, theme: theme)
    }

    // MARK: - Bar view creation

    private func makeBarView(
        side: BarSide,
        items: [BarItemID],
        chipsEnabled: Bool,
        fontSize: CGFloat
    ) -> BarContentView {
        let metrics = fontSize != 14
            ? BarMetrics.scaled(textSize: fontSize)
            : BarMetrics.default

        return BarContentView(
            side: side,
            items: items,
            enablesChipStyle: chipsEnabled,
            chipOpacity: chipsEnabled ? 80 : 0,
            metrics: metrics
        )
    }

    private func testBar(
        name: String,
        side: BarSide,
        items: [BarItemID],
        appearance: AppearanceConfiguration,
        isDark: Bool,
        fontSize: CGFloat,
        chipsEnabled: Bool
    ) throws {
        let theme = BarTheme.resolve(appearance, dark: isDark)
        let metrics = fontSize != 14
            ? BarMetrics.scaled(textSize: fontSize)
            : BarMetrics.default

        let view = makeBarView(side: side, items: items, chipsEnabled: chipsEnabled, fontSize: fontSize)
        view.apply(theme: theme)

        let viewWidth: CGFloat = 800
        let viewHeight: CGFloat = metrics.height
        view.frame = NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight)

        guard let rep = SnapshotTestHelpers.renderView(view, size: CGSize(width: viewWidth, height: viewHeight)) else {
            print("BarSnapshotTests [\(name)]: Skipped — offscreen rendering unavailable (headless environment)")
            return
        }

        try SnapshotTestHelpers.writeBitmapToPNG(name: name, rep: rep, directory: snapshotDirectory())
        assertAllPixelProperties(rep: rep, theme: theme)
    }

    // MARK: - Tests

    @Test("Right bar — all themes × light/dark × default size × chips off")
    func rightBarDefaultSizeNoChips() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]
        let rightItems: [BarItemID] = [.clock]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "bar-right-\(familyName)-\(variantName)-default-chips-off"
                try testBar(name: name, side: .right, items: rightItems, appearance: appearance, isDark: isDark, fontSize: 14, chipsEnabled: false)
            }
        }
    }

    @Test("Right bar — all themes × light/dark × default size × chips on")
    func rightBarDefaultSizeWithChips() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]
        let rightItems: [BarItemID] = [.clock]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "bar-right-\(familyName)-\(variantName)-default-chips-on"
                try testBar(name: name, side: .right, items: rightItems, appearance: appearance, isDark: isDark, fontSize: 14, chipsEnabled: true)
            }
        }
    }

    @Test("Right bar — all themes × light/dark × larger text (16pt) × chips off")
    func rightBarLargerTextNoChips() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]
        let rightItems: [BarItemID] = [.clock]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "bar-right-\(familyName)-\(variantName)-large-chips-off"
                try testBar(name: name, side: .right, items: rightItems, appearance: appearance, isDark: isDark, fontSize: 16, chipsEnabled: false)
            }
        }
    }

    @Test("Right bar — all themes × light/dark × larger text (16pt) × chips on")
    func rightBarLargerTextWithChips() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]
        let rightItems: [BarItemID] = [.clock]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "bar-right-\(familyName)-\(variantName)-large-chips-on"
                try testBar(name: name, side: .right, items: rightItems, appearance: appearance, isDark: isDark, fontSize: 16, chipsEnabled: true)
            }
        }
    }

    @Test("Snapshot directory is under an ignored path (safety check)")
    func snapshotDirectoryIsIgnored() {
        let dir = snapshotDirectory()
        let path = dir.path
        #expect(path.contains(".build"), "Snapshot directory '\(path)' must be under .build/ (gitignored)")
        #expect(path.contains("snapshots"), "Snapshot directory must be under snapshots/ subdirectory")
    }
}
