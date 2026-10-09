import Foundation

/// The result of choosing which manager Divot talks to.
public struct WorkspaceManagerSelection: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        /// The user's configured `widgets.workspaces.adapter`.
        case userOverride
        /// Exactly one supported manager is installed.
        case onlyInstalled
        /// Several are installed; the documented priority picked one.
        case priority
    }

    public let kind: WorkspaceManagerKind
    public let reason: Reason

    public init(kind: WorkspaceManagerKind, reason: Reason) {
        self.kind = kind
        self.reason = reason
    }
}

/// Deterministic manager choice. A user override always wins so a machine with
/// both AeroSpace and yabai is never switched out from under the user; the
/// chosen adapter then reports unavailable if that manager is not installed.
public enum WorkspaceManagerSelector {
    public static func select(preferred: WorkspaceManagerKind?,
                              installed: [WorkspaceManagerKind]) -> WorkspaceManagerSelection? {
        if let preferred {
            return WorkspaceManagerSelection(kind: preferred, reason: .userOverride)
        }
        let available = WorkspaceManagerKind.selectionPriority.filter(installed.contains)
        guard let first = available.first else { return nil }
        return WorkspaceManagerSelection(kind: first,
                                         reason: available.count > 1 ? .priority : .onlyInstalled)
    }
}
