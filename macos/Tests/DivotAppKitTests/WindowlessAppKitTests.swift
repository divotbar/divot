import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The windowless contract (#0091): a `swift test` run must never put a Divot
/// window on screen. These tests exercise the two production paths that used to
/// order real panels front — the anchored popover and the bar panels — and prove
/// they now go through the injected presenter while the window server stays
/// empty for this process.
///
/// The suite carries `.windowless`, so each test also fails if it leaves any
/// window visible.
@MainActor
@Suite("Windowless presentation", .windowless)
struct WindowlessAppKitTests {

    /// The production popover path used to call `panel.makeKeyAndOrderFront`
    /// directly. The injected presenter records the call and the panel stays off
    /// screen, so the window server never sees a Divot window owned by the test
    /// process — before or after.
    @Test func popoverPresentRecordsWithoutShowingAWindow() {
        #expect(onScreenWindowsOwnedByThisProcess().isEmpty)

        let presenter = RecordingWindowPresenter()
        let monitor = NoopPopoverMonitor()
        let host = BarPopoverHost(monitors: monitor, presenter: presenter)

        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                    styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)

        let content = VolumePopoverContentController()
        host.present(content, relativeTo: anchor)

        // The popover was built and wired, but only the presenter saw it.
        #expect(presenter.makeKeyAndOrderFrontCount == 1)
        #expect(presenter.wouldPresent)
        #expect(host.panel != nil)
        #expect(host.window?.isVisible != true)
        #expect(monitor.startCount == 1)

        host.dismiss()

        #expect(NSApplication.shared.windows.filter(\.isVisible).isEmpty)
        #expect(onScreenWindowsOwnedByThisProcess().isEmpty)
    }

    /// The bar panels used to call `orderFrontRegardless()` in `init`. The
    /// presenter records two calls and no panel is ever made visible.
    @Test func barSurfaceBuildsWithoutOrderingPanelsOnScreen() {
        #expect(onScreenWindowsOwnedByThisProcess().isEmpty)

        let presenter = RecordingWindowPresenter()
        let surface = NSPanelBarSurface(id: DisplayBarID(42),
                                        on: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                        presenter: presenter)

        #expect(presenter.orderFrontRegardlessCount == 2)
        #expect(presenter.orderedWindows.count == 2)
        #expect(presenter.orderedWindows.allSatisfy { !$0.isVisible })
        #expect(NSApplication.shared.windows.filter(\.isVisible).isEmpty)
        #expect(onScreenWindowsOwnedByThisProcess().isEmpty)

        surface.close()
    }

    @Test func keepAwakeToastPresentRecordsWithoutShowingAWindow() {
        #expect(onScreenWindowsOwnedByThisProcess().isEmpty)

        let presenter = RecordingWindowPresenter()
        let host = KeepAwakeToastHost(presenter: presenter)
        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                    styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)

        let state = KeepAwakeToastState(isActive: true)
        host.present(state, relativeTo: anchor, theme: .systemDefault)

        #expect(presenter.orderFrontRegardlessCount == 1)
        #expect(presenter.wouldPresent)
        #expect(host.panel != nil)
        #expect(host.panel?.isVisible != true)

        host.dismiss(animated: false)
        #expect(onScreenWindowsOwnedByThisProcess().isEmpty)
    }
}
