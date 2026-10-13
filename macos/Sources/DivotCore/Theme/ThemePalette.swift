import Foundation

// MARK: - Variant

/// The light/dark half of a family. `AppearanceConfiguration.Mode` selects one:
/// `dark` and `light` are explicit, `system` follows the Mac's appearance.
public enum ThemeVariant: String, CaseIterable, Codable, Sendable {
    case light
    case dark

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Tokens

/// The semantic color roles one family variant resolves to.
///
/// The six overridable roles (`foreground`, `background`, `accent`, `selected`,
/// `occupied`, `error`) come from the family and can be replaced by
/// `appearance.palette`. The remaining chrome roles are derived from them so an
/// override stays coherent: `surface`/`border` from `background`, muted and
/// disabled text from `foreground`/`background`, and the selected label from
/// whichever of the foreground/background/black/white clears AA on `selected`.
public struct ThemeTokens: Equatable, Sendable {
    public let foreground: ThemeColor
    public let background: ThemeColor
    public let surface: ThemeColor
    public let border: ThemeColor
    public let accent: ThemeColor
    public let selected: ThemeColor
    public let occupied: ThemeColor
    public let error: ThemeColor

    public let secondary: ThemeColor
    public let disabled: ThemeColor
    public let selectedForeground: ThemeColor
    /// The popover link/accent text: the family accent nudged toward the
    /// foreground until it clears AA (4.5) against the background, so a popover
    /// footer link is readable rather than merely a non-text indicator.
    public let link: ThemeColor

    public init(foreground: ThemeColor,
                background: ThemeColor,
                surface: ThemeColor? = nil,
                border: ThemeColor? = nil,
                accent: ThemeColor,
                selected: ThemeColor,
                occupied: ThemeColor,
                error: ThemeColor) {
        self.foreground = foreground
        self.background = background
        self.surface = surface ?? background.mixed(with: foreground, amount: 0.06)
        self.border = border ?? background.mixed(with: foreground, amount: 0.18)
        self.accent = accent
        self.selected = selected
        self.occupied = occupied
        self.error = error
        self.secondary = foreground.mixed(with: background, amount: 0.30)
            .adjustedForText(against: background, minimum: 4.5, toward: foreground)
        self.disabled = foreground.mixed(with: background, amount: 0.50)
        self.selectedForeground = ThemeTokens.bestLabel(on: selected,
                                                        candidates: [foreground, background, .white, .black])
        self.link = accent.adjustedForText(against: background,
                                           minimum: 4.5,
                                           toward: foreground)
    }

    /// The candidate label with the highest contrast against a state background.
    static func bestLabel(on background: ThemeColor, candidates: [ThemeColor]) -> ThemeColor {
        candidates.max { $0.contrastRatio(against: background) < $1.contrastRatio(against: background) }!
    }
}

// MARK: - Attribution

/// Where a family variant's colors come from. Every family carries its upstream
/// source, license, and whether the light variant is an official upstream
/// variant or a Divot adaptation.
public struct ThemeAttribution: Equatable, Sendable {
    public let familyName: String
    public let variantName: String
    public let source: String
    public let url: String
    public let license: String
    /// True when the upstream project ships this light/dark variant itself.
    public let isOfficialVariant: Bool
    /// Any Divot-side note (for example a contrast tuning), otherwise `nil`.
    public let note: String?

    public init(familyName: String,
                variantName: String,
                source: String,
                url: String,
                license: String,
                isOfficialVariant: Bool = true,
                note: String? = nil) {
        self.familyName = familyName
        self.variantName = variantName
        self.source = source
        self.url = url
        self.license = license
        self.isOfficialVariant = isOfficialVariant
        self.note = note
    }
}

// MARK: - Palette

/// One family variant: its resolved base tokens and its upstream attribution.
public struct ThemePalette: Equatable, Sendable {
    public let family: AppearanceConfiguration.Family
    public let variant: ThemeVariant
    public let tokens: ThemeTokens
    public let attribution: ThemeAttribution

    public init(family: AppearanceConfiguration.Family,
                variant: ThemeVariant,
                tokens: ThemeTokens,
                attribution: ThemeAttribution) {
        self.family = family
        self.variant = variant
        self.tokens = tokens
        self.attribution = attribution
    }
}

// MARK: - Swatch

/// A small sample of a family variant's own palette, drawn by the appearance
/// popover to preview a theme.
///
/// It carries resolved `ThemeColor`s taken straight from the catalog, so the
/// preview always follows the real palette — nothing is hand-copied — and a new
/// family appears automatically. The `native` family has no hex palette and
/// resolves to a `nil` swatch: its option draws with macOS semantic colors.
public struct ThemeSwatch: Equatable, Sendable {
    public let background: ThemeColor
    public let accent: ThemeColor

