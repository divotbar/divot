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

/// The keep-awake indicator is new text/icon color, so the audit checks the
/// color the view actually resolves against the surface it draws on. Native is
/// the only shipped family today; the theme milestone (0011) must map this role
/// per family and extend the audit.
@MainActor
@Test func keepAwakeIndicatorMeetsContrastOnTheNativeBarInEveryVariant() {
    for dark in [false, true] {
        let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
        let background = NSColor.windowBackgroundColor.rgbColor(for: appearance)
        let indicator = BarItemView.color(for: .keepAwakeActive,
                                          appearance: appearance).rgbColor(for: appearance)
        let ratio = ContrastAudit.ratio(indicator, background)
        #expect(ratio >= ContrastAudit.textThreshold,
                "keep-awake indicator contrast \(ratio) is below \(ContrastAudit.textThreshold) in \(dark ? "dark" : "light")")
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
