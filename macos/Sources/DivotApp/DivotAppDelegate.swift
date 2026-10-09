import AppKit
import DivotAppKit
import DivotCore

/// App lifecycle for the Divot shell.
///
/// It is an accessory app: no Dock tile, no app menu, and the bar panels refuse
/// key/main status, so launching Divot never steals focus from the frontmost
/// app. The bar is filled from the built-in provider pipeline; physical
/// fullscreen/Spaces/multi-display behavior is a separate human evidence gate.
@MainActor
public final class DivotAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: DisplayCoordinator?
    private var pipeline: WidgetPipeline?
    private var pipelineTask: Task<Void, Never>?

    /// The first-launch item groups. The versioned configuration milestone
    /// loads into this same shape.
    private let layout = BarLayout.default

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let layout = self.layout
        let adapter = MenuBarObservationAdapter(provider: NSScreenGeometryProvider(),
                                                probe: AXSystemMenuBarProbe())
        let coordinator = DisplayCoordinator(adapter: adapter) { id, screen in
            NSPanelBarSurface(id: id, on: screen, layout: layout) { action in
                DivotAppDelegate.perform(action)
            }
        }
        coordinator.start()
        self.coordinator = coordinator

        let pipeline = WidgetPipeline { changes in
            coordinator.applyWidgetChanges(changes)
        }
        let providers = DefaultWidgetProviders.make()
        pipelineTask = Task { await pipeline.configure(providers) }
        self.pipeline = pipeline

        if !coordinator.accessibilityPermissionGranted {
            // Reported once at launch; the notched-display detector stays
            // indeterminate without it rather than guessing or hiding.
            FileHandle.standardError.write(
                Data("divot: Accessibility permission not granted; notched-display native-menu-bar detection is indeterminate.\n".utf8))
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        pipelineTask?.cancel()
        let pipeline = self.pipeline
        Task { await pipeline?.stop() }
        coordinator?.stop()
    }

    /// Explicit, minimal click behavior — Divot never mirrors another app's menu
    /// extras. Status items open the matching System Settings pane or activate
    /// the frontmost application; the pane links still need physical validation.
    static func perform(_ action: WidgetAction) {
        switch action {
        case .openSettings(let pane):
            if let url = pane.url { NSWorkspace.shared.open(url) }
        case .activateApplication(let bundleIdentifier):
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .first?.activate()
        case .none:
            break
        }
    }
}
