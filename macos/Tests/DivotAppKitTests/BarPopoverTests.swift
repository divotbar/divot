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
    let families: [AppearanceConfiguration.Family] = [.native, .alpine, .gruvbox, .ayu, .dracula, .tokyoNight]
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
