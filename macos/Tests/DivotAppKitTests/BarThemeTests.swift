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
private func themedWorkspaceSnapshot() -> WorkspaceSnapshot {
    WorkspaceSnapshot(manager: .aerospace,
                      workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true),
                                   Workspace(id: WorkspaceID("2"), apps: [WorkspaceApp(identity: .init(bundleID: "com.example.app", name: "App"), pid: 1, windowID: 1)]),
                                   Workspace(id: WorkspaceID("3"))])
}

@MainActor
@Test func selectedWorkspaceChipMatchesTheRightSideChipWhenChipStyleIsOn() async {
    let feed = WorkspaceFeed()
    let theme = BarTheme.resolve(gruvboxDark, dark: true)
    let view = WorkspaceBarView(feed: feed, icons: ThemeIconProvider(), displayScreensID: nil,
                                theme: theme, enablesChipStyle: true)
    view.frame = NSRect(x: 0, y: 0, width: 480, height: 32)
    feed.start(adapter: ThemeStubAdapter(snapshotValue: themedWorkspaceSnapshot()), eventSourceProvider: nil, options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let focused = try! #require(workspaceChip("1", in: view))
    let occupied = try! #require(workspaceChip("2", in: view))
    let empty = try! #require(workspaceChip("3", in: view))

    // Only the selected workspace draws the chip chrome, and it reuses the
    // right-side selected fill and rounded shape (#0059).
    #expect(colorMatches(focused.layer?.backgroundColor, theme.selected))
    #expect(focused.layer?.cornerRadius == 4)
    #expect(focused.layer?.borderWidth == 0)

    // Unselected workspaces never draw a chip: no fill, no border, no corners
    // (#0059).
    for chip in [occupied, empty] {
        #expect(colorMatches(chip.layer?.backgroundColor, .clear))
        #expect(chip.layer?.cornerRadius == 0)
        #expect(chip.layer?.borderWidth == 0)
    }
    #expect(nameColor(of: focused.attributedTitle) == theme.foreground)
    #expect(nameColor(of: occupied.attributedTitle) == theme.foreground)

    // The occupancy marker still carries the occupied/disabled role, so state
    // is never color alone.
    #expect(markerColor(of: occupied.attributedTitle) == theme.occupied)
    #expect(markerColor(of: empty.attributedTitle) == theme.disabled)
    #expect(focused.state == .on)
}

@MainActor
@Test func workspaceChipsHaveNoBoxWhenChipStyleIsOff() async {
    // The default has chips off: the focused workspace must not draw the old
    // bordered box that the other workspaces and right-side items lack (#0052).
    let feed = WorkspaceFeed()
    let theme = BarTheme.resolve(gruvboxDark, dark: true)
    let view = WorkspaceBarView(feed: feed, icons: ThemeIconProvider(), displayScreensID: nil, theme: theme)
    view.frame = NSRect(x: 0, y: 0, width: 480, height: 32)
    feed.start(adapter: ThemeStubAdapter(snapshotValue: themedWorkspaceSnapshot()), eventSourceProvider: nil, options: .default)
    await feed.waitForPendingWork()
    view.layoutSubtreeIfNeeded()

    let focused = try! #require(workspaceChip("1", in: view))
    let occupied = try! #require(workspaceChip("2", in: view))
    for chip in [focused, occupied] {
        #expect(colorMatches(chip.layer?.backgroundColor, .clear))
        #expect(chip.layer?.cornerRadius == 0)
        #expect(chip.layer?.borderWidth == 0)
    }
    // Focus remains the control's selected state and the semibold title.
    #expect(focused.state == .on)
}

@MainActor
@Test func workspaceChipStyleAddsTheSamePaddingAsTheRightSideChip() async throws {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true)])

    func makeChip(enablesChipStyle: Bool) async throws -> NSButton {
        let feed = WorkspaceFeed()
        let view = WorkspaceBarView(feed: feed, icons: ThemeIconProvider(), displayScreensID: nil,
                                    enablesChipStyle: enablesChipStyle)
        view.frame = NSRect(x: 0, y: 0, width: 480, height: 32)
        feed.start(adapter: ThemeStubAdapter(snapshotValue: snapshot), eventSourceProvider: nil, options: .default)
        await feed.waitForPendingWork()
        view.layoutSubtreeIfNeeded()
        return try #require(workspaceChip("1", in: view))
    }

    // A plain borderless button carries no padding; the selected chip adds
    // `chipPadding` on every side through the same `BarMetrics.chipSize` the
    // right-side chips use, so the two are the same size, not just the same
    // width (#0059).
    let compact = try await makeChip(enablesChipStyle: false)
    let chipped = try await makeChip(enablesChipStyle: true)
    let expected = BarMetrics.default.chipSize(contentWidth: compact.intrinsicContentSize.width,
                                               contentHeight: compact.intrinsicContentSize.height)
    #expect(chipped.intrinsicContentSize.width == expected.width)
    #expect(chipped.intrinsicContentSize.height == expected.height)
    #expect(chipped.intrinsicContentSize.width == compact.intrinsicContentSize.width + BarMetrics.chipPadding * 2)
    #expect(chipped.intrinsicContentSize.height == compact.intrinsicContentSize.height + BarMetrics.chipPadding * 2)
}

