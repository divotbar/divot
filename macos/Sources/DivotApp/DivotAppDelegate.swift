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
    private var workspaceFeed: WorkspaceFeed?
    private var reportedWorkspaceAvailability = false

    /// The first-launch item groups. The versioned configuration milestone
    /// loads into this same shape.
    private let layout = BarLayout.default

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // The workspace feed exists before the surfaces so each display's left
        // panel can subscribe to it as it is created.
        let workspaceFeed = WorkspaceFeed()
        self.workspaceFeed = workspaceFeed
        let icons = WorkspaceIconInventory()

        let layout = self.layout
        let adapter = MenuBarObservationAdapter(provider: NSScreenGeometryProvider(),
                                                probe: AXSystemMenuBarProbe())
        let coordinator = DisplayCoordinator(adapter: adapter) { [weak workspaceFeed] id, screen in
            let screensID = NSScreen.screens
                .firstIndex { NSScreenGeometryProvider.displayID(of: $0) == id }
                .map { $0 + 1 }
            return NSPanelBarSurface(id: id,
                                     on: screen,
                                     layout: layout,
                                     workspaceFeed: workspaceFeed,
                                     workspaceIcons: icons,
                                     displayScreensID: screensID) { action in
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

        startWorkspaceFeed()
    }

    /// Start the workspace provider. The workspace indicators render in each
    /// display's left panel; this also reports an honest unavailable reason when
    /// no supported manager is present.
    private func startWorkspaceFeed() {
        guard let feed = workspaceFeed else { return }
        feed.onChange = { [weak self] state in
            guard let self, !self.reportedWorkspaceAvailability else { return }
            self.reportedWorkspaceAvailability = true
            if let reason = state.availability.unavailability {
                FileHandle.standardError.write(
                    Data("divot: workspaces: \(reason.summary).\n".utf8))
            }
        }

        let selection = WorkspaceManagerSelector.select(preferred: nil,
                                                        installed: WorkspaceAdapterFactory.installedManagers())
        let options = WorkspaceOptionsStore.load()
        guard let selection else {
            feed.start(adapter: nil, eventSourceProvider: nil, options: options)
            return
        }
        let kind = selection.kind
        feed.start(adapter: WorkspaceAdapterFactory.makeAdapter(for: kind),
                   eventSourceProvider: { WorkspaceAdapterFactory.makeEventSource(for: kind) },
                   options: options)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        workspaceFeed?.stop()
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
