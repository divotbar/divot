import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

@MainActor
private final class NoIconProvider: WorkspaceIconProviding {
    func icon(for bundleID: String, pointSize: CGFloat) -> NSImage? { nil }
}

private struct StubAdapter: WorkspaceAdapting {
    let kind: WorkspaceManagerKind = .aerospace
    let availability: WorkspaceAvailability
    let snapshotValue: WorkspaceSnapshot

    func capabilities() async -> WorkspaceAvailability { availability }
    func snapshot() async throws -> WorkspaceSnapshot { snapshotValue }
    func activate(_ workspace: WorkspaceID) async throws {}
    func stop() async {}
}

@MainActor
private func allButtons(in view: NSView) -> [NSButton] {
    view.subviews.flatMap { subview -> [NSButton] in
        let nested = allButtons(in: subview)
        return (subview as? NSButton).map { [$0] + nested } ?? nested
    }
}

@MainActor
@Test func workspaceBarViewBuildsWithoutAManager() {
    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: nil, eventSourceProvider: nil, options: .default)
    view.layoutSubtreeIfNeeded()
    // Nothing is fabricated: an unavailable manager draws no workspace chips.
    #expect(allButtons(in: view).isEmpty)
}

@MainActor
@Test func workspaceBarViewRendersAWorkspaceChipForEachVisibleWorkspace() async {
    let workspaces = [
        Workspace(id: WorkspaceID("1"), isFocused: true, monitor: WorkspaceMonitor(id: 1, name: "Built-in")),
        Workspace(id: WorkspaceID("2"), monitor: WorkspaceMonitor(id: 1, name: "Built-in")),
        Workspace(id: WorkspaceID("3"), monitor: WorkspaceMonitor(id: 1, name: "Built-in"))
    ]
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces)

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: 1)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let titles = allButtons(in: view).compactMap(\.title)
    #expect(titles.contains("1"))
    #expect(titles.contains("2"))
    #expect(titles.contains("3"))
    // The focused workspace is selected, not just colored.
    #expect(allButtons(in: view).first { $0.title == "1" }?.state == .on)
    // Workspace filtering by screen index is respected.
    #expect(allButtons(in: view).allSatisfy { $0.title != "M" })
}
