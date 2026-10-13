import Foundation
import Testing
@testable import DivotCore

// MARK: - Color math

@Test func themeColorParsesSixDigitHex() {
    let color = try! #require(ThemeColor(hex: "#B7CEFF"))
    #expect(abs(color.red - 183.0 / 255) < 0.001)
    #expect(abs(color.green - 206.0 / 255) < 0.001)
    #expect(abs(color.blue - 255.0 / 255) < 0.001)
    #expect(color.hexString == "#B7CEFF")

    // Without the leading hash, and case-insensitively.
    #expect(ThemeColor(hex: "b7ceff")?.hexString == "#B7CEFF")

    // Malformed values are refused, never guessed.
    #expect(ThemeColor(hex: "B7CEF") == nil)
    #expect(ThemeColor(hex: "#GGGGGG") == nil)
    #expect(ThemeColor(hex: "#B7CEFF00") == nil)
}

@Test func contrastRatioIsSymmetricAndBounded() {
    let white = ThemeColor.white
    let black = ThemeColor.black
    #expect(abs(white.contrastRatio(against: black) - 21) < 0.01)
    #expect(abs(black.contrastRatio(against: white) - 21) < 0.01)
    #expect(abs(white.contrastRatio(against: white) - 1) < 0.001)
}

@Test func tokensDeriveMutedAndSelectedRoles() {
    let tokens = ThemeTokens(foreground: ThemeColor(hex: "#FFFFFF")!,
                             background: ThemeColor(hex: "#000000")!,
                             accent: ThemeColor(hex: "#7AA2F7")!,
                             selected: ThemeColor(hex: "#FFFFFF")!,
                             occupied: ThemeColor(hex: "#9ECE6A")!,
                             error: ThemeColor(hex: "#F7768E")!)
    // Muted roles sit between the foreground and background, so they keep order.
    #expect(tokens.secondary.relativeLuminance < tokens.foreground.relativeLuminance)
    #expect(tokens.secondary.relativeLuminance > tokens.background.relativeLuminance)
    #expect(tokens.disabled.relativeLuminance < tokens.secondary.relativeLuminance)
    // A white selected background takes the dark label for AA.
    #expect(tokens.selectedForeground.relativeLuminance < tokens.selected.relativeLuminance)
    #expect(tokens.selectedForeground.contrastRatio(against: tokens.selected) >= 4.5)
}

// MARK: - Catalog and attribution

private let families: [AppearanceConfiguration.Family] = [.alpine, .gruvbox, .ayu, .dracula, .tokyoNight]

@Test func everyFamilyShipsBothVariantsWithUpstreamAttribution() {
    for family in families {
        for variant in ThemeVariant.allCases {
            let palette = try! #require(ThemeCatalog.palette(family: family, variant: variant),
                                        "missing \(family.rawValue) \(variant.rawValue)")
            #expect(palette.family == family)
            #expect(palette.variant == variant)
            #expect(!palette.attribution.source.isEmpty)
            #expect(palette.attribution.url.hasPrefix("https://"))
            #expect(palette.attribution.license == "MIT")
            #expect(!palette.attribution.familyName.isEmpty)
            #expect(!palette.attribution.variantName.isEmpty)
        }
    }
    // Native is the system default, not a hex palette.
    #expect(ThemeCatalog.palette(family: .native, variant: .dark) == nil)
}

@Test func everyUpstreamLightVariantIsLabeledOfficial() {
    // Gruvbox, Ayu, Alucard, and Tokyo Night Light are all shipped by upstream,
    // and Alpine's two variants are Divot's own, so none of the families relies
    // on an invented palette.
    for family in families {
        let light = try! #require(ThemeCatalog.palette(family: family, variant: .light))
        #expect(light.attribution.isOfficialVariant, "\(family.rawValue) light marked unofficial")
    }
    // Ayu Light is official but tuned for bar contrast, and says so.
    let ayuLight = try! #require(ThemeCatalog.palette(family: .ayu, variant: .light))
    #expect(ayuLight.attribution.note != nil)
}

// MARK: - Contrast fixtures

