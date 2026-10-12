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

private func app(_ name: String) -> WorkspaceApp {
    WorkspaceApp(identity: .init(bundleID: "com.example.\(name)", name: name), pid: 1, windowID: 1)
}

@MainActor
private func firstChip(_ id: String, in view: NSView) -> NSButton? {
    allSubviews(of: NSButton.self, in: view).first { $0.identifier?.rawValue == id }
}

/// A view rendered to a bitmap so a test can measure what is actually drawn,
/// not just where the layout manager places frames.
@MainActor
private func renderedBitmap(of view: NSView) -> NSBitmapImageRep? {
    guard view.bounds.width > 0, view.bounds.height > 0,
          let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: representation)
    return representation
}

private struct PixelBox {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var centreY: CGFloat { (CGFloat(minY) + CGFloat(maxY)) / 2 }
}

/// The bounding box of every pixel matching `predicate`, in bitmap
/// coordinates, or `nil` when nothing matches.
private func boundingBox(in representation: NSBitmapImageRep,
                         where predicate: (Int, Int, NSColor) -> Bool) -> PixelBox? {
    var box: PixelBox?
    for x in 0..<representation.pixelsWide {
        for y in 0..<representation.pixelsHigh {
            guard let color = representation.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                  predicate(x, y, color) else { continue }
            if var current = box {
                current.minX = min(current.minX, x)
                current.minY = min(current.minY, y)
                current.maxX = max(current.maxX, x)
                current.maxY = max(current.maxY, y)
                box = current
            } else {
                box = PixelBox(minX: x, minY: y, maxX: x, maxY: y)
            }
        }
    }
    return box
}

/// The solid-blue square `SolidIconProvider` draws, not the neutral text.
private func isAppIconPixel(_ color: NSColor) -> Bool {
    color.alphaComponent > 0.3 && color.blueComponent - color.redComponent > 0.2
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
@Test func workspaceChipAppIconsUseTheConfiguredAppIconSize() async {
    let apps = [WorkspaceApp(identity: .init(bundleID: "com.apple.Safari", name: "Safari"), pid: 1, windowID: 1)]
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), apps: apps)])

    // The left app icons use the configured size, which can differ from the
    // status icon size (#0052).
    let metrics = BarMetrics.scaled(textSize: 14, appIconSize: 22)
    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: SolidIconProvider(), displayScreensID: nil, metrics: metrics)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showAppIcons: true))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let chip = try! #require(firstChip("1", in: view))
    var attachmentBounds: CGRect?
    chip.attributedTitle.enumerateAttribute(.attachment,
                                            in: NSRange(location: 0, length: chip.attributedTitle.length)) { value, _, _ in
        if let attachment = value as? NSTextAttachment, attachmentBounds == nil {
            attachmentBounds = attachment.bounds
        }
    }
    #expect(attachmentBounds?.width == 22)
    #expect(attachmentBounds?.height == 22)
}

@MainActor
@Test func workspaceChipNumbersAndAppIconsShareAVerticalCentreAtEveryIconSize() async throws {
    // Smallest, default and largest configured app icon sizes (the range is
    // 8...24). The number and the icons must share one vertical centre line at
    // each, not only at the smallest size (#0055).
    for iconSize in [8.0, 16.0, 24.0] {
        let apps = [WorkspaceApp(identity: .init(bundleID: "com.apple.Safari", name: "Safari"),
                                 pid: 1,
                                 windowID: 1)]
        let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                         workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true, apps: apps)])

        let metrics = BarMetrics.scaled(textSize: 14, appIconSize: iconSize)
        let feed = WorkspaceFeed()
        let view = WorkspaceBarView(feed: feed,
                                    icons: SolidIconProvider(),
                                    displayScreensID: nil,
                                    theme: BarTheme.resolve(AppearanceConfiguration(family: .gruvbox), dark: true),
                                    metrics: metrics)
        view.frame = NSRect(x: 0, y: 0, width: 400, height: metrics.height)
        feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
                   eventSourceProvider: nil,
                   options: .init(showAppIcons: true))
        await feed.waitForPendingWork()
        view.layoutSubtreeIfNeeded()

        let chip = try #require(firstChip("1", in: view), "chip missing at icon size \(iconSize)")
        let bitmap = try #require(renderedBitmap(of: chip), "chip did not render at icon size \(iconSize)")

        // The icon is the solid blue square; the number is the text drawn ahead
        // of it. Measure their actual drawn vertical centres.
        let iconBox = try #require(boundingBox(in: bitmap, where: { _, _, color in isAppIconPixel(color) }),
                                   "no icon pixels at icon size \(iconSize)")
        let numberBox = try #require(boundingBox(in: bitmap, where: { x, _, color in
            // Restrict to the left of the icon so an anti-aliased icon edge can
            // never drag the number's measured centre toward the icon.
            x < iconBox.minX - 1 && color.alphaComponent > 0.5 && !isAppIconPixel(color)
        }), "no number pixels at icon size \(iconSize)")

        #expect(abs(numberBox.centreY - iconBox.centreY) <= 0.5,
                "number and icons out of line at icon size \(iconSize)")
    }
}

@MainActor
@Test func appIconBaselineOffsetKeepsIconsOnTheNumberLineAtEverySize() {
    let font = NSFont.systemFont(ofSize: BarMetrics.default.chipFontSize)
    for iconSize in [8.0, 16.0, 24.0] {
        let offset = WorkspaceBarView.appIconBaselineOffset(iconSize: iconSize,
                                                            rowHeight: BarMetrics.default.height,
                                                            font: font)
        // The number's line centre and the icon's centre, measured from the
        // baseline, must coincide within half a point.
        let numberCentre = (font.ascender + font.descender) / 2
        let iconCentre = offset + iconSize / 2
        #expect(abs(numberCentre - iconCentre) <= 0.5)
    }
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
    // Chips on so the focused workspace draws a background; this test verifies
    // the view renders content beyond the segment chrome, not the chip policy
    // (#0052).
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil,
                                enablesChipStyle: true)
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

