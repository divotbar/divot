import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The optional Divot mark before the workspaces (#0024): a template image
/// tinted with the bar theme, a real focusable control with an accessible label,
/// and a click that routes to the settings-window opener.

@MainActor
private func descendants(of view: NSView) -> [NSView] {
    view.subviews.flatMap { subview in [subview] + descendants(of: subview) }
}

@MainActor
private func appIcon(in view: NSView) -> DivotAppIconButton? {
    descendants(of: view).compactMap { $0 as? DivotAppIconButton }.first
}

@MainActor
@Test func appIconButtonDrawsTheTemplateMarkAtTheConfiguredIconSize() throws {
    let metrics = BarMetrics.scaled(textSize: 18)
    let theme = BarTheme.resolve(AppearanceConfiguration(family: .gruvbox), dark: true)
    let button = DivotAppIconButton(metrics: metrics, theme: theme)

    // The same template mark as the menu-bar item, so one asset follows both
    // the light and dark theme.
    let image = try #require(button.image)
    #expect(image.isTemplate)
    #expect(image.representations.contains { $0 is NSPDFImageRep })
    // The mark scales with the text/icon size set in #0022.
    #expect(button.intrinsicContentSize == NSSize(width: metrics.iconSize, height: metrics.iconSize))
    #expect(button.contentTintColor == theme.foreground)
}

@MainActor
@Test func appIconButtonUsesTheConfiguredAppIconSize() throws {
    // The Divot app icon uses the same configured size as the workspace app
    // icons, which can differ from the status icon size (#0052).
    let metrics = BarMetrics.scaled(textSize: 14, appIconSize: 22)
    let button = DivotAppIconButton(metrics: metrics)
    #expect(button.intrinsicContentSize == NSSize(width: 22, height: 22))
}

@MainActor
@Test func appIconButtonIsFocusableLabelledAndHasNoNativeTooltip() {
    let button = DivotAppIconButton()

    // A real keyboard-reachable control, not a static image.
    #expect(!button.refusesFirstResponder)
    #expect(button.accessibilityRole() == .button)
    #expect(button.accessibilityLabel() == DivotAppIconButton.accessibilityLabelText)
    // AGENTS.md forbids a native `title` tooltip; the spoken label carries it.
    #expect(button.toolTip == nil)
}

@MainActor
@Test func appIconButtonRetintsForANewTheme() {
    let light = BarTheme.resolve(AppearanceConfiguration(family: .dracula), dark: false)
    let dark = BarTheme.resolve(AppearanceConfiguration(family: .dracula), dark: true)
    let button = DivotAppIconButton(theme: light)
    #expect(button.contentTintColor == light.foreground)

    button.apply(theme: dark)
    #expect(button.contentTintColor == dark.foreground)
    #expect(button.contentTintColor != light.foreground)
}

@MainActor
@Test func appIconClickRoutesToTheSettingsWindowAction() throws {
    let theme = BarTheme.resolve(AppearanceConfiguration(family: .native), dark: false)
    let content = BarContentView(side: .left, items: [.clock], showsAppIcon: true, theme: theme)
    content.frame = NSRect(x: 0, y: 0, width: 400, height: BarMetrics.default.height)

    var activated: [WidgetAction] = []
    content.onActivate = { activated.append($0) }
    content.layoutSubtreeIfNeeded()

    let button = try #require(appIcon(in: content))
    button.performClick(nil)

    // The click emits the dedicated action the app delegate maps to the
    // existing settings-window opener, not a System Settings pane.
    #expect(activated == [.openDivotSettings])
    #expect(activated.first != .openSettings(.network))
}

@MainActor
@Test func appIconLeadsTheLeftGroupBeforeTheItems() throws {
    let metrics = BarMetrics.scaled(textSize: 16)
    let content = BarContentView(side: .left, items: [.clock, .frontApp], showsAppIcon: true, metrics: metrics)
    content.frame = NSRect(x: 0, y: 0, width: 420, height: metrics.height)
    content.layoutSubtreeIfNeeded()

    let button = try #require(appIcon(in: content))
    let itemViews = descendants(of: content).compactMap { $0 as? BarItemView }
    #expect(!itemViews.isEmpty)
    // The mark sits at the row inset, ahead of every item in the group.
    #expect(abs(button.frame.minX - metrics.rowInset) < 0.5)
    for itemView in itemViews {
        #expect(itemView.frame.minX >= button.frame.maxX)
    }
}

@MainActor
@Test func appIconIsAbsentWhenTheSettingIsOffAndOnTheLeftOnly() {
    let off = BarContentView(side: .left, items: [.clock], showsAppIcon: false)
    off.frame = NSRect(x: 0, y: 0, width: 400, height: BarMetrics.default.height)
    off.layoutSubtreeIfNeeded()
    #expect(appIcon(in: off) == nil)

    // The mark decorates the left group; the right group starts at the items.
    let right = BarContentView(side: .right, items: [.clock], showsAppIcon: true)
    right.frame = NSRect(x: 0, y: 0, width: 400, height: BarMetrics.default.height)
    right.layoutSubtreeIfNeeded()
    #expect(appIcon(in: right) == nil)
}
