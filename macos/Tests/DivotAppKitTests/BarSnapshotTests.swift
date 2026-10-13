import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Renders the right-hand bar group (battery, clock, network, volume) offscreen
/// for every theme family in light and dark, at the default and one larger text
/// size, and asserts on the pixels. PNGs go to the gitignored
/// `macos/.build/snapshots/` (or `DIVOT_SNAPSHOT_DIR`); nothing is compared with
/// a stored golden, every expected value comes from `BarMetrics`, the resolved
/// `BarTheme` or `ChargingIndicatorPalette`.
///
/// Per configuration four renders are made:
/// - chips off, battery charging: slot layout, gaps, right inset, contrast, green
/// - chips on at 80% transparency: chip fill is the alpha-blended chip colour
/// - chips on, fully opaque: chip edges give a pixel-measured order, gap and inset
/// - chips off, not charging: no charging green anywhere
@MainActor
@Suite("Bar snapshots")
struct BarSnapshotTests {

    static let items: [BarItemID] = [.battery, .clock, .network, .volume]
    static let barWidth: CGFloat = 420
    static let translucentChipOpacity = 80

    struct Config: Sendable, CustomStringConvertible {
        let family: AppearanceConfiguration.Family
        let dark: Bool
        let textSize: CGFloat

        var description: String { name }
        var name: String {
            "\(family.rawValue)-\(dark ? "dark" : "light")-\(textSize == 14 ? "default" : "large")"
        }
    }

    nonisolated static let configs: [Config] = {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
        return families.flatMap { family in
            [false, true].flatMap { dark in
                [CGFloat(14), CGFloat(16)].map { Config(family: family, dark: dark, textSize: $0) }
            }
        }
    }()

    enum Chips {
        case off
        case translucent
        case solid
    }

    /// One rendered bar plus the layout facts the assertions compare it to.
    struct Rendered {
        let pixels: PixelBuffer
        let metrics: BarMetrics
        /// Item frames in points, left to right, in `items` order.
        let frames: [CGRect]
        let scale: Double
        let background: RGB
        let selected: RGB
        /// The item label colour, which the charging battery body must equal.
        let foreground: RGB

        var centerRow: Int { pixels.height / 2 }
        func column(_ points: CGFloat) -> Int { Int((Double(points) * scale).rounded()) }
        func isBackground(_ x: Int, _ y: Int, tolerance: Double = 0.02) -> Bool {
            pixels.color(x, y).delta(background) < tolerance
        }
    }

    // MARK: Rendering

