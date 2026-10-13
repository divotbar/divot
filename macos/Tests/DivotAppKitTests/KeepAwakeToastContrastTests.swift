import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The keep-awake toast heading accent and subtext clear WCAG AA against the
/// solid popover background for every theme family in light and dark.
@MainActor
@Suite("Keep-awake toast contrast")
struct KeepAwakeToastContrastTests {
    private func srgb(_ color: NSColor, in appearance: NSAppearance) -> SRGBColor {
        var result = SRGBColor(red: 0, green: 0, blue: 0)
        appearance.performAsCurrentDrawingAppearance {
            guard let converted = color.usingColorSpace(.sRGB) else { return }
            result = SRGBColor(red: Double(converted.redComponent),
                               green: Double(converted.greenComponent),
                               blue: Double(converted.blueComponent))
        }
        return result
    }

    @Test func accentAndSubtextClearContrastAcrossEveryFamilyAndVariant() {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]

        for family in families {
            for dark in [false, true] {
                let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                let theme = BarTheme.resolve(AppearanceConfiguration(family: family, mode: dark ? .dark : .light),
                                             dark: dark)
                let background = srgb(theme.popoverPalette.background, in: appearance)

                for active in [true, false] {
                    let state = KeepAwakeToastState(isActive: active)
                    let view = KeepAwakeToastContentView(state: state, theme: theme)
                    view.frame = NSRect(x: 0, y: 0, width: 200, height: 60)

                    let accent = srgb(view.accentColor(), in: appearance)
                    let accentRatio = ContrastAudit.ratio(accent, background)
                    #expect(accentRatio >= ContrastAudit.textThreshold,
                            "toast accent contrast \(accentRatio) is below \(ContrastAudit.textThreshold) for \(family) \(active ? "on" : "off") in \(dark ? "dark" : "light")")

                    let secondary = srgb(theme.popoverPalette.secondary, in: appearance)
                    let secondaryRatio = ContrastAudit.ratio(secondary, background)
                    #expect(secondaryRatio >= ContrastAudit.textThreshold,
                            "toast subtext contrast \(secondaryRatio) is below \(ContrastAudit.textThreshold) for \(family) in \(dark ? "dark" : "light")")
                }
            }
        }
    }
}
