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
/// floor against every family's bar background in both light and dark modes.
/// Contrast is audited against the bar background only, not optional chip fills,
/// following the pattern of the charging green (#0084): chip backgrounds span a
/// wide luminance range that no single fixed colour can uniformly satisfy.
@MainActor
@Test func keepAwakeIndicatorClearsTheNonTextFloorOnEveryFamilyBarInLightAndDark() {
    for family in AppearanceConfiguration.Family.allCases {
        for dark in [false, true] {
            let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family,
                                                                mode: dark ? .dark : .light),
                                         dark: dark)
            let green = BarItemView.color(for: .keepAwakeActive,
                                          appearance: appearance).rgbColor(for: appearance)
            let background = theme.background.rgbColor(for: appearance)
            let ratio = ContrastAudit.ratio(green, background)
            #expect(ratio >= ContrastAudit.nonTextThreshold,
                    "\(family.rawValue) \(dark ? "dark" : "light") keep-awake green \(ratio) is below \(ContrastAudit.nonTextThreshold)")
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
