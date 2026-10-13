import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The world clock popover's own text roles (header, local time, each zone row,
/// the add row) clear WCAG AA against its solid popover background for every
/// theme family — including Alpine — in light and dark. The row text is the
/// secondary role at 11 pt, so it is checked at the text floor, not the
/// non-text floor.
@MainActor
@Suite("World clock popover contrast")
struct WorldClockPopoverContrastTests {
    /// Resolve a (possibly dynamic) colour to sRGB under `appearance`, so the
    /// native system roles are measured as they are actually drawn.
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

    private func makeController() -> WorldClockPopoverContentController {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        // A fixed instant with both a Yesterday and a Tomorrow row, so the day
        // labels are exercised in the contrast check too.
        controller.render(timezones: ["Pacific/Kiritimati", "Pacific/Midway", "Asia/Tokyo", "America/Los_Angeles"],
                          timeFormat: .ampm,
                          showSeconds: false,
                          customPattern: nil,
                          at: Date(timeIntervalSince1970: 1_767_261_600),
                          localTimeZone: TimeZone(identifier: "UTC")!)
        return controller
    }

    @Test func textRolesClearContrastAcrossEveryFamilyAndVariant() {
        let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]

        for family in families {
            for dark in [false, true] {
                let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                let theme = BarTheme.resolve(AppearanceConfiguration(family: family, mode: dark ? .dark : .light),
                                             dark: dark)

                let controller = makeController()
                controller.apply(theme: theme)

                let background = srgb(theme.popoverPalette.background, in: appearance)
                var fields = 0
                func walk(_ view: NSView) {
                    if let field = view as? NSTextField {
                        fields += 1
                        let text = srgb(field.textColor ?? .labelColor, in: appearance)
                        let ratio = ContrastAudit.ratio(text, background)
                        #expect(ratio >= ContrastAudit.textThreshold,
                                "world clock text contrast \(ratio) is below \(ContrastAudit.textThreshold) for \(family) in \(dark ? "dark" : "light")")
                    }
                    view.subviews.forEach(walk)
                }
                walk(controller.view)

                #expect(fields > 0, "the world clock popover should have text fields for \(family)")
            }
        }
    }
}
