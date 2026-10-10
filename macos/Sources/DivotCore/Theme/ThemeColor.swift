import Foundation

/// A resolved RGB color used by the pure theme layer.
///
/// The theme catalog is defined in `DivotCore` so palettes, overrides, and
/// contrast fixtures are testable without a window server. `DivotAppKit` bridges
/// these values to `NSColor`.
public struct ThemeColor: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    /// Parse a six-digit `#RRGGBB` color. Returns `nil` for anything else; the
    /// configuration parser already rejects malformed hex, so this is a second
    /// guard for palette values built in code.
    public init?(hex: String) {
        var digits = hex
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, digits.allSatisfy({ $0.isHexDigit }),
              let value = Int(digits, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    public static let white = ThemeColor(red: 1, green: 1, blue: 1)
    public static let black = ThemeColor(red: 0, green: 0, blue: 0)

    /// Uppercase `#RRGGBB` for diagnostics and fixtures.
    public var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// WCAG 2.1 relative luminance.
    public var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG 2.1 contrast ratio, from 1 (identical) to 21 (black on white).
    public func contrastRatio(against other: ThemeColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Blend toward `other` by `amount` (0 keeps this color, 1 returns `other`).
    public func mixed(with other: ThemeColor, amount: Double) -> ThemeColor {
        let t = min(max(amount, 0), 1)
        return ThemeColor(red: red + (other.red - red) * t,
                          green: green + (other.green - green) * t,
                          blue: blue + (other.blue - blue) * t,
                          alpha: alpha + (other.alpha - alpha) * t)
    }
}
