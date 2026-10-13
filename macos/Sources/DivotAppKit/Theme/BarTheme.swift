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
    /// The link/emphasis text role: for a family it is the palette's
    /// contrast-adjusted `link` (accent nudged toward the foreground until it
    /// clears AA against the background); for native it is the system accent,
    /// which already adapts to the popover's appearance.
    public let link: NSColor

    public let material: AppearanceConfiguration.Material
    public let usesSystemColors: Bool
    public let increasedContrast: Bool
    public let reduceTransparency: Bool
    /// Whether this theme resolves the dark variant, so a popover anchored to a
    /// themed bar can adopt the same light/dark appearance as the bar it belongs
    /// to instead of following the app-wide appearance alone.
    public let isDark: Bool

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
                link: .controlAccentColor,
                material: appearance.material,
                usesSystemColors: true,
                increasedContrast: increasedContrast,
                reduceTransparency: reduceTransparency,
                isDark: dark)
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
            link: NSColor(tokens.link),
            material: appearance.material,
            usesSystemColors: false,
            increasedContrast: increasedContrast,
            reduceTransparency: reduceTransparency,
            isDark: dark)
    }

    /// The comfortable native default, used before a configuration is applied.
    public static let systemDefault = BarTheme.resolve(.default, dark: false)

    // MARK: - Popovers

    /// The colours a popover anchored to this theme draws. They come from the
    /// same palette the bar draws, so a popover matches its bar and its label,
    /// secondary, and link roles clear the same contrast floors the audit
    /// checks — instead of a fixed blue that can sit nearly invisible on a dark
    /// popover while the bar is light.
    public struct PopoverPalette: Equatable {
        public let background: NSColor
        public let label: NSColor
        public let secondary: NSColor
        public let link: NSColor
        public let separator: NSColor
    }

    public var popoverPalette: PopoverPalette {
        PopoverPalette(background: background,
                       label: foreground,
                       secondary: secondary,
                       link: link,
                       separator: border)
    }

    /// The popover's light/dark appearance, so its chrome and system controls
    /// (the segmented control, slider, checkbox) match the bar's variant even
    /// when the app-wide appearance differs. `nil` would follow the app.
    public var popoverAppearance: NSAppearance? {
        NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
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
