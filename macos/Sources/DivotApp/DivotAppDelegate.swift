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

        let adapter = MenuBarObservationAdapter(provider: NSScreenGeometryProvider(),
                                                probe: AXSystemMenuBarProbe())
        let coordinator = DisplayCoordinator(adapter: adapter) { id, screen in
            NSPanelBarSurface(id: id, on: screen)
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

    /// Start the workspace provider. Workspace indicators render in their own
    /// milestone; today this establishes the event-driven state and reports an
    /// honest unavailable reason when no supported manager is present.
    private func startWorkspaceFeed() {
        let feed = WorkspaceFeed()
        feed.onChange = { [weak self] state in
            guard let self, !self.reportedWorkspaceAvailability else { return }
            self.reportedWorkspaceAvailability = true
            if let reason = state.availability.unavailability {
                FileHandle.standardError.write(
                    Data("divot: workspaces: \(reason.summary).\n".utf8))
            }
        }
        let resolved = WorkspaceAdapterFactory.resolve(preferred: nil)
        feed.start(adapter: resolved.adapter,
                   eventSource: resolved.eventSource,
                   options: .default)
        workspaceFeed = feed
    }

    public func applicationWillTerminate(_ notification: Notification) {
        workspaceFeed?.stop()
        coordinator?.stop()
    }
}
