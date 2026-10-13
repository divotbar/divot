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

/// The charging green is one fixed constant, not a theme accent, so it must
/// clear the 3:1 non-text floor against each family's bar in both appearances.
/// Only the bolt is green (#0084). The symbol knocks a halo out of the body
/// around the bolt, so the green is read against the bar/chip behind that halo,
/// not against the body colour; the body-vs-bar contrast is the label colour's
/// own audited contrast. Contrast is audited against the bar background only,
/// not the optional chip's selected fill, which spans luminance ranges that no
/// single green can satisfy uniformly.
@MainActor
@Test func chargingGreenClearsTheNonTextFloorOnEveryFamilyBarInLightAndDark() {
    for family in AppearanceConfiguration.Family.allCases {
        for dark in [false, true] {
            let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family,
                                                                mode: dark ? .dark : .light),
                                         dark: dark)
            let green = NSColor(ChargingIndicatorPalette.green).rgbColor(for: appearance)
            let background = theme.background.rgbColor(for: appearance)
            let ratio = ContrastAudit.ratio(green, background)
            #expect(ratio >= ContrastAudit.nonTextThreshold,
                    "\(family.rawValue) \(dark ? "dark" : "light") charging green \(ratio) is below \(ContrastAudit.nonTextThreshold)")
        }
    }
}
