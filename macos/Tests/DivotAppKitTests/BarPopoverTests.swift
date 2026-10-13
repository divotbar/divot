import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// A stub monitor that records the host's start/stop lifecycle and lets a test
/// fire the outside-click press and inspect the in-app press decision, so the
/// dismiss logic is exercised without a real event monitor or window server.
@MainActor
private final class StubPopoverMonitor: PopoverEventMonitoring {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var onDismiss: (() -> Void)?
    private var action: ((NSEvent) -> PopoverPressAction)?
    var isMonitoring = false

    func start(action: @escaping (NSEvent) -> PopoverPressAction, onDismiss: @escaping () -> Void) {
        startCount += 1
        isMonitoring = true
        self.action = action
        self.onDismiss = onDismiss
    }

    func stop() {
        stopCount += 1
        isMonitoring = false
        action = nil
        onDismiss = nil
    }

    /// Fire the callback the live global monitor calls for a press outside the app.
    func fireOutsideClick() { onDismiss?() }

    /// The host's in-app press decision for a synthetic press.
    func pressAction(_ event: NSEvent) -> PopoverPressAction { action?(event) ?? .dismissAndPass }
}

/// A mouse-down event with no window, for the in-app press decision.
private func pressEvent() -> NSEvent {
    NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
                       timestamp: 0, windowNumber: 0, context: nil,
                       eventNumber: 0, clickCount: 1, pressure: 1)!
}

/// The dismiss decision a press makes: an outside press and a press elsewhere in
/// Divot dismiss; a press inside the popover keeps it open; a press on the anchor
/// item is the toggle-close and is consumed so the item cannot re-present.
@MainActor
@Test func popoverPressPolicyDistinguishesOutsideAnchorAndPopover() {
    #expect(PopoverDismissPolicy.actionForOutsideAppPress() == .dismissAndPass)

    #expect(PopoverDismissPolicy.actionForInAppPress(onAnchor: true, insidePopover: false) == .dismissAndConsume)
    #expect(PopoverDismissPolicy.actionForInAppPress(onAnchor: false, insidePopover: true) == .keepOpen)
    #expect(PopoverDismissPolicy.actionForInAppPress(onAnchor: false, insidePopover: false) == .dismissAndPass)

    #expect(PopoverDismissPolicy.dismissesForEscape())
}

/// A second click on the item that already owns the open popover closes it;
/// any other click opens it.
@MainActor
@Test func popoverItemClickTogglesOnlyTheOwningItem() {
    #expect(PopoverDismissPolicy.itemClickCloses(alreadyOwnsAnchor: true))
    #expect(!PopoverDismissPolicy.itemClickCloses(alreadyOwnsAnchor: false))
}

/// When a popover is open and the bar's theme changes, the popover's chrome
/// and content update without closing.
@MainActor
@Test func openPopoverUpdatesOnThemeChange() {
    let families: [AppearanceConfiguration.Family] = [.native, .gruvbox]
    for initialFamily in families {
        for changeToFamily in families where changeToFamily != initialFamily {
            let initialTheme = BarTheme.resolve(AppearanceConfiguration(family: initialFamily, mode: .light), dark: false)
            let changedTheme = BarTheme.resolve(AppearanceConfiguration(family: changeToFamily, mode: .dark), dark: true)

            let host = BarPopoverHost(monitors: StubPopoverMonitor())
            let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                        styleMask: .borderless, backing: .buffered, defer: false)
            let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
            anchorWindow.contentView?.addSubview(anchor)

            let content = VolumePopoverContentController()
            content.theme = initialTheme
            host.present(content, relativeTo: anchor)

            // Verify initial state
            guard let chrome = host.panel?.contentView as? PopoverChromeView else {
                #expect(Bool(false), "chrome should exist")
                continue
            }
            let initialBackground = chrome.palette.background
            #expect(initialBackground == initialTheme.popoverPalette.background)

            // Change theme while popover is open
            host.restyle(theme: changedTheme)

            // Verify the chrome and content updated
            #expect(chrome.palette.background == changedTheme.popoverPalette.background,
                   "Chrome palette should update to \(changeToFamily) from \(initialFamily)")
            #expect(content.theme.popoverPalette.background == changedTheme.popoverPalette.background,
                   "Content theme should update")
            #expect(host.panel?.appearance == changedTheme.popoverAppearance,
                   "Panel appearance should match new theme's variant")

            host.dismiss()
        }
    }
}

/// The host installs the dismiss monitors when it presents and removes them the
/// moment the popover closes — never a poll.
@MainActor
@Test func hostInstallsAndRemovesDismissMonitorsAroundASession() {
    let monitor = StubPopoverMonitor()
    let host = BarPopoverHost(monitors: monitor)

    #expect(!host.isMonitoringDismiss)
    host.startDismissMonitors()
    #expect(monitor.startCount == 1)
    #expect(host.isMonitoringDismiss)

    // A press outside the app (or Escape) runs the host's dismiss path, which
    // removes the monitors again.
    monitor.fireOutsideClick()
    #expect(!host.isMonitoringDismiss)
    #expect(monitor.stopCount >= 1)

    // Dismissing again is harmless and never leaves a monitor installed.
    host.dismiss()
    #expect(!host.isMonitoringDismiss)
}

