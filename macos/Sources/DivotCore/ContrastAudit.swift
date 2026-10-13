import Foundation

// MARK: - Color math

/// A non-premultiplied sRGB color, so the contrast math is pure and testable
/// without a window server.
public struct SRGBColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parse a six-digit `#RRGGBB` color. Returns `nil` for anything else.
    public init?(hex: String) {
        guard hex.count == 7, hex.hasPrefix("#") else { return nil }
        let digits = hex.dropFirst()
        guard let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    /// WCAG 2.1 relative luminance.
    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// This colour composited over `other` at `alpha` (clamped to 0...1), in the
    /// same non-premultiplied sRGB space the theme fills use. A bar chip draws
    /// the `selected` token at a partial alpha over the background, so the audit
    /// can measure the exact composited fill the chip shows.
    public func blended(over other: SRGBColor, alpha: Double) -> SRGBColor {
        let a = min(max(alpha, 0), 1)
        return SRGBColor(red: red * a + other.red * (1 - a),
                         green: green * a + other.green * (1 - a),
                         blue: blue * a + other.blue * (1 - a))
    }
}

/// The WCAG 2.1 contrast helpers the audit uses.
public enum ContrastAudit {
    /// Contrast ratio between two opaque colors, 1.0...21.0.
    public static func ratio(_ a: SRGBColor, _ b: SRGBColor) -> Double {
        let first = a.relativeLuminance
        let second = b.relativeLuminance
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// WCAG AA body-text threshold (4.5:1).
    public static let textThreshold = 4.5
    /// WCAG non-text/UI-component threshold (3:1).
    public static let nonTextThreshold = 3.0
}

// MARK: - Keep-awake indicator palette

/// The keep-awake "on" indicator colors, one per appearance variant.
///
/// The cup must read as a distinct keep-awake mark on every family (Native,
/// Gruvbox, Ayu, Dracula, Tokyo Night, Alpine) in light and dark. It uses a
/// fixed green pair, never the theme accent: `activeLightHex` on a light bar and
/// `activeDarkHex` on a dark one, each clearing the 3:1 non-text floor against
/// every family's bar background.
///
/// The fixed green alone cannot clear 3:1 against a chip fill. The default chip
/// is fully opaque and reuses the family's `selected` colour, whose luminance
/// ranges from a near-white pale accent to a saturated blue, so the green either
/// disappears into a mid-tone chip or fails against a bright one. Where the
/// green falls short the cup is stroked with an outline in the higher-contrast
/// of pure black or pure white (`outline(for:)`), which clears the floor against
/// every composited chip. The outline is the only fallback: a flat stroke, never
/// a blur or drop shadow.
public enum KeepAwakeIndicatorPalette {
    /// The keep-awake green for light mode: works against light bars.
    public static let activeLightHex = "#0B6B3A"
    /// The keep-awake green for dark mode: works against dark bars.
    public static let activeDarkHex = "#7BD88F"

    /// The two fixed outline colours, one of which is the fallback stroke.
    public static let blackOutlineHex = "#000000"
    public static let whiteOutlineHex = "#FFFFFF"

    /// The active indicator hex for the given appearance variant.
    public static func activeHex(dark: Bool) -> String {
        dark ? activeDarkHex : activeLightHex
    }

    /// The outline colour that contrasts most with `backdrop` — the composited
    /// chip fill the cup sits on, or the bar background when chips are off. Pure
    /// black or pure white, so the stroke clears the floor wherever the green
    /// cannot.
    public static func outline(for backdrop: SRGBColor) -> SRGBColor {
        guard let black = SRGBColor(hex: blackOutlineHex),
              let white = SRGBColor(hex: whiteOutlineHex) else {
            return SRGBColor(red: 0, green: 0, blue: 0)
        }
        return ContrastAudit.ratio(black, backdrop) >= ContrastAudit.ratio(white, backdrop) ? black : white
    }
}

// MARK: - Charging indicator palette

/// The charging indicator's fixed green, independent of the theme accent (#0074).
///
/// Charging must read as an unmistakable green on every family, so this value is
/// never taken from the theme accent: a Dracula or Tokyo Night bar has a purple
/// or blue accent, which made the charging mark look like an arbitrary colour
/// (maintainer screenshot, 2026-10-13). It is one named constant for every
/// family and both appearances — a mid green that clears the 3:1 non-text floor
/// against every curated dark bar background *and* every light one. Apple's
/// bright system green fails a light bar and a light-green dark variant fails a
/// dark one, so no brighter system green can be the single value. Only the bolt
/// of the charging battery symbol is this green; the outline and fill keep the
/// normal label colour (#0084).
public enum ChargingIndicatorPalette {
    /// The SF Symbol drawn while charging: a battery with a bolt, whose palette
    /// layers (bolt, outline, fill) let the view colour the bolt alone.
    public static let symbolName = "battery.100.bolt"

    /// The one fixed charging green.
    public static let greenHex = "#248E3C"

    /// The green as a pure theme color, so the contrast audit and the bar share
    /// one value.
    public static let green: ThemeColor = {
        guard let color = ThemeColor(hex: greenHex) else {
            preconditionFailure("Invalid charging green literal: \(greenHex)")
        }
        return color
    }()
}
