import Foundation

/// Workspaces attributed to one monitor, already filtered by display options.
public struct WorkspaceGrouping: Equatable, Sendable {
    /// `nil` when the manager did not attribute the group to a monitor.
    public let monitor: WorkspaceMonitor?
    public let workspaces: [Workspace]

    public init(monitor: WorkspaceMonitor?, workspaces: [Workspace]) {
        self.monitor = monitor
        self.workspaces = workspaces
    }

    public var isEmpty: Bool { workspaces.isEmpty }
}

/// The split between workspaces that fit and those that do not.
///
/// Overflow is a designed menu, never a squashed or notch-crossing row.
public struct WorkspaceOverflow: Equatable, Sendable {
    public let visible: [Workspace]
    public let hidden: [Workspace]

    public init(visible: [Workspace], hidden: [Workspace]) {
        self.visible = visible
        self.hidden = hidden
    }

    public var overflowCount: Int { hidden.count }
    public var hasOverflow: Bool { !hidden.isEmpty }
}

/// Pure layout rules for the workspace group: options filtering, per-monitor
/// grouping, app-icon selection and width overflow.
///
/// Measurement itself is the renderer's job; it supplies a width per workspace
/// so this stays free of font and text machinery.
public enum WorkspaceLayout {
    /// Filter by `showEmpty`, then group by monitor. Monitor order is numeric and
    /// stable; workspaces with no monitor attribution come last. Workspace order
    /// within a group is the manager's own order, never alphabetical.
    public static func groups(snapshot: WorkspaceSnapshot?,
                              options: WorkspaceDisplayOptions) -> [WorkspaceGrouping] {
        guard let snapshot else { return [] }
        let filtered = snapshot.workspaces.filter { options.showEmpty || $0.isOccupied }

        var order: [WorkspaceMonitor?] = []
        var byMonitor: [WorkspaceMonitor?: [Workspace]] = [:]
        for workspace in filtered {
            if byMonitor[workspace.monitor] == nil { order.append(workspace.monitor) }
            byMonitor[workspace.monitor, default: []].append(workspace)
        }

        let attributed = order.compactMap { $0 }.sorted()
        let unattributed = order.contains(where: { $0 == nil }) ? [Optional<WorkspaceMonitor>.none] : []
        return (attributed.map { Optional($0) } + unattributed).map { monitor in
            WorkspaceGrouping(monitor: monitor, workspaces: byMonitor[monitor] ?? [])
        }
    }

    /// The app identities to render for one workspace, honoring the icon toggle
    /// and the optional per-workspace cap. Already deduplicated by the model.
    public static func displayApps(for workspace: Workspace,
                                   options: WorkspaceDisplayOptions) -> [WorkspaceAppIdentity] {
        guard options.showAppIcons else { return [] }
        var apps = workspace.appIdentities
        if let cap = options.maxAppIconsPerWorkspace, cap >= 0, apps.count > cap {
            apps = Array(apps.prefix(cap))
        }
        return apps
    }

    /// Keep a leading run of workspaces that fits `availableWidth`, measuring a
    /// separator between them. The focused workspace is always kept visible: if
    /// it would overflow, it trades places with the last non-focused visible
    /// workspace so the row never exceeds the width it was given and never
    /// crosses the camera housing.
    public static func fit(_ workspaces: [Workspace],
                           width: (Workspace) -> CGFloat,
                           availableWidth: CGFloat,
                           spacing: CGFloat) -> WorkspaceOverflow {
        guard !workspaces.isEmpty else { return WorkspaceOverflow(visible: [], hidden: []) }
        let spacing = max(0, spacing)
        let availableWidth = max(0, availableWidth)

        var visible: [Workspace] = []
        var used: CGFloat = 0
        for workspace in workspaces {
            let itemWidth = max(0, width(workspace))
            let needed = visible.isEmpty ? itemWidth : itemWidth + spacing
            // Always keep the first item; from then on a row must fit entirely.
            if visible.isEmpty || used + needed <= availableWidth {
                visible.append(workspace)
                used += needed
            } else {
                break
            }
        }

        var hidden = Array(workspaces.dropFirst(visible.count))

        if let focused = workspaces.first(where: \.isFocused),
           !visible.contains(where: { $0.id == focused.id }),
           let replaceIndex = visible.lastIndex(where: { !$0.isFocused }) {
            let displaced = visible[replaceIndex]
            visible[replaceIndex] = focused
            hidden.removeAll { $0.id == focused.id }
            hidden.insert(displaced, at: 0)
        }

        return WorkspaceOverflow(visible: visible, hidden: hidden)
    }
}
