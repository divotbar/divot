import Foundation

/// The immutable view state a renderer reads.
///
/// It carries the honest availability plus an optional snapshot and the display
/// options, so the same struct expresses "no manager installed" and "manager
/// available with these workspaces" without inventing placeholders.
public struct WorkspaceFeedState: Equatable, Sendable {
    public var availability: WorkspaceAvailability
    public var snapshot: WorkspaceSnapshot?
    public var options: WorkspaceDisplayOptions
    public var lastError: WorkspaceAdapterError?

    public init(availability: WorkspaceAvailability = .unavailable(.managerNotInstalled),
                snapshot: WorkspaceSnapshot? = nil,
                options: WorkspaceDisplayOptions = .default,
                lastError: WorkspaceAdapterError? = nil) {
        self.availability = availability
        self.snapshot = snapshot
        self.options = options
        self.lastError = lastError
    }

    public var isAvailable: Bool { availability.isAvailable }

    public var focusedWorkspaceID: WorkspaceID? { snapshot?.focusedWorkspaceID }

    /// Workspaces grouped per monitor and filtered by the current options.
    public var groups: [WorkspaceGrouping] {
        WorkspaceLayout.groups(snapshot: snapshot, options: options)
    }

    /// One honest line for diagnostics or the unavailable placeholder. Never a
    /// fabricated workspace count.
    public var statusSummary: String {
        if let lastError, !isAvailable {
            return lastError.summary
        }
        switch availability {
        case .available:
            let count = snapshot?.workspaces.count ?? 0
            return count == 0 ? "No workspaces reported" : "\(count) workspaces"
        case .unavailable(let reason):
            return reason.summary
        }
    }
}
