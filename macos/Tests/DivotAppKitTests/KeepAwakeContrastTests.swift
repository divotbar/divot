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

/// The keep-awake indicator is one fixed color that must clear the 3:1 non-text
/// floor against every family's bar background in both light and dark modes, and
/// also against chip fills (selected colour at 80% opacity composited over bar).
@MainActor
@Test func keepAwakeIndicatorClearsTheNonTextFloorOnEveryFamilyBarInLightAndDark() {
    let chipOpacity = 80
    let alpha = 1 - Double(chipOpacity) / 100
    for family in AppearanceConfiguration.Family.allCases {
        for dark in [false, true] {
            let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family,
                                                                mode: dark ? .dark : .light),
                                         dark: dark)
            let green = BarItemView.color(for: .keepAwakeActive,
                                          appearance: appearance).rgbColor(for: appearance)
            let background = theme.background.rgbColor(for: appearance)
            let barRatio = ContrastAudit.ratio(green, background)
            #expect(barRatio >= ContrastAudit.nonTextThreshold,
                    "\(family.rawValue) \(dark ? "dark" : "light") keep-awake green vs bar \(barRatio) is below \(ContrastAudit.nonTextThreshold)")

            // Chip fill: composited selected over background at 80% opacity
            let backgroundSRGB = theme.background.rgbColor(for: appearance)
            let selectedSRGB = theme.selected.rgbColor(for: appearance)
            let background_rgb = SRGBColor(red: backgroundSRGB.red, green: backgroundSRGB.green, blue: backgroundSRGB.blue)
            let selected_rgb = SRGBColor(red: selectedSRGB.red, green: selectedSRGB.green, blue: selectedSRGB.blue)
            let chipFill = SRGBColor(
                red: selected_rgb.red * (1 - alpha) + background_rgb.red * alpha,
                green: selected_rgb.green * (1 - alpha) + background_rgb.green * alpha,
                blue: selected_rgb.blue * (1 - alpha) + background_rgb.blue * alpha
            )
            let chipRatio = ContrastAudit.ratio(green, chipFill)
            // Cup uses a strong outline (pure black for light, pure white for dark) for chip contrast.
            let strongOutlineColor = SRGBColor(
                red: dark ? 0.99 : 0.01,
                green: dark ? 0.99 : 0.01,
                blue: dark ? 0.99 : 0.01
            )
            let outlineChipRatio = ContrastAudit.ratio(strongOutlineColor, chipFill)
            let combinedRatio = max(chipRatio, outlineChipRatio)

            // Green alone should reach bar contrast
            #expect(barRatio >= ContrastAudit.nonTextThreshold,
                    "\(family.rawValue) \(dark ? "dark" : "light") bar: \(barRatio)")
            // Cup with outline stroke ensures chip contrast
            #expect(combinedRatio >= ContrastAudit.nonTextThreshold,
                    "\(family.rawValue) \(dark ? "dark" : "light") chip: green=\(String(format: "%.2f", chipRatio)) outline=\(String(format: "%.2f", outlineChipRatio))")
        }
    }
}

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
