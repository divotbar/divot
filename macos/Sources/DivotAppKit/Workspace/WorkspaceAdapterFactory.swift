import Foundation
import DivotCore

/// Builds the concrete adapter and event source for a selected manager.
///
/// Both shipped adapters live behind the same manager-selection policy so the
/// app and `divot --report` cannot disagree about which manager they are talking
/// to. The policy itself is in `DivotCore`.
public enum WorkspaceAdapterFactory {
    public static func installedManagers(aeroSpacePath: String? = AeroSpaceBinaryLocator.locate(),
                                         yabaiPath: String? = YabaiBinaryLocator.locate()) -> [WorkspaceManagerKind] {
        var installed: [WorkspaceManagerKind] = []
        if aeroSpacePath != nil { installed.append(.aerospace) }
        if yabaiPath != nil { installed.append(.yabai) }
        return installed
    }

    /// Build the adapter for `kind`. `displayIndex` is supplied by the main
    /// actor so yabai's `CGDirectDisplayID`s can be mapped to screens; without
    /// it the adapter still works and simply reports no screen mapping.
    public static func makeAdapter(for kind: WorkspaceManagerKind,
                                   runner: WorkspaceProcessRunning = ProcessWorkspaceRunner(),
                                   processIdentity: WorkspaceProcessIdentityResolving? = RunningApplicationIdentityResolver(),
                                   displayIndex: WorkspaceDisplayIndexResolving? = nil) -> WorkspaceAdapting? {
        switch kind {
        case .aerospace:
            return AeroSpaceWorkspaceAdapter(executablePath: AeroSpaceBinaryLocator.locate(), runner: runner)
        case .yabai:
            return YabaiWorkspaceAdapter(executablePath: YabaiBinaryLocator.locate(),
                                         runner: runner,
                                         processIdentity: processIdentity,
                                         displayIndex: displayIndex)
        }
    }

    public static func makeEventSource(for kind: WorkspaceManagerKind) -> WorkspaceEventSource? {
        switch kind {
        case .aerospace:
            guard let path = AeroSpaceBinaryLocator.locate() else { return nil }
            return AeroSpaceSubscription(executablePath: path)
        case .yabai:
            // yabai exposes no persistent event stream. Its documented signals
            // run callbacks rather than streaming; the feed reads once on start
            // and refreshes on demand, and no stub stream is fabricated here.
            return nil
        }
    }

    /// Resolve the manager and its collaborators in one call.
    public static func resolve(preferred: WorkspaceManagerKind?,
                               runner: WorkspaceProcessRunning = ProcessWorkspaceRunner(),
                               displayIndex: WorkspaceDisplayIndexResolving? = nil) -> (selection: WorkspaceManagerSelection?, adapter: WorkspaceAdapting?, eventSource: WorkspaceEventSource?) {
        let selection = WorkspaceManagerSelector.select(preferred: preferred,
                                                        installed: installedManagers())
        guard let selection else { return (nil, nil, nil) }
        return (selection,
                makeAdapter(for: selection.kind, runner: runner, displayIndex: displayIndex),
                makeEventSource(for: selection.kind))
    }
}
