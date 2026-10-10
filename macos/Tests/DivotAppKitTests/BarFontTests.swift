import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

// MARK: - Font resolution (#0022)

@MainActor
@Test func anUnknownFontFallsBackToTheSystemFont() {
    // A font that is not installed must not leave the bar unreadable: status
    // text keeps the tabular system digits and chips keep the system font.
    let metrics = BarMetrics.scaled(textSize: 14, fontFamily: "No Such Font 12345")
    #expect(BarFont.text(metrics).fontName
        == NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium).fontName)

    let chip = BarFont.chip(metrics, weight: .regular)
    #expect(chip.pointSize == 13)
    #expect(chip.fontName == NSFont.systemFont(ofSize: 13, weight: .regular).fontName)
}

@MainActor
@Test func anEmptyFontMeansTheSystemFont() {
    let metrics = BarMetrics.scaled(textSize: 14)
    #expect(BarFont.text(metrics).fontName
        == NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium).fontName)
}

@MainActor
@Test func anInstalledFamilyResolvesToThatFont() throws {
    let families = BarFont.installedFamilies()
    #expect(!families.isEmpty)
    let family = try #require(families.first { BarFont.resolve(family: $0, size: 14) != nil })

    let metrics = BarMetrics.scaled(textSize: 16, fontFamily: family)
    let font = try #require(BarFont.resolve(family: family, size: 16))
    #expect(font.pointSize == 16)
    #expect(BarFont.text(metrics).pointSize == 16)
}
