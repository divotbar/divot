import AppKit
import Testing
@testable import DivotAppKit
import DivotCore

/// The appearance popover's content: the System/Light/Dark segmented control,
/// the theme swatch grid, and the settings row.
@MainActor
@Suite("Appearance popover content")
struct AppearancePopoverContentTests {
    private func makeController() -> AppearancePopoverContentController {
        let controller = AppearancePopoverContentController()
        // Force `loadView` so the rows exist before the assertions.
        _ = controller.view
        return controller
    }

    @Test func offersEveryModeAndFamilyFromTheEnums() {
        let controller = makeController()

        #expect(Set(AppearancePopoverContentController.modeOrder) == Set(AppearanceConfiguration.Mode.allCases))
        #expect(controller.modeControl.segmentCount == AppearanceConfiguration.Mode.allCases.count)
        #expect(Set(controller.familyButtons.keys) == Set(AppearanceConfiguration.Family.allCases))
    }

    @Test func modeControlPresentsSystemLightDarkInOrder() {
        let controller = makeController()

        #expect(AppearancePopoverContentController.modeOrder == [.system, .light, .dark])
        let labels = (0..<controller.modeControl.segmentCount)
            .map { controller.modeControl.label(forSegment: $0) }
        #expect(labels == ["System", "Light", "Dark"])
    }