@MainActor
@Test func nonFocusedChipsDistinguishOccupancyWithoutColorOrIcons() async {
    let workspaces = [
        Workspace(id: WorkspaceID("1"), isFocused: true, apps: [app("Safari")]),
        Workspace(id: WorkspaceID("2"), apps: [app("Safari")]),  // occupied
        Workspace(id: WorkspaceID("3"))                          // empty
    ]
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces)

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showAppIcons: false))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let focused = try! #require(firstChip("1", in: view))
    let occupied = try! #require(firstChip("2", in: view))
    let empty = try! #require(firstChip("3", in: view))

    // Focused state is the control's selected state, not a marker.
    #expect(focused.state == .on)
    #expect(focused.attributedTitle.string == "1")

    // Occupied and empty differ by a shape marker, never by text tint alone.
    #expect(occupied.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .occupied)))
    #expect(empty.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .empty)))
    #expect(occupied.attributedTitle.string != empty.attributedTitle.string)

    // The three occupancy markers are visually distinct from one another.
    let markers = [WorkspaceOccupancy.occupied, .empty, .unknown].map(WorkspaceBarView.occupancyMarker(for:))
    #expect(Set(markers).count == 3)
}

@MainActor
@Test func occupiedAndEmptyDotsShowByDefault() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true, apps: [app("Safari")]),
                                                  Workspace(id: WorkspaceID("2"), apps: [app("Safari")]),
                                                  Workspace(id: WorkspaceID("3"))])

    let feed = WorkspaceFeed()
    // Both markers default on, so the row keeps today's look.
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let occupied = try! #require(firstChip("2", in: view))
    let empty = try! #require(firstChip("3", in: view))
    #expect(occupied.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .occupied)))
    #expect(empty.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .empty)))
}

@MainActor
@Test func hidingTheOccupiedDotRemovesOnlyThatMarker() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true),
                                                  Workspace(id: WorkspaceID("2"), apps: [app("Safari")]),
                                                  Workspace(id: WorkspaceID("3"))])

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil,
                                showOccupiedDot: false)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let occupied = try! #require(firstChip("2", in: view))
    let empty = try! #require(firstChip("3", in: view))
    // The occupied marker is gone, but the name still identifies the workspace.
    #expect(!occupied.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .occupied)))
    #expect(occupied.attributedTitle.string.contains("2"))
    // The empty ring is untouched.
    #expect(empty.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .empty)))
}

@MainActor
@Test func hidingTheEmptyDotRemovesOnlyThatMarker() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true),
                                                  Workspace(id: WorkspaceID("2"), apps: [app("Safari")]),
                                                  Workspace(id: WorkspaceID("3"))])

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil,
                                showEmptyDot: false)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let occupied = try! #require(firstChip("2", in: view))
    let empty = try! #require(firstChip("3", in: view))
    // The empty ring is gone, but the name still identifies the workspace.
    #expect(!empty.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .empty)))
    #expect(empty.attributedTitle.string.contains("3"))
    // The occupied dot is untouched.
    #expect(occupied.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .occupied)))
}

@MainActor
@Test func unknownOccupancyChipsGetTheirOwnMarkerAndDescription() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), apps: [app("Safari")])],
                                     appsAvailable: false)
    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showAppIcons: false))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let chip = try! #require(firstChip("1", in: view))
    #expect(chip.attributedTitle.string.contains(WorkspaceBarView.occupancyMarker(for: .unknown)))
    #expect(chip.accessibilityLabel()?.contains("unknown") == true)
}

@MainActor
@Test func chipAccessibilityDescribesFocusAndOccupancy() async {
    let workspaces = [
        Workspace(id: WorkspaceID("1"), isFocused: true, apps: [app("Safari")]),
        Workspace(id: WorkspaceID("2"), apps: [app("Safari")]),  // occupied
        Workspace(id: WorkspaceID("3"))                          // empty
    ]
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces)

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 480, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showAppIcons: false))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    #expect(try! #require(firstChip("1", in: view)).accessibilityLabel()?.contains("focused") == true)
    #expect(try! #require(firstChip("2", in: view)).accessibilityLabel()?.contains("occupied") == true)
    #expect(try! #require(firstChip("3", in: view)).accessibilityLabel()?.contains("empty") == true)
}

@MainActor
@Test func occupancyMarkersKeepTheRowWithinItsWidth() async {
    let workspaces = (1...12).map { index in
        Workspace(id: WorkspaceID("\(index)"),
                  apps: index.isMultiple(of: 2) ? [app("Safari")] : [])
    }
    let snapshot = WorkspaceSnapshot(manager: .aerospace, workspaces: workspaces)

    let feed = WorkspaceFeed()
    let view = WorkspaceBarView(feed: feed, icons: NoIconProvider(), displayScreensID: nil)
    view.frame = NSRect(x: 0, y: 0, width: 220, height: 32)
    feed.start(adapter: StubAdapter(availability: .available(.full), snapshotValue: snapshot),
               eventSourceProvider: nil,
               options: .init(showAppIcons: false, showDetails: false))
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let stack = try! #require(allSubviews(of: NSStackView.self, in: view).first)
    // Marker glyphs are measured into each chip, so a marked row still fits and
    // never crosses the notch; crowded rows spill into the overflow menu.
    #expect(stack.frame.maxX <= view.bounds.width + 0.5)
    #expect(allSubviews(of: NSPopUpButton.self, in: view).count == 1)
}