/// Per-role contrast floors. Body text clears AA (4.5); the selected label
/// clears AA against its state; state indicators and the accent clear the 3:1
/// non-text floor; disabled text stays visible though WCAG exempts it.
private let floors: [(name: String, floor: Double)] = [
    ("foreground/background", 4.5),
    ("foreground/surface", 4.5),
    ("secondary/background", 3.0),
    ("disabled/background", 2.0),
    ("selectedForeground/selected", 4.5),
    ("selected/background", 2.5),
    ("error/background", 3.0),
    ("occupied/background", 3.0),
    ("accent/background", 2.5),
    ("border/background", 1.2)
]

@Test func everyPaletteClearsItsContrastFloorsInEveryState() {
    for family in families {
        for variant in ThemeVariant.allCases {
            let tokens = try! #require(ThemeCatalog.palette(family: family, variant: variant)).tokens
            let measured: [String: Double] = [
                "foreground/background": tokens.foreground.contrastRatio(against: tokens.background),
                "foreground/surface": tokens.foreground.contrastRatio(against: tokens.surface),
                "secondary/background": tokens.secondary.contrastRatio(against: tokens.background),
                "disabled/background": tokens.disabled.contrastRatio(against: tokens.background),
                "selectedForeground/selected": tokens.selectedForeground.contrastRatio(against: tokens.selected),
                "selected/background": tokens.selected.contrastRatio(against: tokens.background),
                "error/background": tokens.error.contrastRatio(against: tokens.background),
                "occupied/background": tokens.occupied.contrastRatio(against: tokens.background),
                "accent/background": tokens.accent.contrastRatio(against: tokens.background),
                "border/background": tokens.border.contrastRatio(against: tokens.background)
            ]
            for floor in floors {
                let value = measured[floor.name]!
                #expect(value >= floor.floor,
                        "\(family.rawValue) \(variant.rawValue) \(floor.name) = \(value) < \(floor.floor)")
            }
        }
    }
}

// MARK: - Resolution

@Test func nativeResolvesToSystemColors() {
    let resolved = ThemeResolver.resolve(.default, dark: false)
    #expect(resolved.usesSystemColors)
    #expect(resolved.tokens == nil)
    #expect(resolved.attribution == nil)
    #expect(resolved.family == .native)
}

@Test func variantSelectionFollowsTheDarkFlag() {
    #expect(ThemeResolver.resolve(.default, dark: true).variant == .dark)
    #expect(ThemeResolver.resolve(.default, dark: false).variant == .light)

    let gruvbox = AppearanceConfiguration(family: .gruvbox)
    #expect(ThemeResolver.resolve(gruvbox, dark: true).tokens?.background.hexString == "#282828")
    #expect(ThemeResolver.resolve(gruvbox, dark: false).tokens?.background.hexString == "#FBF1C7")
    // The family survives the variant change.
    #expect(ThemeResolver.resolve(gruvbox, dark: false).family == .gruvbox)
}

/// Alpine is Divot's own family: both variants are authored by the project and
/// resolve to the project's lake-blue/pine/warm-paper direction.
@Test func alpineIsDivotsOwnFamilyWithBothAuthoredVariants() {
    let dark = try! #require(ThemeCatalog.palette(family: .alpine, variant: .dark))
    let light = try! #require(ThemeCatalog.palette(family: .alpine, variant: .light))
    #expect(dark.attribution.source == "Divot")
    #expect(light.attribution.source == "Divot")
    #expect(dark.attribution.isOfficialVariant)
    #expect(light.attribution.isOfficialVariant)
    #expect(ThemeResolver.resolve(AppearanceConfiguration(family: .alpine), dark: true)
        .tokens?.background.hexString == "#16272B")
    #expect(ThemeResolver.resolve(AppearanceConfiguration(family: .alpine), dark: false)
        .tokens?.background.hexString == "#F4F1E8")
}

@Test func defaultAccentAdoptsTheFamilySignature() {
    var appearance = AppearanceConfiguration(family: .gruvbox, mode: .dark)
    appearance.accent = AppearanceConfiguration.defaultAccent
    let tokens = try! #require(ThemeResolver.resolve(appearance, dark: true).tokens)
    #expect(tokens.accent.hexString == "#FABD2F")

    // The native default keeps the built-in accent untouched.
    #expect(ThemeResolver.resolve(.default, dark: true).tokens == nil)
}

@Test func explicitRootAccentOverridesTheFamilyAccent() {
    var appearance = AppearanceConfiguration(family: .gruvbox, mode: .dark)
    appearance.accent = "#B7CEFF"
    let tokens = try! #require(ThemeResolver.resolve(appearance, dark: true).tokens)
    #expect(tokens.accent.hexString == "#B7CEFF")
}

