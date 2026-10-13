import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

private extension NSColor {
    /// Resolve this (possibly dynamic) color to sRGB under `appearance`.
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

/// Calendar popover today cell uses selected background with selectedForeground text.
/// The text contrast is checked against the button's selected background, not the popover background.
@MainActor
@Suite("Calendar popover contrast")
struct CalendarPopoverContrastTests {
    @Test func todayCellMeetsContrastAcrossAllThemesAndVariants() {
        let themes: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]

        for family in themes {
            for dark in [false, true] {
                let appearance = try! #require(NSAppearance(named: dark ? .darkAqua : .aqua))
                let theme = BarTheme.resolve(AppearanceConfiguration(family: family, mode: dark ? .dark : .light),
                                           dark: dark)

                // For native, use system semantic colors; for families, use resolved colors
                let selectedBg = theme.selected.rgbColor(for: appearance)
                let selectedText = theme.selectedForeground.rgbColor(for: appearance)
                let contrastRatio = ContrastAudit.ratio(selectedText, selectedBg)

                // Small UI components (non-text) use the 3:1 threshold per WCAG 2.1.
                #expect(contrastRatio >= ContrastAudit.nonTextThreshold,
                        "today cell contrast \(contrastRatio) is below \(ContrastAudit.nonTextThreshold) for \(family) in \(dark ? "dark" : "light")")
            }
        }
    }
}