    public init(background: ThemeColor, accent: ThemeColor) {
        self.background = background
        self.accent = accent
    }
}

// MARK: - Catalog

/// The four curated hacker families, each with an upstream-sourced light and
/// dark variant. Colors are pinned from the upstream palettes named in each
/// `ThemeAttribution`; the only Divot-side tuning is noted per variant.
public enum ThemeCatalog {
    public static func palette(family: AppearanceConfiguration.Family,
                               variant: ThemeVariant) -> ThemePalette? {
        switch (family, variant) {
        case (.gruvbox, .dark): return gruvboxDark
        case (.gruvbox, .light): return gruvboxLight
        case (.ayu, .dark): return ayuDark
        case (.ayu, .light): return ayuLight
        case (.dracula, .dark): return draculaDark
        case (.dracula, .light): return draculaLight
        case (.tokyoNight, .dark): return tokyoNightDark
        case (.tokyoNight, .light): return tokyoNightLight
        case (.native, _): return nil
        }
    }

    /// The palette sample for a family variant, or `nil` for native (which has
    /// no hex palette). The appearance popover draws this so its theme previews
    /// are the family's own colors, never a hand-copied copy.
    public static func swatch(family: AppearanceConfiguration.Family,
                              variant: ThemeVariant) -> ThemeSwatch? {
        guard let tokens = palette(family: family, variant: variant)?.tokens else { return nil }
        return ThemeSwatch(background: tokens.background,
                           accent: tokens.accent)
    }

    // MARK: Gruvbox — morhetz/gruvbox, MIT

    private static let gruvbox = (source: "morhetz/gruvbox",
                                  url: "https://github.com/morhetz/gruvbox",
                                  license: "MIT")

    private static let gruvboxDark = ThemePalette(
        family: .gruvbox,
        variant: .dark,
        tokens: ThemeTokens(foreground: hex("#EBDBB2"),
                            background: hex("#282828"),
                            surface: hex("#3C3836"),
                            border: hex("#504945"),
                            accent: hex("#FABD2F"),
                            selected: hex("#83A598"),
                            occupied: hex("#B8BB26"),
                            error: hex("#FB4934")),
        attribution: ThemeAttribution(familyName: "Gruvbox",
                                      variantName: "Gruvbox Dark (medium contrast)",
                                      source: gruvbox.source,
                                      url: gruvbox.url,
                                      license: gruvbox.license))

    private static let gruvboxLight = ThemePalette(
        family: .gruvbox,
        variant: .light,
        tokens: ThemeTokens(foreground: hex("#3C3836"),
                            background: hex("#FBF1C7"),
                            surface: hex("#F2E5BC"),
                            border: hex("#D5C4A1"),
                            accent: hex("#B57614"),
                            selected: hex("#076678"),
                            occupied: hex("#79740E"),
                            error: hex("#9D0006")),
        attribution: ThemeAttribution(familyName: "Gruvbox",
                                      variantName: "Gruvbox Light (medium contrast)",
                                      source: gruvbox.source,
                                      url: gruvbox.url,
                                      license: gruvbox.license))

    // MARK: Ayu — ayu-theme/ayu-colors, MIT

    private static let ayu = (source: "ayu-theme/ayu-colors",
                              url: "https://github.com/ayu-theme/ayu-colors",
                              license: "MIT")

    private static let ayuDark = ThemePalette(
        family: .ayu,
        variant: .dark,
        tokens: ThemeTokens(foreground: hex("#B3B1AD"),
                            background: hex("#0A0E14"),
                            surface: hex("#0D1017"),
                            border: hex("#1D2433"),
                            accent: hex("#E6B450"),
                            selected: hex("#59C2FF"),
                            occupied: hex("#AAD94C"),
                            error: hex("#F07178")),
        attribution: ThemeAttribution(familyName: "Ayu",
                                      variantName: "Ayu Dark",
                                      source: ayu.source,
                                      url: ayu.url,
                                      license: ayu.license))

