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

    /// Workspaces to draw on one display, in manager order.
    ///
    /// When the manager reported a screen index for a workspace and Divot knows
    /// which screen it is drawing, only that monitor's workspaces are returned.
    /// An unknown or absent mapping falls back to every workspace so the row is
    /// never silently empty on a single-display setup.
    public static func workspaces(forScreensID screensID: Int?,
                                  in snapshot: WorkspaceSnapshot?,
                                  options: WorkspaceDisplayOptions) -> [Workspace] {
        let groups = groups(snapshot: snapshot, options: options)
        guard let screensID else { return groups.flatMap(\.workspaces) }
        let attributed = groups.filter { $0.monitor?.screensID == screensID }
        guard !attributed.isEmpty else { return groups.flatMap(\.workspaces) }
        return attributed.flatMap(\.workspaces)
    }

    /// Keep a leading run of workspaces that fits `availableWidth`, measuring a
    /// separator between them. The focused workspace is always kept visible when
    /// it can be: if it would overflow, it trades places with the last
    /// non-focused visible workspace.
    ///
    /// The returned row never exceeds `availableWidth`. If an item is hidden the
    /// caller must show an overflow control, so `overflowWidth` (the control's
    /// own width) is reserved before fitting. A single label wider than the whole
    /// row is hidden rather than allowed to cross the camera housing.
    public static func fit(_ workspaces: [Workspace],
                           width: (Workspace) -> CGFloat,
                           availableWidth: CGFloat,
                           spacing: CGFloat,
                           overflowWidth: CGFloat = 0) -> WorkspaceOverflow {
        guard !workspaces.isEmpty else { return WorkspaceOverflow(visible: [], hidden: []) }
        let spacing = max(0, spacing)
        let availableWidth = max(0, availableWidth)
        let widths = workspaces.map { max(0, width($0)) }

        let totalAll = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        if totalAll <= availableWidth {
            return WorkspaceOverflow(visible: workspaces, hidden: [])
        }

        // Something will overflow, so reserve the overflow control's width first.
        let budget = max(0, availableWidth - max(0, overflowWidth))
        var visibleCount = 0
        var used: CGFloat = 0
        for itemWidth in widths {
            let needed = visibleCount == 0 ? itemWidth : itemWidth + spacing
            guard used + needed <= budget else { break }
            used += needed
            visibleCount += 1
        }

        var visible = Array(workspaces.prefix(visibleCount))
        var hidden = Array(workspaces.dropFirst(visibleCount))

        // Pin focus only when the swap still fits: workspace labels differ in
        // width, so a wider focused item could otherwise exceed the budget.
        var widthByID: [WorkspaceID: CGFloat] = [:]
        for (index, workspace) in workspaces.enumerated() { widthByID[workspace.id] = widths[index] }
        if let focused = workspaces.first(where: \.isFocused),
           !visible.contains(where: { $0.id == focused.id }),
           let focusedWidth = widthByID[focused.id] {
            let currentWidth = visible.reduce(CGFloat(0)) { $0 + (widthByID[$1.id] ?? 0) }
                + spacing * CGFloat(max(0, visible.count - 1))
            for replaceIndex in visible.indices.reversed() where !visible[replaceIndex].isFocused {
                let candidate = visible[replaceIndex]
                let candidateWidth = widthByID[candidate.id] ?? 0
                if currentWidth - candidateWidth + focusedWidth <= budget + 0.0001 {
                    visible[replaceIndex] = focused
                    hidden.removeAll { $0.id == focused.id }
                    hidden.insert(candidate, at: 0)
                    break
                }
            }
        }

        return WorkspaceOverflow(visible: visible, hidden: hidden)
    }
}
