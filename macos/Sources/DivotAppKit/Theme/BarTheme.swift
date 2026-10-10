import AppKit
import DivotCore

/// The AppKit-facing theme: the resolved semantic roles as `NSColor`s plus the
/// material decision, so the bar views draw one path for the native default and
/// the four families.
///
/// The native family uses macOS semantic colors (`labelColor`,
/// `windowBackgroundColor`, `selectedContentBackgroundColor`, …) so it keeps
/// appearance and accessibility behavior. The four families use the resolved
/// hex tokens. Both honor increased contrast and reduced transparency. The bar
/// chrome itself is flat (#0025): the fill is the solid `background` token.
@MainActor
public struct BarTheme: Equatable {
    public let foreground: NSColor
    public let secondary: NSColor
    public let disabled: NSColor
    public let background: NSColor
    public let surface: NSColor
    public let border: NSColor
    public let accent: NSColor
    public let selected: NSColor
    public let selectedForeground: NSColor
    public let occupied: NSColor
    public let error: NSColor

    public let material: AppearanceConfiguration.Material
    public let usesSystemColors: Bool
    public let increasedContrast: Bool
    public let reduceTransparency: Bool

    /// Whether the resolved material would have been opaque, before the flat
    /// chrome (#0025) made every fill solid. Kept so the theme still reports the
    /// user's material decision; it no longer changes the drawn fill.
    public var isOpaque: Bool {
        material == .opaque || reduceTransparency || increasedContrast
    }

    /// The layer fill: the theme's flat `background` token.
    ///
    /// The bar chrome is flat (#0025): one solid colour edge to edge with square
    /// corners and no material bevel, so the fill never falls back to clear or a
    /// translucent tint. `isOpaque` still reports whether the resolved material
    /// would have been translucent; it no longer changes the drawn fill.
    public var layerBackground: NSColor {
        background
    }

    /// The chrome stroke width. The flat default has no border; increased
    /// contrast keeps an explicit stroke so the bar stays separable from a busy
    /// wallpaper.
    public var borderWidth: CGFloat { increasedContrast ? 2 : 0 }

    public var borderColor: NSColor {
        increasedContrast ? foreground.withAlphaComponent(0.55) : border
    }

    /// Resolve an appearance for a light/dark state.
    public static func resolve(_ appearance: AppearanceConfiguration,
                               dark: Bool,
                               increasedContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
                               reduceTransparency: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency) -> BarTheme {
        let resolved = ThemeResolver.resolve(appearance, dark: dark)
        guard let tokens = resolved.tokens, !resolved.usesSystemColors else {
            return BarTheme(
                foreground: .labelColor,
                secondary: .secondaryLabelColor,
                disabled: .tertiaryLabelColor,
                background: .windowBackgroundColor,
                surface: .windowBackgroundColor,
                border: .separatorColor,
                accent: NSColor(hexString: appearance.accent) ?? .controlAccentColor,
                selected: .selectedContentBackgroundColor,
                selectedForeground: .selectedTextColor,
                occupied: .controlAccentColor,
                error: .systemRed,
                material: appearance.material,
                usesSystemColors: true,
                increasedContrast: increasedContrast,
                reduceTransparency: reduceTransparency)
        }
        return BarTheme(
            foreground: NSColor(tokens.foreground),
            secondary: NSColor(tokens.secondary),
            disabled: NSColor(tokens.disabled),
            background: NSColor(tokens.background),
            surface: NSColor(tokens.surface),
            border: NSColor(tokens.border),
            accent: NSColor(tokens.accent),
            selected: NSColor(tokens.selected),
            selectedForeground: NSColor(tokens.selectedForeground),
            occupied: NSColor(tokens.occupied),
            error: NSColor(tokens.error),
            material: appearance.material,
            usesSystemColors: false,
            increasedContrast: increasedContrast,
            reduceTransparency: reduceTransparency)
    }

    /// The comfortable native default, used before a configuration is applied.
    public static let systemDefault = BarTheme.resolve(.default, dark: false)
}

extension NSColor {
    /// Bridge a resolved theme color into AppKit.
    public convenience init(_ color: ThemeColor) {
        self.init(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    /// Parse a six-digit `#RRGGBB` color, or `nil` when malformed.
    public convenience init?(hexString: String) {
        guard let color = ThemeColor(hex: hexString) else { return nil }
        self.init(color)
    }
}
