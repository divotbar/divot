import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

private extension NSColor {
    /// Resolve this (possibly dynamic) color to sRGB under `appearance`, so the
    /// contrast audit measures the exact value the bar draws.
    func rgbColor(for appearance: NSAppearance) -> SRGBColor {
        var result = SRGBColor(red: 0, green: 0, blue: 0)
        appearance.performAsCurrentDrawingAppearance {
            guard let converted = self.usingColorSpace(.sRGB) else { return }
            result = SRGBColor(red: Double(converted.redComponent),
                              green: Double(converted.greenComponent),
                              blue: Double(converted.blueComponent))
        }
        return result
    }
}

/// The keep-awake cup must clear the 3:1 non-text floor against every family's
/// bar background and against the composited chip fill. The default chip is an
/// opaque `selected`; the most transparent chip the bar renders is `selected` at
/// 80% transparency over the bar. The fixed green clears every bar and every
/// translucent chip, but not every opaque chip, so there the cup falls back to a
/// black/white outline that clears the floor instead.
@MainActor
@Test func keepAwakeIndicatorClearsTheNonTextFloorOnEveryFamilyBarAndChipInLightAndDark() {
    let floor = ContrastAudit.nonTextThreshold
    /// The chip opacities to audit: the default (opaque) chip and the most
    /// transparent chip the snapshots render (80% transparency).
    let chipOpacities = [0, translucentChipOpacity]
    var rows: [(String, String, String, Double, Double, Double)] = []

    for family in AppearanceConfiguration.Family.allCases {
        for dark in [false, true] {
            let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family,
                                                                 mode: dark ? .dark : .light),
                                         dark: dark)
            let green = BarItemView.color(for: .keepAwakeActive,
                                          appearance: appearance).rgbColor(for: appearance)
            let background = theme.background.rgbColor(for: appearance)
            let selected = theme.selected.rgbColor(for: appearance)
            let mode = dark ? "dark" : "light"

            let barRatio = ContrastAudit.ratio(green, background)
            #expect(barRatio >= floor, "\(family.rawValue) \(mode) bar: \(barRatio)")

            for opacity in chipOpacities {
                let chipFill = selected.blended(over: background,
                                                alpha: 1 - Double(opacity) / 100)
                let greenRatio = ContrastAudit.ratio(green, chipFill)
                let outline = KeepAwakeIndicatorPalette.outline(for: chipFill)
                let outlineRatio = ContrastAudit.ratio(outline, chipFill)
                // The drawn mark is the green where it clears the floor, else the
                // outline stroke drawn over it.
                let markRatio = greenRatio >= floor ? greenRatio : outlineRatio
                let chipLabel = opacity == 0 ? "opaque" : "translucent"
                #expect(markRatio >= floor,
                        "\(family.rawValue) \(mode) \(chipLabel) chip: green=\(greenRatio) outline=\(outlineRatio)")
                // Where the green cannot carry the chip, the fallback must.
                if greenRatio < floor {
                    #expect(outlineRatio >= floor,
                            "\(family.rawValue) \(mode) \(chipLabel): neither green (\(greenRatio)) nor outline (\(outlineRatio)) clears \(floor)")
                }
                rows.append((family.rawValue, mode, chipLabel, barRatio, greenRatio, outlineRatio))
            }
        }
    }

    print("\n=== Keep-awake cup contrast (vs bar and vs chip) ===")
    print(pad("Family", 14) + pad("Mode", 7) + pad("Chip", 13)
          + pad("Bar", 8) + pad("Green", 9) + pad("Outline", 9) + "Mark")
    print(String(repeating: "-", count: 66))
    for (family, mode, chip, bar, greenRatio, outlineRatio) in rows {
        let mark = greenRatio >= floor ? "green" : "outline"
        print(pad(family, 14) + pad(mode, 7) + pad(chip, 13)
              + pad(fmt(bar), 8) + pad(fmt(greenRatio), 9) + pad(fmt(outlineRatio), 9) + mark)
    }
}

/// The 80%-transparency chip the snapshot helper renders.
private let translucentChipOpacity = 80

private func pad(_ value: String, _ width: Int) -> String {
    value.count >= width ? value : value + String(repeating: " ", count: width - value.count)
}

private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }

/// The role must resolve to the audited palette, not to an unrelated system
/// color, so the audit above cannot silently stop covering the drawn value.
@MainActor
@Test func keepAwakeIndicatorRoleResolvesToTheAuditedPalette() {
    for dark in [false, true] {
        let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
        let resolved = BarItemView.color(for: .keepAwakeActive,
                                         appearance: appearance).rgbColor(for: appearance)
        let expected = try! #require(SRGBColor(hex: KeepAwakeIndicatorPalette.activeHex(dark: dark)))
        #expect(resolved == expected)
    }
}
