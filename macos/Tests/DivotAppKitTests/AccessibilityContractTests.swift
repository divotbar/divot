import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Accessibility regression checks for the AppKit layer.
///
/// These assert the contract the physical VoiceOver pass will exercise: an
/// interactive item is a button with a label and help, a non-interactive item is
/// static text that refuses a press, and a restyle never drops the announced
/// label. What no test here can prove — VoiceOver reading order on a real Mac,
/// focus behavior, and display placement — is a human check
/// (`docs/accessibility-physical-checks.md`).

private let allFamilies: [AppearanceConfiguration.Family] =
    [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]

@MainActor
@Test func interactiveItemExposesButtonRoleLabelAndHelp() {
    let view = BarItemView()
    var activated: WidgetAction?
    view.onActivate = { activated = $0 }

    let action = WidgetAction.openSettings(.sound)
    view.update(WidgetPresentation(symbolName: "speaker.fill", text: "40%",
                                   accessibilityLabel: "Volume 40 percent"),
                action: action)

    #expect(view.accessibilityRole() == .button)
    #expect(view.accessibilityLabel() == "Volume 40 percent")
    #expect((view.accessibilityHelp() ?? "").contains("Volume 40 percent"))
    #expect(view.accessibilityPerformPress())
    #expect(activated == action)
}

@MainActor
@Test func nonInteractiveItemExposesStaticTextAndRefusesPress() {
    let view = BarItemView()
    var activated: WidgetAction?
    view.onActivate = { activated = $0 }

    view.update(WidgetPresentation(symbolName: nil, text: "…",
                                   accessibilityLabel: "Network is loading"),
                action: .none)

    #expect(view.accessibilityRole() == .staticText)
    #expect(view.accessibilityLabel() == "Network is loading")
    #expect(view.accessibilityHelp() == nil)
    #expect(!view.accessibilityPerformPress())
    #expect(activated == nil)
}

@MainActor
@Test func accessibleLabelSurvivesEveryThemeRestyle() {
    for family in allFamilies {
        for dark in [false, true] {
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family), dark: dark)
            let view = BarItemView()
            view.apply(theme: theme)
            view.update(WidgetPresentation(symbolName: "wifi", text: "",
                                           accessibilityLabel: "Wi-Fi connected"),
                        action: .openSettings(.network))
            // A restyle repaints colors only; the announcement must not change.
            view.apply(theme: theme)
            #expect(view.accessibilityLabel() == "Wi-Fi connected", "\(family.rawValue) \(dark)")
            #expect(view.accessibilityRole() == .button)
        }
    }
}

@MainActor
@Test func everyDefaultItemIsLabelledAndRoatedAcrossEveryTheme() {
    for family in allFamilies {
        for dark in [false, true] {
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family), dark: dark)
            let content = BarContentView(side: .right, items: BarLayout.default.right, theme: theme)
            content.apply(PerformanceHarness.defaultWorkloadStates().map(WidgetChange.update))
            content.frame = NSRect(x: 0, y: 0, width: 752, height: BarMetrics.default.height)
            content.layoutSubtreeIfNeeded()

            let itemViews = descendants(of: content).compactMap { $0 as? BarItemView }
            #expect(itemViews.count == BarLayout.default.right.count,
                    "\(family.rawValue) \(dark): expected one view per item")
            for itemView in itemViews {
                let label = itemView.accessibilityLabel() ?? ""
                #expect(!label.trimmingCharacters(in: .whitespaces).isEmpty,
                        "\(family.rawValue) \(dark): unlabelled item")
                #expect(itemView.accessibilityRole() == .button
                        || itemView.accessibilityRole() == .staticText)
            }
        }
    }
}

/// Every subview in a tree, so a contract check can find the item views without
/// reaching into `BarContentView`'s private storage.
@MainActor
private func descendants(of view: NSView) -> [NSView] {
    view.subviews.flatMap { subview in [subview] + descendants(of: subview) }
}
