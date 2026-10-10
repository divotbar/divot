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
/// These are the new text/icon colors the contrast audit covers. They are a
/// semantic role rather than a hard-coded `NSColor` so the theme milestone
/// (0011) can map the same role onto each shipped family; until then the native
/// default is the only shipped theme, and the audit checks both of its variants
/// against the native bar surface.
public enum KeepAwakeIndicatorPalette {
    public static let activeLightHex = "#0B6B3A"
    public static let activeDarkHex = "#7BD88F"

    /// The active indicator hex for the given appearance variant.
    public static func activeHex(dark: Bool) -> String {
        dark ? activeDarkHex : activeLightHex
    }
}