    /// Ayu Light is an official upstream variant. Its bright state colors are
    /// darkened here so a focused/occupied/error state clears the bar's contrast
    /// floor over a wallpaper; the base background and foreground are upstream.
    private static let ayuLight = ThemePalette(
        family: .ayu,
        variant: .light,
        tokens: ThemeTokens(foreground: hex("#5C6166"),
                            background: hex("#FAFAFA"),
                            surface: hex("#F0F1F2"),
                            border: hex("#E1E4E8"),
                            accent: hex("#D97E1A"),
                            selected: hex("#399EE6"),
                            occupied: hex("#5C8A00"),
                            error: hex("#C94F4F")),
        attribution: ThemeAttribution(familyName: "Ayu",
                                      variantName: "Ayu Light",
                                      source: ayu.source,
                                      url: ayu.url,
                                      license: ayu.license,
                                      note: "Official Ayu Light; Divot darkens the accent, occupied, and error roles for menu-bar contrast."))

    // MARK: Dracula — dracula/dracula-theme, MIT (Alucard is the official light)

    private static let dracula = (source: "dracula/dracula-theme",
                                  url: "https://github.com/dracula/dracula-theme",
                                  license: "MIT")

    private static let draculaDark = ThemePalette(
        family: .dracula,
        variant: .dark,
        tokens: ThemeTokens(foreground: hex("#F8F8F2"),
                            background: hex("#282A36"),
                            surface: hex("#343746"),
                            border: hex("#44475A"),
                            accent: hex("#BD93F9"),
                            selected: hex("#6272A4"),
                            occupied: hex("#50FA7B"),
                            error: hex("#FF5555")),
        attribution: ThemeAttribution(familyName: "Dracula",
                                      variantName: "Dracula",
                                      source: dracula.source,
                                      url: dracula.url,
                                      license: dracula.license))

    private static let draculaLight = ThemePalette(
        family: .dracula,
        variant: .light,
        tokens: ThemeTokens(foreground: hex("#1F1F1F"),
                            background: hex("#FFFBEB"),
                            surface: hex("#F2EEDD"),
                            border: hex("#CFCFDE"),
                            accent: hex("#644AC9"),
                            selected: hex("#644AC9"),
                            occupied: hex("#14710A"),
                            error: hex("#CB3A2A")),
        attribution: ThemeAttribution(familyName: "Dracula",
                                      variantName: "Alucard",
                                      source: dracula.source,
                                      url: dracula.url,
                                      license: dracula.license))

    // MARK: Tokyo Night — enkia/tokyo-night-vscode-theme, MIT

    private static let tokyoNight = (source: "enkia/tokyo-night-vscode-theme",
                                     url: "https://github.com/enkia/tokyo-night-vscode-theme",
                                     license: "MIT")

    private static let tokyoNightDark = ThemePalette(
        family: .tokyoNight,
        variant: .dark,
        tokens: ThemeTokens(foreground: hex("#C0CAF5"),
                            background: hex("#1A1B26"),
                            surface: hex("#1F2335"),
                            border: hex("#292E42"),
                            accent: hex("#7AA2F7"),
                            selected: hex("#3D59A1"),
                            occupied: hex("#9ECE6A"),
                            error: hex("#F7768E")),
        attribution: ThemeAttribution(familyName: "Tokyo Night",
                                      variantName: "Tokyo Night",
                                      source: tokyoNight.source,
                                      url: tokyoNight.url,
                                      license: tokyoNight.license))

    private static let tokyoNightLight = ThemePalette(
        family: .tokyoNight,
        variant: .light,
        tokens: ThemeTokens(foreground: hex("#343B58"),
                            background: hex("#E6E7ED"),
                            surface: hex("#D6D8DF"),
                            border: hex("#C1C2C7"),
                            accent: hex("#5A3E8E"),
                            selected: hex("#2959AA"),
                            occupied: hex("#33635C"),
                            error: hex("#8C4351")),
        attribution: ThemeAttribution(familyName: "Tokyo Night",
                                      variantName: "Tokyo Night Light",
                                      source: tokyoNight.source,
                                      url: tokyoNight.url,
                                      license: tokyoNight.license))

    /// Internal helper so a malformed literal fails loudly at definition time.
    private static func hex(_ value: String) -> ThemeColor {
        guard let color = ThemeColor(hex: value) else {
            preconditionFailure("Invalid theme color literal: \(value)")
        }
        return color
    }
}
