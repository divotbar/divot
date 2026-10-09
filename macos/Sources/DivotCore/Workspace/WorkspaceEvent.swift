import Foundation

/// A manager event that may invalidate the current snapshot.
///
/// These mirror AeroSpace's documented `subscribe` events; a later yabai adapter
/// maps its own events onto the same cases. Unknown events are preserved rather
/// than dropped so a newer manager does not silently stop refreshing.
public enum WorkspaceEvent: Equatable, Sendable {
    case focusChanged(workspace: WorkspaceID)
    case focusedMonitorChanged(monitorID: Int, workspace: WorkspaceID?)
    case focusedWorkspaceChanged(workspace: WorkspaceID, previous: WorkspaceID?)
    case windowDetected(workspace: WorkspaceID?, appBundleID: String?, appName: String?)
    case modeChanged(String)
    case bindingTriggered(String)
    case unknown(String)

    /// Whether this event can change workspace membership, focus or monitor
    /// attribution and therefore warrants a fresh snapshot. Mode and binding
    /// changes do not, so they never trigger a read.
    public var requiresSnapshotRefresh: Bool {
        switch self {
        case .focusChanged, .focusedMonitorChanged, .focusedWorkspaceChanged, .windowDetected:
            return true
        case .modeChanged, .bindingTriggered:
            return false
        case .unknown:
            // Forward compatible: an unrecognized event may carry new state.
            return true
        }
    }
}
