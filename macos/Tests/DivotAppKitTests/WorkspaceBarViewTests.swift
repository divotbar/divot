import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

@MainActor
private final class NoIconProvider: WorkspaceIconProviding {
    func icon(for bundleID: String, pointSize: CGFloat) -> NSImage? { nil }
}

/// Returns a real, non-empty image for any bundle id so attachment rendering can
/// be exercised without a live app.
@MainActor
private final class SolidIconProvider: WorkspaceIconProviding {
    func icon(for bundleID: String, pointSize: CGFloat) -> NSImage? {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
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
private func allSubviews<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
    view.subviews.flatMap { subview -> [T] in
        let nested = allSubviews(of: type, in: subview)
        return (subview as? T).map { [$0] + nested } ?? nested
    }
}

private func attachmentCount(in string: NSAttributedString) -> Int {
    var count = 0
    string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) { value, _, _ in
        if value != nil { count += 1 }
    }
    return count
}

@MainActor
@Test func workspaceBarViewBuildsWithoutAManager() {
    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: nil, eventSourceProvider: nil, options: .default)
    view.layoutSubtreeIfNeeded()
    // Nothing is fabricated: an unavailable manager draws no workspace chips.
    #expect(allSubviews(of: NSButton.self, in: view).isEmpty)
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

    let titles = allSubviews(of: NSButton.self, in: view).compactMap { $0.identifier?.rawValue }
    #expect(titles.contains("1"))
    #expect(titles.contains("2"))
    #expect(titles.contains("3"))
    // The focused workspace is selected, not just colored.
    #expect(allSubviews(of: NSButton.self, in: view).first { $0.identifier?.rawValue == "1" }?.state == .on)
}

@MainActor
@Test func workspaceBarViewDrawsEveryDeduplicatedAppIcon() async {
    let apps = [
        WorkspaceApp(identity: .init(bundleID: "com.apple.Safari", name: "Safari"), pid: 1, windowID: 1),
        WorkspaceApp(identity: .init(bundleID: "com.apple.Terminal", name: "Terminal"), pid: 2, windowID: 2),
        WorkspaceApp(identity: .init(bundleID: "com.apple.Safari", name: "Safari"), pid: 3, windowID: 3)
    ]
    let workspace = Workspace(id: WorkspaceID("1"), apps: apps)
    #expect(workspace.apps.count == 2)  // Safari is deduplicated

    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: [workspace])
    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: SolidIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showAppIcons: true))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let chip = try! #require(allSubviews(of: NSButton.self, in: view).first { $0.identifier?.rawValue == "1" })
    // One attachment per deduplicated app (two), not just the first.
    #expect(attachmentCount(in: chip.attributedTitle) == 2)
}

@MainActor
private func uniqueColors(in image: NSImage) -> Int {
    guard let tiff = image.tiffRepresentation, let representation = NSBitmapImageRep(data: tiff) else { return 0 }
    var colors = Set<String>()
    for x in stride(from: 0, to: representation.pixelsWide, by: 2) {
        for y in stride(from: 0, to: representation.pixelsHigh, by: 2) {
            if let color = representation.colorAt(x: x, y: y), color.alphaComponent > 0.05 {
                colors.insert("\(color.redComponent),\(color.greenComponent),\(color.blueComponent)")
            }
        }
    }
    return colors.count
}

@MainActor
@Test func workspaceBarViewDrawsContentBeyondTheChrome() async {
    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    view.wantsLayer = true

    // Unavailable: only the segment chrome is drawn.
    feed.start(adapter: nil, eventSourceProvider: nil, options: .default)
    view.layoutSubtreeIfNeeded()
    let emptyImage = try! #require(view.renderPreviewImage())
    let emptyColors = uniqueColors(in: emptyImage)

    // Populated: each workspace chip adds its own drawing.
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true),
                                                  Workspace(id: WorkspaceID("2"))])
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()
    let populatedImage = try! #require(view.renderPreviewImage())

    #expect(uniqueColors(in: populatedImage) > emptyColors)
}

@MainActor
@Test func workspaceBarViewKeepsTheFrontProgramWhenChipsOverflow() async {
    let workspaces = (1...12).map { Workspace(id: WorkspaceID("\($0)"), isFocused: $0 == 1) }
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces)

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 240, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showDetails: true))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    // A crowded row spills workspaces into the overflow control instead of
    // dropping the current-program label.
    #expect(allSubviews(of: NSPopUpButton.self, in: view).count == 1)
    let label = try! #require(allSubviews(of: NSTextField.self, in: view).first)
    #expect(!label.stringValue.isEmpty)
    #expect(label.frame.width > 0)
}

