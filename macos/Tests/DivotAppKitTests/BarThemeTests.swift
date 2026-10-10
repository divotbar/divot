import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

private let gruvboxDark = AppearanceConfiguration(family: .gruvbox, mode: .dark)

@MainActor
@Test func nativeThemeUsesSystemColorsAndFollowsMaterial() {
    let theme = BarTheme.resolve(.default, dark: true)
    #expect(theme.usesSystemColors)
    #expect(theme.foreground == .labelColor)
    #expect(theme.selected == .selectedContentBackgroundColor)
    // Native material is translucent, but the flat chrome (#0025) paints the
    // solid background token edge to edge rather than a material blur.
    #expect(!theme.isOpaque)
    #expect(theme.layerBackground == .windowBackgroundColor)
    #expect(theme.layerBackground == theme.background)

    let opaque = BarTheme.resolve(AppearanceConfiguration(material: .opaque), dark: true)
    #expect(opaque.isOpaque)
}

@MainActor
@Test func familyThemeUsesResolvedPaletteColors() {
    var appearance = gruvboxDark
    appearance.material = .opaque
    let theme = BarTheme.resolve(appearance, dark: true)
    #expect(!theme.usesSystemColors)
    #expect(theme.foreground == NSColor(ThemeColor(hex: "#EBDBB2")!))
    #expect(theme.background == NSColor(ThemeColor(hex: "#282828")!))
    // The default accent adopts the family signature.
    #expect(theme.accent == NSColor(ThemeColor(hex: "#FABD2F")!))
    #expect(theme.isOpaque)
}

@MainActor
@Test func reducedTransparencyAndIncreasedContrastForceAnOpaqueBackground() {
    var appearance = gruvboxDark
    appearance.material = .native
    let theme = BarTheme.resolve(appearance, dark: true, increasedContrast: false, reduceTransparency: true)
    #expect(theme.isOpaque)
    #expect(theme.layerBackground != .clear)

    let contrast = BarTheme.resolve(appearance, dark: true, increasedContrast: true, reduceTransparency: false)
    #expect(contrast.isOpaque)
    #expect(contrast.borderWidth == 2)
}

@MainActor
@Test func barContentUsesThemedFlatBackgroundWithNoBevel() {
    let theme = BarTheme.resolve(AppearanceConfiguration(family: .gruvbox, mode: .dark, material: .opaque), dark: true)
    let content = BarContentView(side: .right, items: [.clock], theme: theme)
    content.frame = NSRect(x: 0, y: 0, width: 200, height: 32)
    content.updateLayer()
    // Flat chrome (#0025): the solid background token, square corners, and no
    // default border.
    #expect(colorMatches(content.layer?.backgroundColor, theme.background))
    #expect(content.layer?.cornerRadius == 0)
    #expect(content.layer?.borderWidth == 0)
}

@MainActor
@Test func barItemViewColorsFollowTheTheme() {
    let theme = BarTheme.resolve(gruvboxDark, dark: true)
    let view = BarItemView()
    view.apply(theme: theme)
    view.update(WidgetPresentation(symbolName: "wifi", text: "5G", accessibilityLabel: "Wi-Fi"), action: .none)
    let normal = try! #require(allTextFields(in: view).first)
    #expect(normal.textColor == theme.foreground)

    view.update(WidgetPresentation(symbolName: "wifi.slash", text: "", accessibilityLabel: "No network", isError: true),
                action: .none)
    #expect(normal.textColor == theme.error)
}

@MainActor
private func allTextFields(in view: NSView) -> [NSTextField] {
    view.subviews.flatMap { subview -> [NSTextField] in
        let nested = allTextFields(in: subview)
        return (subview as? NSTextField).map { [$0] + nested } ?? nested
    }
}

// MARK: Workspace chips

@MainActor
private final class ThemeIconProvider: WorkspaceIconProviding {
    func icon(for bundleID: String, pointSize: CGFloat) -> NSImage? { nil }
}

private struct ThemeStubAdapter: WorkspaceAdapting {
    let kind: WorkspaceManagerKind = .aerospace
    let availability: WorkspaceAvailability = .available(.full)
    let snapshotValue: WorkspaceSnapshot
    func capabilities() async -> WorkspaceAvailability { availability }
    func snapshot() async throws -> WorkspaceSnapshot { snapshotValue }
    func activate(_ workspace: WorkspaceID) async throws {}
    func stop() async {}
}

private func workspaceChip(_ id: String, in view: NSView) -> NSButton? {
    func find(_ view: NSView) -> [NSButton] {
        view.subviews.flatMap { subview -> [NSButton] in
            let nested = find(subview)
            return (subview as? NSButton).map { [$0] + nested } ?? nested
        }
    }
    return find(view).first { $0.identifier?.rawValue == id }
}

@MainActor
@Test func workspaceChipsCarryThemedSelectedAndOccupiedColors() async {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true),
                                                  Workspace(id: WorkspaceID("2"), apps: [WorkspaceApp(identity: .init(bundleID: "com.example.app", name: "App"), pid: 1, windowID: 1)]),
                                                  Workspace(id: WorkspaceID("3"))])
    let feed = WorkspaceFeed()
    let theme = BarTheme.resolve(gruvboxDark, dark: true)
    let view = WorkspaceBarView(feed: feed, icons: ThemeIconProvider(), displayScreensID: nil, theme: theme)
    view.frame = NSRect(x: 0, y: 0, width: 480, height: 32)
    feed.start(adapter: ThemeStubAdapter(snapshotValue: snapshot), eventSourceProvider: nil, options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let focused = try! #require(workspaceChip("1", in: view))
    let occupied = try! #require(workspaceChip("2", in: view))
    let empty = try! #require(workspaceChip("3", in: view))

    // Focused uses the family selected background, not the system accent.
    #expect(colorMatches(focused.layer?.backgroundColor, theme.selected))
    #expect(colorMatches(focused.layer?.borderColor, theme.accent))
    #expect(colorMatches(occupied.layer?.backgroundColor, .clear))

    // Flat chrome (#0025): square chips with a flat focused stroke.
    #expect(focused.layer?.cornerRadius == 0)
    #expect(occupied.layer?.cornerRadius == 0)
    #expect(focused.layer?.borderWidth == 1)
    #expect(occupied.layer?.borderWidth == 0)

    // The occupancy marker carries the occupied/disabled role; the name stays in
    // the foreground so state is never color alone.
    #expect(markerColor(of: occupied.attributedTitle) == theme.occupied)
    #expect(markerColor(of: empty.attributedTitle) == theme.disabled)
    #expect(nameColor(of: occupied.attributedTitle) == theme.foreground)
    #expect(focused.state == .on)
}

private func markerColor(of string: NSAttributedString) -> NSColor? {
    guard string.length > 0 else { return nil }
    return string.attribute(.foregroundColor, at: string.length - 1, effectiveRange: nil) as? NSColor
}

private func nameColor(of string: NSAttributedString) -> NSColor? {
    string.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
}

/// Compare a layer's `CGColor` against an `NSColor` without tripping on color
/// space conversions.
private func colorMatches(_ cg: CGColor?, _ color: NSColor) -> Bool {
    guard let cg, let lhs = NSColor(cgColor: cg)?.usingColorSpace(.sRGB),
          let rhs = color.usingColorSpace(.sRGB) else { return false }
    return abs(lhs.redComponent - rhs.redComponent) < 0.002
        && abs(lhs.greenComponent - rhs.greenComponent) < 0.002
        && abs(lhs.blueComponent - rhs.blueComponent) < 0.002
        && abs(lhs.alphaComponent - rhs.alphaComponent) < 0.002
}
