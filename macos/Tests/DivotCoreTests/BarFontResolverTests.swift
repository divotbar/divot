import Foundation
import Testing
@testable import DivotCore

// MARK: - Font fallback (#0022)

@Test func anEmptyFontNameMeansTheSystemFont() {
    #expect(BarFontResolver.resolveFamily("", installed: ["Helvetica"]) == nil)
    #expect(BarFontResolver.resolveFamily("   ", installed: ["Helvetica"]) == nil)
}

@Test func anInstalledFamilyIsKept() {
    #expect(BarFontResolver.resolveFamily("Helvetica", installed: ["Helvetica", "Menlo"]) == "Helvetica")
}

@Test func aMissingFontFallsBackToTheSystemFontInsteadOfCrashing() {
    // A typo, or a font removed since the file was written, must not fail the
    // load: the renderer falls back to the system font.
    #expect(BarFontResolver.resolveFamily("NotAFont", installed: ["Helvetica"]) == nil)
    #expect(BarFontResolver.resolveFamily("Helvetica Neue", installed: ["Helvetica"]) == nil)
}

@Test func aFontNameIsTrimmedBeforeMatching() {
    #expect(BarFontResolver.resolveFamily("  Menlo ", installed: ["Menlo"]) == "Menlo")
}