/// With nothing shown, an item click opens rather than toggles, and an in-app
/// press that is not on a shown anchor or popover dismisses nothing.
@MainActor
@Test func hostDoesNotOwnAnAnchorUntilPresented() {
    let monitor = StubPopoverMonitor()
    let host = BarPopoverHost(monitors: monitor)
    let view = NSView()

    #expect(!host.isShown(relativeTo: view))
    #expect(!host.itemClickCloses(relativeTo: view))
    #expect(!host.isMonitoringDismiss)

    host.startDismissMonitors()
    // No popover window and no anchor, so a stray in-app press dismisses
    // (which here is a no-op) and passes through.
    #expect(monitor.pressAction(pressEvent()) == .dismissAndPass)
}

/// The popover content background is fully opaque (alpha == 1) for all families
/// and modes, so the popover renders predictably regardless of background.
@MainActor
@Test func popoverContentBackgroundIsFullyOpaqueForAllThemes() {
    let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
    let modes: [AppearanceConfiguration.Mode] = [.light, .dark]

    for family in families {
        for mode in modes {
            let appearance = AppearanceConfiguration(family: family, mode: mode)
            let theme = BarTheme.resolve(appearance, dark: mode == .dark)
            let content = BarPopoverContentController()
            content.theme = theme
            _ = content.view
            content.applyTheme()

            guard let backgroundColor = content.view.layer?.backgroundColor else {
                #expect(Bool(false), "Content view should have a layer background color")
                continue
            }
            let nsColor = NSColor(cgColor: backgroundColor)
            let alpha = nsColor?.alphaComponent ?? 0
            #expect(alpha == 1.0, "Background for \(family.displayName) in \(mode.displayName) mode should be fully opaque (alpha: \(alpha))")
        }
    }
}

/// Runtime check on the real popover window (no offscreen rendering): the host
/// shows a borderless panel with a clear (non-opaque) background so the rounded
/// corners and arrow can be cut out, but the PopoverChromeView bubble drawn
/// inside is fully opaque (alpha 1 fill) with no NSVisualEffectView material.
/// All text colours clear WCAG AA (4.5:1) contrast. Appearance rows start at the
/// same leading inset.
@MainActor
@Test func realPopoverWindowHasNoMaterialAndASolidFillForEveryTheme() {
    func walk(_ view: NSView, _ visit: (NSView) -> Void) {
        visit(view)
        view.subviews.forEach { walk($0, visit) }
    }
    func contrastRatio(_ fg: NSColor, _ bg: NSColor) -> Double {
        func luminance(_ color: NSColor) -> Double {
            let rgb = color.withAlphaComponent(1)
            func linearize(_ channel: Double) -> Double {
                return channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            let r = linearize(rgb.redComponent)
            let g = linearize(rgb.greenComponent)
            let b = linearize(rgb.blueComponent)
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
        let l1 = luminance(fg)
        let l2 = luminance(bg)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
    let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]
    for family in families {
        for dark in [false, true] {
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family, mode: dark ? .dark : .light), dark: dark)
            let host = BarPopoverHost(monitors: StubPopoverMonitor())
            let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                        styleMask: .borderless, backing: .buffered, defer: false)
            let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
            anchorWindow.contentView?.addSubview(anchor)
            let content = AppearancePopoverContentController()
            content.theme = theme
            host.present(content, relativeTo: anchor)
            defer { host.dismiss() }

            guard let panel = host.window, let root = panel.contentView as? PopoverChromeView else {
                #expect(Bool(false), "popover panel should exist")
                continue
            }
            // Panel setup: non-opaque for rounded corners, but chrome and content are solid
            #expect(panel.isOpaque == false, "panel should be non-opaque for rounded corner cutout")
            #expect(panel.backgroundColor == NSColor.clear, "panel background should be clear for transparency")

            var materials = 0
            walk(root) { if $0 is NSVisualEffectView { materials += 1 } }
            #expect(materials == 0, "no vibrancy material in \(family)")

            #expect(root.palette.background.alphaComponent == 1, "chrome palette background alpha is 1")
            #expect(root.palette.background == theme.popoverPalette.background.withAlphaComponent(1))

            if let fill = content.view.layer?.backgroundColor {
                #expect(NSColor(cgColor: fill)?.alphaComponent == 1, "content fill alpha is 1")
            } else {
                #expect(Bool(false), "content has a solid layer fill")
            }

            // Verify contrast: label, secondary, and link colours clear AA (4.5:1)
            let palette = theme.popoverPalette
            let labelContrast = contrastRatio(palette.label, palette.background)
            let secondaryContrast = contrastRatio(palette.secondary, palette.background)
            let linkContrast = contrastRatio(palette.link, palette.background)
            #expect(labelContrast >= 4.5, "\(family) label contrast is \(labelContrast)")
            #expect(secondaryContrast >= 4.5, "\(family) secondary contrast is \(secondaryContrast)")
            #expect(linkContrast >= 4.5, "\(family) link contrast is \(linkContrast)")

            content.view.layoutSubtreeIfNeeded()
            for button in content.familyButtons.values {
                let x = button.convert(button.bounds, to: content.view).minX
                #expect(x <= 13, "theme row \(family) starts at the leading inset (x=\(x))")
            }
        }
    }
}