@Test func paletteAccentBeatsTheRootAccent() {
    var appearance = AppearanceConfiguration(family: .gruvbox, mode: .dark)
    appearance.accent = "#B7CEFF"
    appearance.palette = [.accent: "#B8BB26"]
    let tokens = try! #require(ThemeResolver.resolve(appearance, dark: true).tokens)
    #expect(tokens.accent.hexString == "#B8BB26")
}

@Test func paletteOverridesReplaceTheNamedTokensAndKeepChromeCoherent() {
    var appearance = AppearanceConfiguration(family: .gruvbox, mode: .dark)
    appearance.palette = [
        .foreground: "#EBDBB2",
        .background: "#002B36",
        .selected: "#458588",
        .occupied: "#83A598",
        .error: "#FB4934"
    ]
    let tokens = try! #require(ThemeResolver.resolve(appearance, dark: true).tokens)
    #expect(tokens.foreground.hexString == "#EBDBB2")
    #expect(tokens.background.hexString == "#002B36")
    #expect(tokens.selected.hexString == "#458588")
    #expect(tokens.occupied.hexString == "#83A598")
    #expect(tokens.error.hexString == "#FB4934")
    // An overridden background re-derives the surface/border so the chrome is
    // not stranded on the family's original base.
    #expect(tokens.surface != tokens.background)
    #expect(tokens.surface.hexString != "#3C3836")
    // Derived roles follow the override.
    #expect(tokens.secondary.relativeLuminance < tokens.foreground.relativeLuminance)
}

@Test func everyFamilyVariantKeepsItsOwnAttributionThroughResolution() {
    for family in families {
        var appearance = AppearanceConfiguration(family: family, mode: .dark)
        appearance.accent = AppearanceConfiguration.defaultAccent
        let resolved = ThemeResolver.resolve(appearance, dark: true)
        #expect(resolved.attribution?.familyName == ThemeCatalog.palette(family: family, variant: .dark)?.attribution.familyName)
        #expect(!resolved.usesSystemColors)
        #expect(resolved.tokens != nil)
    }
}

// MARK: - Popover swatches

@Test func everyFamilyVariantHasASwatchFromItsOwnPalette() {
    for family in families {
        for variant in ThemeVariant.allCases {
            let swatch = try! #require(ThemeResolver.swatch(family: family, variant: variant),
                                       "missing \(family.rawValue) \(variant.rawValue) swatch")
            let tokens = try! #require(ThemeCatalog.palette(family: family, variant: variant)).tokens
            #expect(swatch.background == tokens.background)
            #expect(swatch.accent == tokens.accent)
        }
    }
    // Native draws with macOS semantic colours instead of a hex swatch.
    #expect(ThemeResolver.swatch(family: .native, variant: .dark) == nil)
    #expect(ThemeResolver.swatch(family: .native, variant: .light) == nil)
}

@Test func modeResolvesToTheVariantTheBarDraws() {
    #expect(AppearanceConfiguration.Mode.system.variant(systemDark: true) == .dark)
    #expect(AppearanceConfiguration.Mode.system.variant(systemDark: false) == .light)
    // An explicit override ignores the system state.
    #expect(AppearanceConfiguration.Mode.dark.variant(systemDark: false) == .dark)
    #expect(AppearanceConfiguration.Mode.light.variant(systemDark: true) == .light)
}

// MARK: - Popover link

/// The popover link role is the family accent nudged toward the foreground
/// until it clears AA (4.5) against the background, so a popover footer link is
/// readable instead of only a non-text indicator. An accent that already clears
/// the floor is used unchanged.
@Test func popoverLinkClearsTheTextFloorAndKeepsAClearingAccent() {
    for family in families {
        for variant in ThemeVariant.allCases {
            let tokens = try! #require(ThemeCatalog.palette(family: family, variant: variant)).tokens
            let ratio = tokens.link.contrastRatio(against: tokens.background)
            #expect(ratio >= 4.5, "\(family.rawValue) \(variant.rawValue) link = \(ratio)")
            if tokens.accent.contrastRatio(against: tokens.background) >= 4.5 {
                #expect(tokens.link == tokens.accent)
            }
        }
    }
}