@MainActor
@Test func selectedWorkspaceChipOpacityStillApplies() async throws {
    let snapshot = WorkspaceSnapshot(manager: .aerospace,
                                     workspaces: [Workspace(id: WorkspaceID("1"), isFocused: true),
                                                  Workspace(id: WorkspaceID("2"))])
    let theme = BarTheme.resolve(gruvboxDark, dark: true)

    func chip(focusedAtOpacity opacity: Int) async throws -> (focused: NSButton, other: NSButton) {
        let feed = WorkspaceFeed()
        let view = WorkspaceBarView(feed: feed, icons: ThemeIconProvider(), displayScreensID: nil,
                                    theme: theme, enablesChipStyle: true, chipOpacity: opacity)
        view.frame = NSRect(x: 0, y: 0, width: 480, height: 32)
        feed.start(adapter: ThemeStubAdapter(snapshotValue: snapshot), eventSourceProvider: nil, options: .default)
        await feed.waitForPendingWork()
        view.layoutSubtreeIfNeeded()
        return (try #require(workspaceChip("1", in: view)), try #require(workspaceChip("2", in: view)))
    }

    // The one workspace chip that exists (the selected one) still fades with
    // the shared opacity setting (#0059).
    let op0 = try await chip(focusedAtOpacity: 0)
    #expect(colorMatches(op0.focused.layer?.backgroundColor, theme.selected))

    let op50 = try await chip(focusedAtOpacity: 50)
    #expect(colorMatches(op50.focused.layer?.backgroundColor, theme.selected.withAlphaComponent(0.5)))

    let op100 = try await chip(focusedAtOpacity: 100)
    #expect(colorMatches(op100.focused.layer?.backgroundColor, theme.selected.withAlphaComponent(0.0)))

    // An unselected workspace never draws a chip at any opacity.
    for result in [op0, op50, op100] {
        #expect(colorMatches(result.other.layer?.backgroundColor, .clear))
    }
}

@MainActor
@Test func rightSideChipsUseTheSharedOpacity() {
    let theme = BarTheme.resolve(gruvboxDark, dark: true)
    let presentation = WidgetPresentation(symbolName: "battery.25", text: "50%", accessibilityLabel: "Battery: 50%")

    func chip(opacity: Int) -> BarItemView {
        let view = BarItemView(metrics: .default, enablesChipStyle: true, chipOpacity: opacity)
        view.apply(theme: theme)
        view.update(presentation, action: .none)
        view.updateLayer()
        return view
    }

    // The right-side chips fade with the same shared value as the left workspaces
    // (#0052).
    #expect(colorMatches(chip(opacity: 0).layer?.backgroundColor, theme.selected))
    #expect(colorMatches(chip(opacity: 50).layer?.backgroundColor, theme.selected.withAlphaComponent(0.5)))
    #expect(colorMatches(chip(opacity: 100).layer?.backgroundColor, theme.selected.withAlphaComponent(0.0)))
}

// MARK: - Popover palette

/// A popover takes its colours and light/dark variant from the bar theme, so it
/// matches its bar and its text clears the audit — even when the bar's variant
/// differs from the app-wide appearance that used to drive the popover.
@MainActor
@Test func popoverPaletteComesFromTheBarTheme() {
    let dark = BarTheme.resolve(gruvboxDark, dark: true)
    #expect(dark.isDark)
    #expect(dark.popoverAppearance?.name == .darkAqua)

    let palette = dark.popoverPalette
    #expect(palette.background == dark.background)
    #expect(palette.label == dark.foreground)
    #expect(palette.secondary == dark.secondary)
    #expect(palette.link == dark.link)
    #expect(palette.separator == dark.border)

    let light = BarTheme.resolve(gruvboxDark, dark: false)
    #expect(!light.isDark)
    #expect(light.popoverAppearance?.name == .aqua)
    #expect(light.popoverPalette.background == light.background)
}

/// The native theme keeps macOS semantic roles (which adapt to the popover's
/// own appearance) and the system accent for its link.
@MainActor
@Test func nativePopoverPaletteKeepsSystemRoles() {
    let theme = BarTheme.resolve(.default, dark: true)
    let palette = theme.popoverPalette
    #expect(palette.background == .windowBackgroundColor)
    #expect(palette.label == .labelColor)
    #expect(palette.secondary == .secondaryLabelColor)
    #expect(palette.link == .controlAccentColor)
}

/// The family link role clears the AA text floor against the popover background,
/// which a raw accent need not: that is what stopped the footer link reading as
/// nearly invisible.
@MainActor
@Test func familyPopoverLinkClearsTheTextFloorAgainstTheBackground() {
    for family in [AppearanceConfiguration.Family.alpine, .gruvbox, .ayu, .dracula, .tokyoNight] {
        for variant in ThemeVariant.allCases {
            let dark = variant == .dark
            let theme = BarTheme.resolve(AppearanceConfiguration(family: family), dark: dark)
            let palette = theme.popoverPalette
            #expect(colorContrast(palette.link, palette.background) >= 4.5,
                    "\(family.rawValue) \(variant.rawValue) popover link contrast")
            #expect(colorContrast(palette.label, palette.background) >= 4.5)
            #expect(colorContrast(palette.secondary, palette.background) >= 3.0)
        }
    }
}

/// WCAG contrast between two NSColors, so the popover roles are checked with the
/// same math the theme audit uses.
private func colorContrast(_ a: NSColor, _ b: NSColor) -> Double {
    func luminance(_ color: NSColor) -> Double {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(srgb.redComponent)
            + 0.7152 * channel(srgb.greenComponent)
            + 0.0722 * channel(srgb.blueComponent)
    }
    let first = luminance(a)
    let second = luminance(b)
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)
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
