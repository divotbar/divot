import Foundation

/// A family/mode resolved to concrete tokens (or to the system palette).
///
/// `usesSystemColors` is true only for the native family, which deliberately
/// follows macOS semantic colors instead of a fixed hex palette so it keeps
/// vibrancy, appearance, and accessibility behavior for free.
public struct ResolvedTheme: Equatable, Sendable {
    public let family: AppearanceConfiguration.Family
    public let variant: ThemeVariant
    public let usesSystemColors: Bool
    /// `nil` for the native family.
    public let tokens: ThemeTokens?
    /// `nil` for the native family.
    public let attribution: ThemeAttribution?

    public init(family: AppearanceConfiguration.Family,
                variant: ThemeVariant,
                usesSystemColors: Bool,
                tokens: ThemeTokens?,
                attribution: ThemeAttribution?) {
        self.family = family
        self.variant = variant
        self.usesSystemColors = usesSystemColors
        self.tokens = tokens
        self.attribution = attribution
    }
}

/// Resolves `appearance` (family + mode + accent + palette overrides) into the
/// tokens the renderer draws with.
public enum ThemeResolver {
    /// The variant for a resolved light/dark state.
    public static func variant(dark: Bool) -> ThemeVariant { dark ? .dark : .light }

    /// The upstream palette for a family variant, or `nil` for native.
    public static func palette(family: AppearanceConfiguration.Family,
                               variant: ThemeVariant) -> ThemePalette? {
        ThemeCatalog.palette(family: family, variant: variant)
    }

    /// Resolve one appearance into tokens.
    ///
    /// Precedence, lowest to highest:
    /// 1. the family/variant palette,
    /// 2. the root `accent` when it differs from the built-in default (the
    ///    default means "use the family's signature accent"),
    /// 3. `appearance.palette` token overrides.
    public static func resolve(_ appearance: AppearanceConfiguration, dark: Bool) -> ResolvedTheme {
        let variant = variant(dark: dark)
        guard appearance.family != .native,
              let base = ThemeCatalog.palette(family: appearance.family, variant: variant) else {
            return ResolvedTheme(family: .native,
                                 variant: variant,
                                 usesSystemColors: true,
                                 tokens: nil,
                                 attribution: nil)
        }

        let defaults = base.tokens
        var foreground = defaults.foreground
        var background = defaults.background
        var surface = defaults.surface
        var border = defaults.border
        var accent = defaults.accent
        var selected = defaults.selected
        var occupied = defaults.occupied
        var error = defaults.error

        // Accent: palette override wins, then an explicit root accent, then the
        // family signature accent.
        if let override = appearance.palette[.accent], let color = ThemeColor(hex: override) {
            accent = color
        } else if appearance.accent != AppearanceConfiguration.defaultAccent,
                  let color = ThemeColor(hex: appearance.accent) {
            accent = color
        }

        if let value = appearance.palette[.foreground], let color = ThemeColor(hex: value) {
            foreground = color
        }
        if let value = appearance.palette[.background], let color = ThemeColor(hex: value) {
            background = color
            // Keep the chrome coherent with an overridden base: derive the
            // surface and border unless the family provided them (it did, but a
            // custom background would otherwise strand them).
            surface = color.mixed(with: foreground, amount: 0.06)
            border = color.mixed(with: foreground, amount: 0.18)
        }
        if let value = appearance.palette[.selected], let color = ThemeColor(hex: value) {
            selected = color
        }
        if let value = appearance.palette[.occupied], let color = ThemeColor(hex: value) {
            occupied = color
        }
        if let value = appearance.palette[.error], let color = ThemeColor(hex: value) {
            error = color
        }

        let tokens = ThemeTokens(foreground: foreground,
                                 background: background,
                                 surface: surface,
                                 border: border,
                                 accent: accent,
                                 selected: selected,
                                 occupied: occupied,
                                 error: error)
        return ResolvedTheme(family: appearance.family,
                             variant: variant,
                             usesSystemColors: false,
                             tokens: tokens,
                             attribution: base.attribution)
    }
}
