import AppKit

/// The one seam through which Divot makes one of its windows visible.
///
/// Every place that would order a bar panel or an anchored popover front goes
/// through this protocol, so a test can inject a no-op presenter and a
/// `swift test` run never puts a window on the maintainer's desktop, never
/// steals focus, and never needs the window server (#0091). Production uses
/// `SystemWindowPresenter`, the real AppKit ordering.
///
/// Keep "make a Divot window visible" calls behind this seam. Creating a panel
/// offscreen (so an offscreen snapshot can render its views) is fine; ordering
/// it front without a presenter is the regression this guards against.
@MainActor
public protocol WindowPresenting {
    /// Put a window on screen without taking key focus. The bar panels use this
    /// so they decorate the desktop without pulling focus from the user's app.
    func orderFrontRegardless(_ window: NSWindow)
    /// Put a window on screen and make it key. The anchored popover uses this so
    /// its controls accept keyboard input while it is open.
    func makeKeyAndOrderFront(_ window: NSWindow)
}

/// The production presenter: the real AppKit window ordering.
@MainActor
public struct SystemWindowPresenter: WindowPresenting {
    public init() {}

    public func orderFrontRegardless(_ window: NSWindow) {
        window.orderFrontRegardless()
    }

    public func makeKeyAndOrderFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
    }
}
