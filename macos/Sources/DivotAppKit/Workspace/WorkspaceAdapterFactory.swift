import Foundation
import DivotCore

/// Builds the concrete adapter and event source for a selected manager.
///
/// AeroSpace is the only shipped adapter today; yabai returns `nil`, which the
/// feed turns into the honest unavailable state instead of a stub. This keeps
/// the manager-selection policy in one place for the app and `divot --report`.
public enum WorkspaceAdapterFactory {
    public static func installedManagers(aeroSpacePath: String? = AeroSpaceBinaryLocator.locate()) -> [WorkspaceManagerKind] {
        var installed: [WorkspaceManagerKind] = []
        if aeroSpacePath != nil { installed.append(.aerospace) }
        return installed
    }

    public static func makeAdapter(for kind: WorkspaceManagerKind,
                                   runner: WorkspaceProcessRunning = ProcessWorkspaceRunner()) -> WorkspaceAdapting? {
        switch kind {
        case .aerospace:
            return AeroSpaceWorkspaceAdapter(executablePath: AeroSpaceBinaryLocator.locate(), runner: runner)
        case .yabai:
            // Second adapter milestone; no capability is claimed here.
            return nil
        }
    }

    public static func makeEventSource(for kind: WorkspaceManagerKind) -> WorkspaceEventSource? {
        switch kind {
        case .aerospace:
            guard let path = AeroSpaceBinaryLocator.locate() else { return nil }
            return AeroSpaceSubscription(executablePath: path)
        case .yabai:
            return nil
        }
    }

    /// Resolve the manager and both collaborators in one call.
    public static func resolve(preferred: WorkspaceManagerKind?,
                               runner: WorkspaceProcessRunning = ProcessWorkspaceRunner()) -> (selection: WorkspaceManagerSelection?, adapter: WorkspaceAdapting?, eventSource: WorkspaceEventSource?) {
        let selection = WorkspaceManagerSelector.select(preferred: preferred,
                                                        installed: installedManagers())
        guard let selection else { return (nil, nil, nil) }
        return (selection,
                makeAdapter(for: selection.kind, runner: runner),
                makeEventSource(for: selection.kind))
    }
}