    @Test func marksTheCurrentModeAndFamily() {
        let controller = makeController()

        controller.update(AppearanceConfiguration(family: .gruvbox, mode: .dark), systemDark: true)

        #expect(controller.selectedMode == .dark)
        #expect(controller.modeControl.selectedSegment
                == AppearancePopoverContentController.modeOrder.firstIndex(of: .dark))
        #expect(controller.familyButtons[.gruvbox]?.isChosen == true)
        #expect(controller.familyButtons[.native]?.isChosen == false)
    }

    @Test func aChangeMadeElsewhereMovesTheSelection() {
        let controller = makeController()
        controller.update(AppearanceConfiguration(family: .native, mode: .system))

        // The same call the popover makes when a published change arrives.
        controller.update(AppearanceConfiguration(family: .dracula, mode: .light), systemDark: true)

        #expect(controller.familyButtons[.native]?.isChosen == false)
        #expect(controller.familyButtons[.dracula]?.isChosen == true)
        #expect(controller.selectedMode == .light)
    }

    @Test func choosingAModeForwardsTheValue() {
        let controller = makeController()
        var reported: AppearanceConfiguration.Mode?
        controller.onModeSelected = { reported = $0 }

        controller.modeControl.selectedSegment =
            AppearancePopoverContentController.modeOrder.firstIndex(of: .light)!
        controller.modeControl.sendAction(controller.modeControl.action, to: controller.modeControl.target)

        #expect(reported == .light)
    }

    @Test func choosingAFamilyForwardsTheValue() {
        let controller = makeController()
        var reported: AppearanceConfiguration.Family?
        controller.onFamilySelected = { reported = $0 }

        controller.familyButtons[.tokyoNight]?.performClick(nil)

        #expect(reported == .tokyoNight)
    }

    @Test func themeSwatchesComeFromTheResolvedPalette() {
        let controller = makeController()

        controller.update(AppearanceConfiguration(family: .gruvbox, mode: .dark), systemDark: true)
        #expect(controller.familyButtons[.gruvbox]?.swatch?.background.hexString == "#282828")
        #expect(controller.familyButtons[.gruvbox]?.swatch?.accent.hexString == "#FABD2F")

        // The same family previews its light palette when the mode is light.
        controller.update(AppearanceConfiguration(family: .gruvbox, mode: .light), systemDark: true)
        #expect(controller.familyButtons[.gruvbox]?.swatch?.background.hexString == "#FBF1C7")

        // Native has no hex palette, so the option draws with system colours.
        let native = try! #require(controller.familyButtons[.native])
        #expect(native.swatch == nil)
    }

    @Test func modeSystemPreviewsTheSystemVariant() {
        let controller = makeController()

        controller.update(AppearanceConfiguration(family: .ayu, mode: .system), systemDark: true)
        #expect(controller.familyButtons[.ayu]?.swatch?.background.hexString == "#0A0E14")

        controller.update(AppearanceConfiguration(family: .ayu, mode: .system), systemDark: false)
        #expect(controller.familyButtons[.ayu]?.swatch?.background.hexString == "#FAFAFA")
    }

    @Test func optionsAreLabelledSelectedAndKeyboardReachable() {
        let controller = makeController()
        controller.update(AppearanceConfiguration(family: .ayu, mode: .dark))

        #expect(controller.modeControl.accessibilityLabel() == "Mode")
        #expect(controller.modeControl.accessibilityValue() as? String == "Dark")
        #expect(!controller.modeControl.refusesFirstResponder)

        for (family, button) in controller.familyButtons {
            #expect(button.accessibilityLabel() == "Theme: \(family.displayName)")
            #expect(!button.refusesFirstResponder)
        }
        #expect(controller.familyButtons[.ayu]?.accessibilityValue() as? String == "Selected")
        #expect(controller.familyButtons[.native]?.accessibilityValue() as? String == "Not selected")
    }

    @Test func focusLandsOnTheModeControl() {
        let controller = makeController()
        controller.update(AppearanceConfiguration(family: .native, mode: .light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller

        controller.focusInitialResponder()

        #expect(window.firstResponder === controller.modeControl)
    }

    @Test func theSettingsRowOpensDivotSettings() {
        let controller = makeController()
        var opened = false
        controller.onOpenDivotSettings = { opened = true }

        let settingsButton = controller.stack.arrangedSubviews
            .compactMap { $0 as? NSButton }
            .first { $0.title == "Open Divot Settings…" }
        settingsButton?.performClick(nil)

        #expect(opened)
    }

    @Test func themeGridWrapsToAtMostThreeColumns() {
        #expect(AppearancePopoverContentController.themeGridColumns(for: 5) == 3)
        #expect(AppearancePopoverContentController.themeGridColumns(for: 4) == 3)
        #expect(AppearancePopoverContentController.themeGridColumns(for: 3) == 3)
        #expect(AppearancePopoverContentController.themeGridColumns(for: 2) == 2)
        #expect(AppearancePopoverContentController.themeGridColumns(for: 1) == 1)
        #expect(AppearancePopoverContentController.themeGridColumns(for: 0) == 1)
    }

    @Test func theAppearancePopoverDropsTheSharedWidthFloor() {
        // The shared Wi-Fi/volume floor leaves an empty block beside this
        // content, so the Appearance popover sizes to its own control and grid.
        let appearance = makeController()
        #expect(appearance.minimumContentWidth == 0)

        let shared = WifiPopoverContentController()
        _ = shared.view
        #expect(shared.minimumContentWidth == 272)
    }

    @Test func theContentTakesItsColorsFromTheBarTheme() {
        let controller = makeController()
        let theme = BarTheme.resolve(AppearanceConfiguration(family: .gruvbox), dark: true)

        controller.apply(theme: theme)

        // The settings link uses the theme's contrast-safe link role, not a
        // fixed system accent, and the swatch options follow its label/ring.
        let settingsButton = controller.stack.arrangedSubviews
            .compactMap { $0 as? NSButton }
            .first { $0.title == "Open Divot Settings…" }
        #expect(settingsButton?.contentTintColor == theme.popoverPalette.link)
        for button in controller.familyButtons.values {
            #expect(button.highlightColor == theme.popoverPalette.link)
            #expect(button.contentTintColor == theme.popoverPalette.label)
        }
        // The content background is the bar's own background token.
        let background = controller.view.layer?.backgroundColor
        let expected = theme.popoverPalette.background.usingColorSpace(.sRGB)
        let actual = background.flatMap { NSColor(cgColor: $0)?.usingColorSpace(.sRGB) }
        #expect(actual == expected)
    }

    @Test func aThemedPopoverAdoptsTheBarVariant() {
        let dark = BarTheme.resolve(AppearanceConfiguration(family: .dracula), dark: true)
        let light = BarTheme.resolve(AppearanceConfiguration(family: .dracula), dark: false)

        #expect(dark.popoverAppearance?.name == .darkAqua)
        #expect(light.popoverAppearance?.name == .aqua)
    }
}
