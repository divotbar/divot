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
/// The whole-icon tint is the chosen approach (see the task): a small bolt over
/// the battery outline is not reliably legible, so the whole symbol carries the
/// green (#0074). Contrast is audited against the bar background only, not the
/// optional chip's selected fill, which spans luminance ranges that no single
/// green can satisfy uniformly (site/guide/widgets.md documents the whole-symbol
/// tint as the mitigation for visibility on chips).
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

/// The drawn green is the fixed palette value for every family — never the
/// family accent, even when that accent is not green (the Dracula purple that
/// started this bug) — and the whole battery symbol carries it while charging.
@MainActor
@Test func chargingTintsTheWholeSymbolWithTheFixedGreenOnEveryFamily() {
    let expected = NSColor(ChargingIndicatorPalette.green)
    for family in AppearanceConfiguration.Family.allCases {
        for dark in [false, true] {
            // A deliberately non-green accent must never leak into the mark.
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family,
                                                                mode: dark ? .dark : .light,
                                                                accent: "#BD93F9"),
                                         dark: dark)
            #expect(!theme.accent.isEqual(expected),
                    "\(family.rawValue): the test accent must differ from the charging green")

            let charging = BarItemView()
            charging.apply(theme: theme)
            charging.update(batteryPresentation(charging: true), action: .none)
            #expect(charging.iconTintColor.isEqual(expected),
                    "\(family.rawValue) \(dark ? "dark" : "light") charging icon tint is not the fixed green")
            #expect(charging.badgeTintColor?.isEqual(expected) == true,
                    "\(family.rawValue) \(dark ? "dark" : "light") charging bolt tint is not the fixed green")

            let plain = BarItemView()
            plain.apply(theme: theme)
            plain.update(batteryPresentation(charging: false), action: .none)
            #expect(plain.badgeTintColor == nil,
                    "\(family.rawValue) \(dark ? "dark" : "light") not charging must draw no bolt")
            #expect(!plain.iconTintColor.isEqual(expected),
                    "\(family.rawValue) \(dark ? "dark" : "light") not charging must not be green")
        }
    }
}

@MainActor
private func batteryPresentation(charging: Bool) -> WidgetPresentation {
    WidgetPresenter.present(
        id: .battery,
        state: WidgetState(id: .battery, revision: 1,
                           content: .battery(BatterySnapshot(presence: .internalBattery,
                                                             percentage: 80,
                                                             isCharging: charging))))
}
