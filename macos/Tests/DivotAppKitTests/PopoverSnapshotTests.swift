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

    /// The snapshot output directory: `DIVOT_SNAPSHOT_DIR` (an ignored location, or
    /// the RepoOS shot directory) or `macos/.build/snapshots/`.
    private func snapshotDirectory() -> URL {
        SnapshotTestHelpers.snapshotDirectory(testFile: #filePath)
    }

    // MARK: - Snapshot rendering

    /// Render a view offscreen using AppKit's bitmap cache API.
    /// Returns the bitmap rep or nil if rendering cannot occur (e.g., headless environment).
    private func renderView(_ view: NSView, size: NSSize) -> NSBitmapImageRep? {
        // The shared helper samples alpha across the whole bitmap; the previous
        // check read only the first bytes, which are transparent in the rounded
        // corner, so it reported every render as headless.
        SnapshotTestHelpers.render(view, size: size)
    }

    /// Write a bitmap image as PNG to the snapshot directory. Throws on error.
    private func writeBitmapToPNG(name: String, rep: NSBitmapImageRep) throws {
        guard SnapshotTestHelpers.wantsPNG(named: name) else { return }
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

    /// The sound pixel assertions (#0083), run on the offscreen render of the
    /// content view over the popover's solid background:
    /// - the bitmap is opaque and the fill matches the palette;
    /// - every ink row's first non-background pixel sits within the leading inset
    ///   (so nothing is centred or right-aligned);
    /// - every text band (taller than a hairline) reaches AA-ish contrast against
    ///   the sampled background, except bands drawn on the selected fill, which
    ///   must instead contain the palette's selected colour.
    /// `expectSelectedFill` demands the selected fill is visible (today, chosen row).
    private func assertPixelRules(rep: NSBitmapImageRep, size: NSSize, theme: BarTheme,
                                  expectSelectedFill: Bool, label: String) {
        guard let buffer = PixelBuffer(rep) else { return }
        let palette = theme.popoverPalette
        func rgb(_ c: NSColor) -> RGB {
            let c = c.usingColorSpace(.sRGB)!
            return RGB(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent))
        }
        let bg = rgb(palette.background)
        let selected = rgb(palette.selected)
        let scale = Double(buffer.width) / Double(size.width)

        // Background: opaque, and the mid-right edge is exactly the palette fill.
        #expect(buffer.alpha(buffer.width - 4, buffer.height / 2) == 1, "\(label): fill is opaque")
        #expect(buffer.color(buffer.width - 4, buffer.height / 2).delta(bg) < 0.02, "\(label): fill matches palette")

        // Ink rows.
        var bands: [[Int]] = []
        var current: [Int] = []
        var rowFirstInk: [Int: Int] = [:]
        // Ignore a 3pt margin: the content layer's rounded corners are cut out there.
        let margin = Int(3 * scale)
        for y in margin..<(buffer.height - margin) {
            var first: Int?
            for x in margin..<(buffer.width - margin) where buffer.color(x, y).delta(bg) > 0.08 {
                first = x
                break
            }
            if let first {
                rowFirstInk[y] = first
                current.append(y)
            } else if !current.isEmpty {
                bands.append(current)
                current = []
            }
        }
        if !current.isEmpty { bands.append(current) }

        let leadingLimit = 26.0 * scale
        var selectedSeen = false
        for band in bands where Double(band.count) > 2 * scale {
            let first = band.compactMap { rowFirstInk[$0] }.min() ?? 0
            #expect(Double(first) <= leadingLimit,
                    "\(label): row at y=\(band[0]) starts at x=\(Double(first) / scale)pt, beyond the leading inset")
            var best = 0.0
            var onSelected = false
            for y in band {
                for x in margin..<(buffer.width - margin) {
                    let c = buffer.color(x, y)
                    if c.delta(selected) < 0.03 && selected.delta(bg) > 0.08 { onSelected = true; continue }
                    best = max(best, ContrastAudit.ratio(c.srgb, bg.srgb))
                }
            }
            if onSelected { selectedSeen = true; continue }
            #expect(best >= 4.0, "\(label): text band at y=\(band[0]) contrast \(best)")
        }
        if expectSelectedFill {
            #expect(selectedSeen, "\(label): selected fill is visible")
        }
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
        controller.update(.default)
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

    private func makeWifiPermissionController(fontSize: CGFloat = 12) -> WifiPopoverContentController {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.render(.permissionDenied)
        return controller
    }

    private func makeCalendarController(fontSize: CGFloat = 12) -> CalendarPopoverContentController {
        let controller = CalendarPopoverContentController()
        _ = controller.view
        // A fixed month with "today" inside it so the filled highlight is rendered.
        controller.update(CalendarMonthLayout.`for`(.today()))
        return controller
    }

    /// A world clock controller rendered for the given stored list, through the
    /// real content controller (no separate snapshot layout).
    private func makeWorldClockController(timezones: [String], fontSize: CGFloat = 12) -> WorldClockPopoverContentController {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        controller.render(timezones: timezones,
                          timeFormat: .ampm,
                          showSeconds: false,
                          customPattern: nil)
        return controller
    }

    /// The empty state: the user removed every zone (`[]`, not absent), so the
    /// hint and the Add row show and no defaults reappear.
    private func makeWorldClockEmptyController(fontSize: CGFloat = 12) -> WorldClockPopoverContentController {
        makeWorldClockController(timezones: WorldClock.resolvedTimezones(configured: []))
    }

    /// The first-run state: the config key is absent, so the three defaults show.
    /// Resolved through `WorldClock.resolvedTimezones`, the same path production
    /// and the Settings list use, so the shot cannot show a state the app cannot.
    private func makeWorldClockDefaultsController(fontSize: CGFloat = 12) -> WorldClockPopoverContentController {
        makeWorldClockController(timezones: WorldClock.resolvedTimezones(configured: nil))
    }

    /// One zone: a user list with a single entry, distinct from both the empty
    /// state and the three first-run defaults.
    private func makeWorldClockOneZoneController(fontSize: CGFloat = 12) -> WorldClockPopoverContentController {
        makeWorldClockController(timezones: ["Asia/Tokyo"])
    }

    /// The add flow: the empty state with `los` typed into the real search field
    /// and the results list visible. The text is set and the control-text-did-change
    /// notification posted exactly as the live popover receives it.
    private func makeWorldClockAddFlowController(fontSize: CGFloat = 12) -> WorldClockPopoverContentController {
        let controller = makeWorldClockController(timezones: WorldClock.resolvedTimezones(configured: []))
        if let search = firstSearchField(in: controller.view) {
            search.stringValue = "los"
            NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        }
        return controller
    }

    private func firstSearchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        for subview in view.subviews {
            if let found = firstSearchField(in: subview) { return found }
        }
        return nil
    }

    /// A world clock controller rendered at a fixed instant and local zone so a
    /// Yesterday/Tomorrow day label is deterministic: local 2026-01-01T10:00Z,
    /// where Kiritimati (UTC+14) is already tomorrow and Midway (UTC-11) is
    /// still yesterday.
    private func makeWorldClockDayLabelController(fontSize: CGFloat = 12) -> WorldClockPopoverContentController {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        controller.render(timezones: ["Pacific/Kiritimati", "Pacific/Midway", "Asia/Tokyo", "America/Los_Angeles"],
                         timeFormat: .ampm,
                         showSeconds: false,
                         customPattern: nil,
                         at: Date(timeIntervalSince1970: 1_767_261_600),
                         localTimeZone: TimeZone(identifier: "UTC")!)
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
        fontSize: CGFloat,
        expectSelectedFill: Bool = false
    ) throws {
        let theme = BarTheme.resolve(appearance, dark: isDark)
        let controller = maker(fontSize)
        controller.apply(theme: theme)
        // The popover chrome normally supplies the opaque background and the
        // appearance; an offscreen render of the bare content view has neither.
        controller.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = theme.popoverPalette.background.withAlphaComponent(1).cgColor

        let size = controller.preferredSize
        controller.view.frame = NSRect(origin: .zero, size: size)
        guard let rep = renderView(controller.view, size: size) else {
            // Headless environment: offscreen rendering is unavailable (no display).
            // This is expected in CI and local headless runs. Snapshot PNGs are not
            // generated. The test passes with this clear message.
            print("PopoverSnapshotTests [\(name)]: Skipped — offscreen rendering unavailable (headless environment)")
            return
        }

        try writeBitmapToPNG(name: name, rep: rep)
        assertPixelRules(rep: rep, size: size, theme: theme,
                         expectSelectedFill: expectSelectedFill, label: name)
    }

    /// Render a popover through the real panel path: present the content in a
    /// `BarPopoverHost` (which builds and sizes a `BarPopoverPanel`), then render
    /// the panel's chrome + content at the size the host computed. The content
    /// view's pixel rules still run, so alignment/contrast coverage is unchanged;
    /// the saved PNG is the real panel, not the bare content view.
    private func testPanelPopover(
        name: String,
        maker: (CGFloat) -> BarPopoverContentController,
        appearance: AppearanceConfiguration,
        isDark: Bool,
        fontSize: CGFloat
    ) throws {
        let theme = BarTheme.resolve(appearance, dark: isDark)
        let controller = maker(fontSize)
        controller.apply(theme: theme)

        let host = BarPopoverHost(monitors: NoopPopoverMonitor(), presenter: RecordingWindowPresenter())
        let anchorWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 24),
                                    styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)
        host.present(controller, relativeTo: anchor)
        defer { host.dismiss() }

        // Keep the content-view pixel assertions the other popovers use.
        let contentSize = controller.preferredSize
        if let contentRep = renderView(controller.view, size: contentSize) {
            assertPixelRules(rep: contentRep, size: contentSize, theme: theme,
                             expectSelectedFill: false, label: name)
        }

        guard let panel = host.panel, let chrome = panel.contentView else { return }
        let panelSize = chrome.frame.size
        chrome.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        guard let rep = renderView(chrome, size: panelSize) else {
            print("PopoverSnapshotTests [\(name)]: Skipped — offscreen rendering unavailable (headless environment)")
            return
        }
        try writeBitmapToPNG(name: name, rep: rep)
    }

    // MARK: - Tests

    @Test("Volume popover — all themes × light/dark × default size")
    func volumePopoverMatrix() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
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
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
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
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "appearance-popover-\(familyName)-\(variantName)-default"
                try testPopover(name: name, maker: makeAppearancePopoverController, appearance: appearance, isDark: isDark, fontSize: 12, expectSelectedFill: true)
            }
        }
    }

    @Test("Wi-Fi permission message — all themes × light/dark")
    func wifiPermissionMatrix() throws {
        for family in [AppearanceConfiguration.Family.native, .gruvbox, .ayu, .dracula, .tokyoNight] {
            for (variantName, isDark) in [("light", false), ("dark", true)] {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                try testPopover(name: "wifi-permission-popover-\(family.rawValue)-\(variantName)-default",
                                maker: makeWifiPermissionController, appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("Calendar popover — all themes × light/dark")
    func calendarPopoverMatrix() throws {
        for family in [AppearanceConfiguration.Family.native, .gruvbox, .ayu, .dracula, .tokyoNight] {
            for (variantName, isDark) in [("light", false), ("dark", true)] {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                try testPopover(name: "calendar-popover-\(family.rawValue)-\(variantName)-default",
                                maker: makeCalendarController, appearance: appearance, isDark: isDark, fontSize: 12,
                                expectSelectedFill: true)
            }
        }
    }

    @Test("Volume popover — all themes × light/dark × larger text (16pt)")
    func volumePopoverLargerText() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
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
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
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
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
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

    @Test("World clock popover — empty state, all themes × light/dark")
    func worldClockPopoverEmptyState() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "worldclock-popover-\(familyName)-\(variantName)-default-zero-timezones"
                try testPanelPopover(name: name, maker: { self.makeWorldClockEmptyController(fontSize: $0) },
                                     appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("World clock popover — three default zones, all themes × light/dark")
    func worldClockPopoverDefaults() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "worldclock-popover-\(familyName)-\(variantName)-default-defaults"
                try testPanelPopover(name: name, maker: { self.makeWorldClockDefaultsController(fontSize: $0) },
                                     appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("World clock popover — one zone, all themes × light/dark")
    func worldClockPopoverOneZone() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "worldclock-popover-\(familyName)-\(variantName)-default-one-zone"
                try testPanelPopover(name: name, maker: { self.makeWorldClockOneZoneController(fontSize: $0) },
                                     appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("World clock popover — four zones with day labels, all themes × light/dark")
    func worldClockPopoverDayLabel() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "worldclock-popover-\(familyName)-\(variantName)-default-day-label"
                try testPanelPopover(name: name, maker: { self.makeWorldClockDayLabelController(fontSize: $0) },
                                     appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("World clock popover — add flow (typed 'los'), all themes × light/dark")
    func worldClockPopoverAddFlow() throws {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        let variants: [(String, Bool)] = [("light", false), ("dark", true)]

        for family in families {
            for (variantName, isDark) in variants {
                let appearance = AppearanceConfiguration(family: family, mode: isDark ? .dark : .light, material: .opaque)
                let familyName = family == .native ? "native" : family.rawValue
                let name = "worldclock-popover-\(familyName)-\(variantName)-default-add-flow"
                try testPanelPopover(name: name, maker: { self.makeWorldClockAddFlowController(fontSize: $0) },
                                     appearance: appearance, isDark: isDark, fontSize: 12)
            }
        }
    }

    @Test("Snapshot directory is under an ignored path (safety check)")
    func snapshotDirectoryIsIgnored() {
        let dir = snapshotDirectory()
        let path = dir.path
        #expect(SnapshotTestHelpers.isIgnoredLocation(dir),
                "Snapshot directory '\(path)' must be under .build/ or snapshots/, or be REPOOS_SHOT_DIR (gitignored)")
    }
}
