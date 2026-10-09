import AppKit
import SwiftUI

/// The settings window: a SwiftUI form hosted by AppKit, opened from the Divot
/// menu and the menu-bar item. It edits the same validated configuration the app
/// runs on.
@MainActor
public final class DivotSettingsWindowController: NSWindowController {
    private let model: DivotSettingsModel

    public init(model: DivotSettingsModel) {
        self.model = model
        let hosting = NSHostingController(rootView: DivotSettingsView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Divot Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.setContentSize(NSSize(width: 500, height: 660))
        window.center()
        window.setFrameAutosaveName("DivotSettingsWindow")
    }

    public required init?(coder: NSCoder) {
        fatalError("DivotSettingsWindowController does not support NSCoding")
    }

    /// Bring the window forward, refreshed from the shared configuration.
    public func present() {
        model.refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