    private func snapshotDirectory() -> URL {
        SnapshotTestHelpers.snapshotDirectory(testFile: #filePath)
    }

    private func render(_ config: Config, chips: Chips, charging: Bool, label: String) throws -> Rendered {
        let appearance = AppearanceConfiguration(family: config.family,
                                                 mode: config.dark ? .dark : .light,
                                                 material: .opaque)
        let theme = BarTheme.resolve(appearance, dark: config.dark,
                                     increasedContrast: false, reduceTransparency: false)
        let metrics = BarMetrics.scaled(textSize: config.textSize)
        let opacity: Int
        switch chips {
        case .off, .solid: opacity = 0
        case .translucent: opacity = Self.translucentChipOpacity
        }

        let view = BarContentView(side: .right, items: Self.items,
                                  enablesChipStyle: chips != .off,
                                  chipOpacity: opacity,
                                  metrics: metrics)
        let nsAppearance = try #require(NSAppearance(named: config.dark ? .darkAqua : .aqua))
        view.appearance = nsAppearance
        view.apply(theme: theme)
        view.applyInitialState()
        view.apply([
            .update(WidgetState(id: .battery, revision: 1,
                                content: .battery(BatterySnapshot(presence: .internalBattery,
                                                                  percentage: 80,
                                                                  isCharging: charging,
                                                                  isPluggedIn: charging)))),
            .update(WidgetState(id: .clock, revision: 1,
                                content: .clock(ClockSnapshot(date: Date(timeIntervalSince1970: 1_800_000_000))))),
            .update(WidgetState(id: .network, revision: 1,
                                content: .network(NetworkSnapshot(isConnected: true, kind: .wifi)))),
            .update(WidgetState(id: .volume, revision: 1,
                                content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: false))))
        ])
        let size = CGSize(width: Self.barWidth, height: metrics.height)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        let rep = try #require(SnapshotTestHelpers.render(view, size: size),
                               "Offscreen rendering produced no pixels for \(label)")
        let name = "bar-right-\(config.name)-\(label)"
        try SnapshotTestHelpers.writePNG(name: name, rep: rep, directory: snapshotDirectory())
        let pixels = try #require(PixelBuffer(rep))

        let itemViews = view.subviews.compactMap { $0 as? BarItemView }
        try #require(itemViews.count == Self.items.count)
        return Rendered(pixels: pixels,
                        metrics: metrics,
                        frames: itemViews.map(\.frame),
                        scale: Double(pixels.width) / Double(size.width),
                        background: SnapshotTestHelpers.rgb(theme.layerBackground, in: nsAppearance),
                        selected: SnapshotTestHelpers.rgb(theme.selected, in: nsAppearance),
                        foreground: SnapshotTestHelpers.rgb(theme.foreground, in: nsAppearance))
    }

    // MARK: Assertions

    /// Item order and gaps from the laid-out slots, against `BarMetrics`.
    private func assertSlotLayout(_ r: Rendered) {
        for (left, right) in zip(r.frames, r.frames.dropFirst()) {
            #expect(left.minX < right.minX, "Items are out of order")
            #expect(abs((right.minX - left.maxX) - r.metrics.rightItemSpacing) < 0.01,
                    "Gap between items is \(right.minX - left.maxX), expected \(r.metrics.rightItemSpacing)")
        }
        let last = r.frames.last!
        #expect(abs((Self.barWidth - last.maxX) - BarMetrics.rightEdgeInset) < 0.01,
                "Rightmost item ends \(Self.barWidth - last.maxX)pt from the right edge, expected \(BarMetrics.rightEdgeInset)")
        #expect(r.frames.allSatisfy { $0.width > 0 }, "An item collapsed to zero width")
    }

    /// With chips off the drawn ink must sit inside the slots: every item draws
    /// something, and the gaps, the leading margin and the right inset are pure
    /// bar background.
    private func assertInkMatchesSlots(_ r: Rendered) {
        let height = r.pixels.height
        func columnsAreBackground(_ range: Range<Int>) -> Bool {
            for x in range where x >= 0 && x < r.pixels.width {
                for y in 0..<height where !r.isBackground(x, y) { return false }
            }
            return true
        }
        for (index, frame) in r.frames.enumerated() {
            var inked = false
            scan: for x in r.column(frame.minX)..<r.column(frame.maxX) {
                for y in 0..<height where !r.isBackground(x, y, tolerance: 0.1) {
                    inked = true
                    break scan
                }
            }
            #expect(inked, "Item \(index) (\(Self.items[index].rawValue)) drew nothing in its slot")
        }
        for (left, right) in zip(r.frames, r.frames.dropFirst()) {
            #expect(columnsAreBackground((r.column(left.maxX) + 1)..<(r.column(right.minX) - 1)),
                    "Ink between \(left.maxX)pt and \(right.minX)pt, inside the item gap")
        }
        #expect(columnsAreBackground(0..<(r.column(r.frames[0].minX) - 1)), "Ink left of the first item")
        let insetStart = r.column(Self.barWidth - BarMetrics.rightEdgeInset)
        #expect(columnsAreBackground((insetStart + 1)..<r.pixels.width), "Ink inside the 17pt right inset")

        // The rightmost drawn column sits against the inset line, not far short of it.
        var rightmostInk = -1
        for x in stride(from: insetStart, through: 0, by: -1) {
            if (0..<height).contains(where: { !r.isBackground(x, $0, tolerance: 0.1) }) {
                rightmostInk = x
                break
            }
        }
        let shortfall = Double(insetStart - rightmostInk) / r.scale
        #expect(rightmostInk >= 0 && shortfall <= 4,
                "Rightmost ink is \(shortfall)pt short of the \(BarMetrics.rightEdgeInset)pt inset line")
    }

    /// Chip fill: off draws none, translucent draws the alpha-blended chip colour,
    /// both probed one point inside each slot's left edge (inside the chip padding,
    /// clear of any glyph).
    private func assertChipFill(_ r: Rendered, chips: Chips) {
        let alpha = 1 - Double(Self.translucentChipOpacity) / 100
        let expected = r.selected.blended(over: r.background, alpha: alpha)
        if chips == .translucent {
            #expect(expected.delta(r.background) > 0.03,
                    "Chip colour is indistinguishable from the bar background; cannot prove opacity")
        }
        for (index, frame) in r.frames.enumerated() {
            let probe = r.pixels.color(r.column(frame.minX + 1), r.centerRow)
            switch chips {
            case .off:
                #expect(probe.delta(r.background) < 0.02, "Chips off but item \(index) has a chip fill")
            case .translucent:
                #expect(probe.delta(expected) < 0.025,
                        "Item \(index) chip is \(probe), expected \(expected) at \(Self.translucentChipOpacity)% transparency")
            case .solid:
                #expect(probe.delta(r.selected) < 0.025, "Item \(index) solid chip is \(probe), expected \(r.selected)")
            }
        }
    }

    /// Fully opaque chips make each slot an edge-to-edge block of the chip colour,
    /// so order, gap widths and the right inset can be measured from pixels alone.
    private func assertMeasuredChipRuns(_ r: Rendered) {
        #expect(r.selected.delta(r.background) > 0.05, "Chip colour is indistinguishable from the bar background")
        var runs: [Range<Int>] = []
        var start: Int?
        for x in 0..<r.pixels.width {
            let inChip = !r.isBackground(x, r.centerRow, tolerance: 0.03)
            if inChip, start == nil { start = x }
            if !inChip, let begin = start { runs.append(begin..<x); start = nil }
        }
        if let begin = start { runs.append(begin..<r.pixels.width) }

        #expect(runs.count == Self.items.count, "Measured \(runs.count) chips, expected \(Self.items.count)")
        guard runs.count == Self.items.count else { return }
        let tolerance = Int(ceil(r.scale)) + 1
        for (index, run) in runs.enumerated() {
            #expect(abs(run.lowerBound - r.column(r.frames[index].minX)) <= tolerance,
                    "Chip \(index) starts at column \(run.lowerBound), expected \(r.column(r.frames[index].minX))")
        }
        for (left, right) in zip(runs, runs.dropFirst()) {
            let gapPoints = Double(right.lowerBound - left.upperBound) / r.scale
            #expect(abs(gapPoints - Double(r.metrics.rightItemSpacing)) <= 1.0 / r.scale * 2,
                    "Measured chip gap \(gapPoints)pt, expected \(r.metrics.rightItemSpacing)pt")
        }
        let insetPoints = Double(r.pixels.width - runs.last!.upperBound) / r.scale
        #expect(abs(insetPoints - Double(BarMetrics.rightEdgeInset)) <= 1.0 / r.scale * 2,
                "Measured right inset \(insetPoints)pt, expected \(BarMetrics.rightEdgeInset)pt")
    }

    /// The strongest pixel in the clock label must clear the text threshold against
    /// whatever sits behind it.
    private func assertClockContrast(_ r: Rendered, behind: RGB) {
        let frame = r.frames[1]
        var best = 0.0
        for x in r.column(frame.minX)..<r.column(frame.maxX) {
            for y in 0..<r.pixels.height {
                best = max(best, ContrastAudit.ratio(r.pixels.color(x, y).srgb, behind.srgb))
            }
        }
        #expect(best >= ContrastAudit.textThreshold,
                "Clock text peaks at \(best):1, below \(ContrastAudit.textThreshold):1")
    }

    private func chargingGreenColumns(_ r: Rendered) -> [Int] {
        let green = RGB(r: Double(ChargingIndicatorPalette.green.red),
                        g: Double(ChargingIndicatorPalette.green.green),
                        b: Double(ChargingIndicatorPalette.green.blue))
        var columns: [Int] = []
        for x in 0..<r.pixels.width {
            for y in 0..<r.pixels.height where r.pixels.color(x, y).delta(green) < 0.05 {
                columns.append(x)
            }
        }
        return columns
    }

    // MARK: Tests

    @Test("Right bar layout, inset, chip fill, contrast and charging green", arguments: configs)
    func rightBar(config: Config) throws {
        let off = try render(config, chips: .off, charging: true, label: "chips-off")
        assertSlotLayout(off)
        assertInkMatchesSlots(off)
        assertChipFill(off, chips: .off)
        assertClockContrast(off, behind: off.background)

        // Only the bolt is green (#0084): green pixels exist, sit well inside the
        // battery slot, and span far less than the battery body, while the body
        // itself is drawn in the normal label colour.
        let green = chargingGreenColumns(off)
        #expect(green.count >= 10, "Charging battery drew only \(green.count) pixels of the fixed green")
        let battery = off.frames[0]
        let greenSpan = (green.max() ?? 0) - (green.min() ?? 0)
        #expect(greenSpan < off.column(off.metrics.iconSize),
                "Charging green spans \(greenSpan)px, as wide as or wider than the icon (\(off.column(off.metrics.iconSize))px): the whole battery is tinted, not just the bolt")
        #expect(green.allSatisfy { $0 >= off.column(battery.minX) - 1 && $0 <= off.column(battery.maxX) + 1 },
                "Charging green appears outside the battery slot")
        var bodyPixels = 0
        for x in off.column(battery.minX)..<off.column(battery.maxX) {
            for y in 0..<off.pixels.height where off.pixels.color(x, y).delta(off.foreground) < 0.05 { bodyPixels += 1 }
        }
        #expect(bodyPixels >= 40, "Charging battery body drew only \(bodyPixels) pixels of the normal label colour")

        let translucent = try render(config, chips: .translucent, charging: true, label: "chips-on")
        assertSlotLayout(translucent)
        assertChipFill(translucent, chips: .translucent)
        let alpha = 1 - Double(Self.translucentChipOpacity) / 100
        assertClockContrast(translucent,
                            behind: translucent.selected.blended(over: translucent.background, alpha: alpha))

        let solid = try render(config, chips: .solid, charging: true, label: "chips-solid")
        assertSlotLayout(solid)
        assertChipFill(solid, chips: .solid)
        assertMeasuredChipRuns(solid)

        let idle = try render(config, chips: .off, charging: false, label: "not-charging")
        #expect(chargingGreenColumns(idle).isEmpty, "Charging green drawn while not charging")
        var batteryInked = false
        for x in idle.column(idle.frames[0].minX)..<idle.column(idle.frames[0].maxX) {
            for y in 0..<idle.pixels.height where !idle.isBackground(x, y, tolerance: 0.1) { batteryInked = true }
        }
        #expect(batteryInked, "Not-charging render drew no battery, so the absence check proves nothing")
    }

    @Test("Keep-awake cup visibility on every family", arguments: configs)
    func keepAwakeCup(config: Config) throws {
        // Render with keep-awake on, not charging, to show the cup without the bolt.
        let appearance = AppearanceConfiguration(family: config.family,
                                                 mode: config.dark ? .dark : .light,
                                                 material: .opaque)
        let theme = BarTheme.resolve(appearance, dark: config.dark,
                                     increasedContrast: false, reduceTransparency: false)
        let metrics = BarMetrics.scaled(textSize: config.textSize)

        let offChips = try renderWithKeepAwake(config, chips: .off, theme: theme, metrics: metrics, label: "chips-off")
        assertSlotLayout(offChips)
        assertInkMatchesSlots(offChips)
        assertChipFill(offChips, chips: .off)
        assertClockContrast(offChips, behind: offChips.background)

        // The cup is drawn beside the battery percentage: green pixels must exist,
        // sit well inside the battery slot, and the cup is clearly visible.
        let cupGreenColumns = keepAwakeCupColumns(offChips, dark: config.dark)
        #expect(cupGreenColumns.count >= 5, "Keep-awake cup drew only \(cupGreenColumns.count) pixels of the fixed green")
        let battery = offChips.frames[0]
        #expect(cupGreenColumns.allSatisfy { $0 >= offChips.column(battery.minX) - 1 && $0 <= offChips.column(battery.maxX) + 1 },
                "Keep-awake cup green appears outside the battery slot")

        let onChips = try renderWithKeepAwake(config, chips: .translucent, theme: theme, metrics: metrics, label: "chips-on")
        assertSlotLayout(onChips)
        assertChipFill(onChips, chips: .translucent)
        let alpha = 1 - Double(Self.translucentChipOpacity) / 100
        assertClockContrast(onChips,
                            behind: onChips.selected.blended(over: onChips.background, alpha: alpha))

        // Cup must still be visible on chips background.
        let cupGreenOnChips = keepAwakeCupColumns(onChips, dark: config.dark)
        #expect(cupGreenOnChips.count >= 5, "Keep-awake cup on chips drew only \(cupGreenOnChips.count) pixels of the fixed green")
    }

    private func keepAwakeCupColumns(_ r: Rendered, dark: Bool) -> [Int] {
        // The cup uses the keep-awake palette green. Extract the hex and convert to RGB.
        let cupHex = KeepAwakeIndicatorPalette.activeHex(dark: dark)
        guard let cupColor = SRGBColor(hex: cupHex) else { return [] }
        let cupRGB = RGB(r: cupColor.red, g: cupColor.green, b: cupColor.blue)

        var columns: [Int] = []
        for x in 0..<r.pixels.width {
            for y in 0..<r.pixels.height where r.pixels.color(x, y).delta(cupRGB) < 0.05 {
                columns.append(x)
            }
        }
        return columns
    }

    private func renderWithKeepAwake(_ config: Config, chips: Chips, theme: BarTheme, metrics: BarMetrics, label: String) throws -> Rendered {
        let opacity: Int
        switch chips {
        case .off, .solid: opacity = 0
        case .translucent: opacity = Self.translucentChipOpacity
        }

        let view = BarContentView(side: .right, items: Self.items,
                                  enablesChipStyle: chips != .off,
                                  chipOpacity: opacity,
                                  metrics: metrics)
        let nsAppearance = try #require(NSAppearance(named: config.dark ? .darkAqua : .aqua))
        view.appearance = nsAppearance
        view.apply(theme: theme)
        view.applyInitialState()
        view.apply([
            .update(WidgetState(id: .battery, revision: 1,
                                content: .battery(BatterySnapshot(presence: .internalBattery,
                                                                  percentage: 80,
                                                                  isCharging: false,
                                                                  isPluggedIn: false,
                                                                  isKeepingAwake: true)))),
            .update(WidgetState(id: .clock, revision: 1,
                                content: .clock(ClockSnapshot(date: Date(timeIntervalSince1970: 1_800_000_000))))),
            .update(WidgetState(id: .network, revision: 1,
                                content: .network(NetworkSnapshot(isConnected: true, kind: .wifi)))),
            .update(WidgetState(id: .volume, revision: 1,
                                content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: false))))
        ])
        let size = CGSize(width: Self.barWidth, height: metrics.height)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        let rep = try #require(SnapshotTestHelpers.render(view, size: size),
                               "Offscreen rendering produced no pixels for keep-awake-\(label)")
        let name = "keep-awake-\(config.name)-\(label)"
        try SnapshotTestHelpers.writePNG(name: name, rep: rep, directory: snapshotDirectory())
        let pixels = try #require(PixelBuffer(rep))

        let itemViews = view.subviews.compactMap { $0 as? BarItemView }
        try #require(itemViews.count == Self.items.count)
        return Rendered(pixels: pixels,
                        metrics: metrics,
                        frames: itemViews.map(\.frame),
                        scale: Double(pixels.width) / Double(size.width),
                        background: SnapshotTestHelpers.rgb(theme.layerBackground, in: nsAppearance),
                        selected: SnapshotTestHelpers.rgb(theme.selected, in: nsAppearance),
                        foreground: SnapshotTestHelpers.rgb(theme.foreground, in: nsAppearance))
    }

    @Test("Snapshot directory is under an ignored path")
    func snapshotDirectoryIsIgnored() {
        let path = snapshotDirectory().path
        #expect(SnapshotTestHelpers.isIgnoredLocation(snapshotDirectory()),
                "Snapshot directory '\(path)' must be under .build/ or snapshots/, or be REPOOS_SHOT_DIR (gitignored)")
    }
}
