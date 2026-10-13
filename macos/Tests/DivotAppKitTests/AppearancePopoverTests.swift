import AppKit
import Testing
@testable import DivotAppKit
import DivotCore

/// The appearance popover's content rows: the System/Light/Dark mode choices,
/// the theme-family choices, and the settings row.
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

        #expect(Set(controller.modeButtons.keys) == Set(AppearanceConfiguration.Mode.allCases))
        #expect(Set(controller.familyButtons.keys) == Set(AppearanceConfiguration.Family.allCases))
    }

    @Test func marksTheCurrentModeAndFamilyChecked() {
        let controller = makeController()

        controller.update(AppearanceConfiguration(family: .gruvbox, mode: .dark))

        #expect(controller.modeButtons[.dark]?.state == .on)
        #expect(controller.modeButtons[.light]?.state == .off)
        #expect(controller.modeButtons[.system]?.state == .off)
        #expect(controller.familyButtons[.gruvbox]?.state == .on)
        #expect(controller.familyButtons[.native]?.state == .off)
    }

    @Test func aChangeMadeElsewhereMovesTheCheck() {
        let controller = makeController()
        controller.update(AppearanceConfiguration(family: .native, mode: .system))

        // The same call the popover makes when a published change arrives.
        controller.update(AppearanceConfiguration(family: .dracula, mode: .light))

        #expect(controller.familyButtons[.native]?.state == .off)
        #expect(controller.familyButtons[.dracula]?.state == .on)
        #expect(controller.modeButtons[.light]?.state == .on)
    }

    @Test func choosingAModeForwardsTheValue() {
        let controller = makeController()
        var reported: AppearanceConfiguration.Mode?
        controller.onModeSelected = { reported = $0 }

        controller.modeButtons[.light]?.performClick(nil)

        #expect(reported == .light)
    }

    @Test func choosingAFamilyForwardsTheValue() {
        let controller = makeController()
        var reported: AppearanceConfiguration.Family?
        controller.onFamilySelected = { reported = $0 }

        controller.familyButtons[.tokyoNight]?.performClick(nil)

        #expect(reported == .tokyoNight)
    }

    @Test func optionsAreLabelledSelectedAndKeyboardReachable() {
        let controller = makeController()
        controller.update(AppearanceConfiguration(family: .ayu, mode: .dark))

        for (mode, button) in controller.modeButtons {
            #expect(button.accessibilityLabel() == "Mode: \(mode.displayName)")
            #expect(!button.refusesFirstResponder)
        }
        #expect(controller.modeButtons[.dark]?.accessibilityValue() as? String == "Selected")
        #expect(controller.modeButtons[.light]?.accessibilityValue() as? String == "Not selected")

        for (family, button) in controller.familyButtons {
            #expect(button.accessibilityLabel() == "Theme: \(family.displayName)")
            #expect(!button.refusesFirstResponder)
        }
    }

    @Test func focusLandsOnTheSelectedMode() {
        let controller = makeController()
        controller.update(AppearanceConfiguration(family: .native, mode: .light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller

        controller.focusInitialResponder()

        #expect(window.firstResponder === controller.modeButtons[.light])
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
}
