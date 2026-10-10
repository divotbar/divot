import AppKit
import DivotCore

/// The AppKit-facing theme: the resolved semantic roles as `NSColor`s plus the
/// material decision, so the bar views draw one path for the native default and
/// the four families.
///
/// The native family uses macOS semantic colors (`labelColor`,
/// `windowBackgroundColor`, `selectedContentBackgroundColor`, …) so it keeps
/// appearance, vibrancy, and accessibility behavior. The four families use the
/// resolved hex tokens. Both honor increased contrast and reduced transparency.
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

    /// Solid background when the user asked for opaque, asked to reduce
    /// transparency, or (for readability) increased contrast.
    public var isOpaque: Bool {
        material == .opaque || reduceTransparency || increasedContrast
    }

    /// The layer fill. Opaque requests (including reduced transparency and
    /// increased contrast) get the solid background. A translucent native
    /// material gets a family-tinted fill over the vibrancy blur, or clear for
    /// the native family, whose background already comes from the system.
    public var layerBackground: NSColor {
        if isOpaque { return background }
        return usesSystemColors ? .clear : background.withAlphaComponent(0.55)
    }

    public var borderWidth: CGFloat { increasedContrast ? 2 : 1 }

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
