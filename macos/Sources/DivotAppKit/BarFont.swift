import AppKit
import DivotCore

/// Resolves the configured text font to an AppKit `NSFont`.
///
/// The configuration stores a font **family** name; macOS maps a family to a
/// concrete face through `NSFontManager`. A configured name that is not
/// installed — a typo, or a font removed since the file was written — falls back
/// to the system font (`BarFontResolver`), so the bar is never left unreadable.
/// The status text keeps tabular system digits while the system font is in use
/// so numeric items do not jitter as values change.
@MainActor
enum BarFont {
    /// Every installed font family, sorted for a stable picker.
    static func installedFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }

    /// The font for status item text.
    static func text(_ metrics: BarMetrics) -> NSFont {
        resolve(family: metrics.fontFamily, size: metrics.textFontSize)
            ?? .monospacedDigitSystemFont(ofSize: metrics.textFontSize, weight: .medium)
    }

    /// The font for workspace chips and the current-program label.
    static func chip(_ metrics: BarMetrics, weight: NSFont.Weight) -> NSFont {
        resolve(family: metrics.fontFamily, size: metrics.chipFontSize)
            ?? .systemFont(ofSize: metrics.chipFontSize, weight: weight)
    }

    /// A font in the configured family, or `nil` when the name is empty, not
    /// installed, or `NSFontManager` cannot produce a face for it.
    static func resolve(family: String?, size: CGFloat) -> NSFont? {
        guard let family = BarFontResolver.resolveFamily(family ?? "",
                                                         installed: Set(NSFontManager.shared.availableFontFamilies)),
              let members = NSFontManager.shared.availableMembers(ofFontFamily: family),
              let faceName = members.first?.first as? String else { return nil }
        return NSFont(name: faceName, size: size)
    }
}
