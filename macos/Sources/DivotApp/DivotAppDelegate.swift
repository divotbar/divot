import AppKit
import ApplicationServices
import DivotAppKit
import DivotCore

/// App lifecycle for the Divot shell.
///
/// It is an accessory app: no Dock tile, no app menu, and the bar panels refuse
/// key/main status, so launching Divot never steals focus from the frontmost
/// app. Physical fullscreen/Spaces/multi-display behavior is not claimed here;
/// it is a separate human evidence gate.
@MainActor
public final class DivotAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: DisplayCoordinator?
    private var workspaceFeed: WorkspaceFeed?
    private var reportedWorkspaceAvailability = false

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // The workspace feed exists before the surfaces so each display's left
        // panel can subscribe to it as it is created.
        let workspaceFeed = WorkspaceFeed()
        self.workspaceFeed = workspaceFeed
        let icons = WorkspaceIconInventory()

        let adapter = MenuBarObservationAdapter(provider: NSScreenGeometryProvider(),
                                                probe: AXSystemMenuBarProbe())
        let coordinator = DisplayCoordinator(adapter: adapter) { [weak workspaceFeed] id, screen in
            let screensID = NSScreen.screens
                .firstIndex { NSScreenGeometryProvider.displayID(of: $0) == id }
                .map { $0 + 1 }
            let left: NSView? = workspaceFeed.map {
                WorkspaceBarView(feed: $0, icons: icons, displayScreensID: screensID)
            }
            return NSPanelBarSurface(id: id, on: screen, leftContent: left)
        }
        coordinator.start()
        self.coordinator = coordinator

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
        coordinator?.stop()
    }
}
