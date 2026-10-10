import Foundation

/// Resolves a configured font family name to one that can be drawn.
///
/// Kept pure — the caller supplies the families installed on the system — so
/// the fallback is verifiable without a window server. An empty name (the
/// system default) and a name that is not installed both resolve to `nil`,
/// meaning "use the system font". A missing or misspelled font therefore
/// degrades to the system font instead of leaving the bar unreadable; it is
/// never a crash and never a rejected configuration.
public enum BarFontResolver {
    /// The configured name when it names an installed family, else `nil` for
    /// the system font.
    public static func resolveFamily(_ name: String, installed: Set<String>) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, installed.contains(trimmed) else { return nil }
        return trimmed
    }
}
