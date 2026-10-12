import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Every `NSTextField` in a view tree, so a rendering test can inspect the label
/// each item actually draws.
@MainActor
private func textFields(in view: NSView) -> [NSTextField] {
    view.subviews.flatMap { subview -> [NSTextField] in
        let nested = textFields(in: subview)
        return (subview as? NSTextField).map { [$0] + nested } ?? nested
    }
}

/// A label is only guaranteed to draw without an ellipsis when its frame is at
/// least the cell's own measured size. `intrinsicContentSize` omits the cell
/// padding (`cell.cellSize`), which is exactly what used to clip "Muted" to
/// "Mut…" and "Ghostty" to "Ghos…".
@MainActor
private func expectNoTruncation(_ field: NSTextField, _ label: String) {
    let needed = field.cell?.cellSize.width ?? 0
    #expect(field.frame.width >= needed - 0.5,
            "\(label): frame \(field.frame.width) < cell \(needed)")
}

/// Every `NSImageView` in a view tree, so a rendering test can inspect the icon
/// the bar item actually resolved.
@MainActor
private func imageViews(in view: NSView) -> [NSImageView] {
    view.subviews.flatMap { subview -> [NSImageView] in
        let nested = imageViews(in: subview)
        return (subview as? NSImageView).map { [$0] + nested } ?? nested
    }
}

@MainActor
@Test func batteryItemShowsBoltWhileChargingAndPlainSymbolOtherwise() {
    func presentation(charging: Bool) -> WidgetPresentation {
        WidgetPresenter.present(
            id: .battery,
            state: WidgetState(id: .battery, revision: 1,
                               content: .battery(BatterySnapshot(presence: .internalBattery,
                                                                 percentage: 80,
                                                                 isCharging: charging))))
    }

    // While charging the outline is the plain full battery and the bolt is a
    // separate element over it, so the outline keeps the bar's normal colour
    // (#0058).
    let charging = BarItemView()
    charging.update(presentation(charging: true), action: .none)
    #expect(charging.displayedSymbolName == "battery.100")
    #expect(charging.displayedBadgeSymbolName == "bolt.fill")
    #expect(charging.isBadgeVisible)
    #expect(imageViews(in: charging).contains { !$0.isHidden && $0.image != nil })

    // Not charging: the same plain battery symbol and no bolt at all.
    let plain = BarItemView()
    plain.update(presentation(charging: false), action: .none)
    #expect(plain.displayedSymbolName == "battery.75")
    #expect(plain.displayedBadgeSymbolName == nil)
    #expect(!plain.isBadgeVisible)
    #expect(imageViews(in: plain).contains { !$0.isHidden && $0.image != nil })

    // A live switch on the same view re-resolves the icon, so the bolt appears
    // and disappears with the power source.
    charging.update(presentation(charging: false), action: .none)
    #expect(charging.displayedBadgeSymbolName == nil)
    #expect(!charging.isBadgeVisible)
    charging.update(presentation(charging: true), action: .none)
    #expect(charging.displayedBadgeSymbolName == "bolt.fill")
    #expect(charging.isBadgeVisible)
}

/// Only the charging bolt takes the theme's accent green: the battery outline
/// and the label keep the foreground colour, and with no charge there is no
/// green at all (#0058).
@MainActor
@Test func onlyTheChargingBoltUsesTheThemeAccentGreen() {
    // The built-in theme accent is the fixed green the bolt draws with.
    let theme = BarTheme.systemDefault
    let green = try! #require(NSColor(hexString: "#D6F58A"))
    #expect(theme.accent.isEqual(green))

    func presentation(charging: Bool) -> WidgetPresentation {
        WidgetPresenter.present(
            id: .battery,
            state: WidgetState(id: .battery, revision: 1,
                               content: .battery(BatterySnapshot(presence: .internalBattery,
                                                                 percentage: 80,
                                                                 isCharging: charging))))
    }

    let charging = BarItemView()
    charging.apply(theme: theme)
    charging.update(presentation(charging: true), action: .none)
    let badgeTint = try! #require(charging.badgeTintColor)
    #expect(badgeTint.isEqual(theme.accent))
    // The outline and the label are the foreground, never the bolt green.
    #expect(charging.iconTintColor.isEqual(theme.foreground))
    #expect(charging.itemTextColor.isEqual(theme.foreground))
    #expect(!charging.iconTintColor.isEqual(theme.accent))
    #expect(!charging.itemTextColor.isEqual(theme.accent))

    // Not charging: no bolt, so nothing carries the accent green.
    let plain = BarItemView()
    plain.apply(theme: theme)
    plain.update(presentation(charging: false), action: .none)
    #expect(plain.badgeTintColor == nil)
    #expect(!plain.iconTintColor.isEqual(theme.accent))
    #expect(!plain.itemTextColor.isEqual(theme.accent))
}

/// The keep-awake cup is the battery item's only state mark. A second mark (a
/// green dot drawn over the cup) must never appear, and with keep-awake off the
/// item draws no indicator at all, so another app's sleep assertion cannot
/// light one up.
@MainActor
@Test func batteryItemDrawsOnlyTheKeepAwakeCupAsItsStateMark() {
    func presentation(keepingAwake: Bool) -> WidgetPresentation {
        WidgetPresenter.present(
            id: .battery,
            state: WidgetState(id: .battery, revision: 1,
                               content: .battery(BatterySnapshot(presence: .internalBattery,
                                                                 percentage: 63,
                                                                 isCharging: false,
                                                                 isKeepingAwake: keepingAwake))))
    }

    let on = BarItemView()
    on.update(presentation(keepingAwake: true), action: .toggleKeepAwake)
    #expect(on.displayedIndicatorSymbolName == "cup.and.saucer.fill")
    #expect(on.isIndicatorVisible)
    // Exactly two visible images: the battery icon and the cup. Nothing else
    // (no dot, badge, or bezel) is drawn over the cup.
    #expect(imageViews(in: on).filter { !$0.isHidden && $0.image != nil }.count == 2)

    let off = BarItemView()
    off.update(presentation(keepingAwake: false), action: .toggleKeepAwake)
    #expect(off.displayedIndicatorSymbolName == nil)
    #expect(!off.isIndicatorVisible)
    // Only the battery icon remains; no stale cup or dot.
    #expect(imageViews(in: off).filter { !$0.isHidden && $0.image != nil }.count == 1)
}

@MainActor
@Test func nativeStatusSymbolsUseTheBarIconSizeAndScaleWithTextSize() {
    func resolvedImage(_ view: BarItemView) -> NSImage? {
        imageViews(in: view).first { !$0.isHidden && $0.image != nil }?.image
    }

    let presentations: [(BarItemID, WidgetPresentation)] = [
        (.battery, WidgetPresentation(symbolName: "battery.100", text: "80%", accessibilityLabel: "Battery: 80%")),
        (.network, WidgetPresentation(symbolName: "wifi", text: "", accessibilityLabel: "Wi-Fi")),
        (.volume, WidgetPresentation(symbolName: "speaker.wave.2.fill", text: "40%", accessibilityLabel: "Volume: 40%"))
    ]
    let smallest = BarMetrics.scaled(textSize: 10)   // icon 12 pt
    let largest = BarMetrics.scaled(textSize: 20)     // icon 22 pt
    #expect(smallest.statusSymbolPointSize == 12)
    #expect(largest.statusSymbolPointSize == 22)

    for (item, presentation) in presentations {
        let smallView = BarItemView(metrics: smallest, item: item)
        smallView.update(presentation, action: .none)
        let largeView = BarItemView(metrics: largest, item: item)
        largeView.update(presentation, action: .none)

        let smallIcon = try! #require(resolvedImage(smallView))
        let largeIcon = try! #require(resolvedImage(largeView))
        #expect(largeIcon.size.width > smallIcon.size.width,
                "\(item.rawValue) symbol width does not grow with the text size")
        #expect(largeIcon.size.height > smallIcon.size.height,
                "\(item.rawValue) symbol height does not grow with the text size")

        // The icon box is the symbol's own box, so a wide battery or a tall
        // Wi-Fi glyph is not squeezed into the square status-icon box.
        smallView.frame = NSRect(origin: .zero, size: smallView.intrinsicContentSize)
        smallView.layoutSubtreeIfNeeded()
        let icon = try! #require(imageViews(in: smallView).first)
        #expect(icon.frame.size == smallIcon.size)
    }
}

@MainActor
@Test func nativeStatusSymbolIsConfiguredNotLeftAtTheRawSymbolSize() {
    let raw = try! #require(NSImage(systemSymbolName: "wifi", accessibilityDescription: nil))
    let view = BarItemView(metrics: .default, item: .network)
    view.update(WidgetPresentation(symbolName: "wifi", text: "", accessibilityLabel: "Wi-Fi"), action: .none)
    let configured = try! #require(imageViews(in: view).first?.image)
    #expect(configured.size.height > raw.size.height)
    #expect(configured.size.width > raw.size.width)
}

@MainActor
@Test func otherSymbolsKeepTheSquareStatusIconBox() {
    let metrics = BarMetrics.scaled(textSize: 10)
    let view = BarItemView(metrics: metrics, item: .appearance)
    view.update(WidgetPresentation(symbolName: "moon.fill", text: "", accessibilityLabel: "Dark"), action: .none)
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()
    let icon = try! #require(imageViews(in: view).first)
    #expect(icon.frame.width == metrics.iconSize)
    #expect(icon.frame.height == metrics.iconSize)
}

@MainActor
@Test func itemViewMeasuresTheWholeLabel() {
    let view = BarItemView()
    view.update(WidgetPresentation(symbolName: "speaker.slash.fill", text: "Muted", accessibilityLabel: "Volume muted"),
                action: .none)
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let field = try! #require(textFields(in: view).first)
    #expect(field.stringValue == "Muted")
    expectNoTruncation(field, "volume muted")
    #expect(view.intrinsicContentSize.width >= field.frame.maxX)
}

@MainActor
@Test func defaultRightGroupDrawsEveryLabelFully() {
    let metrics = BarMetrics.default
    let content = BarContentView(side: .right, items: BarLayout.default.right, metrics: metrics)
    content.applyInitialState()
    content.apply([
        .update(WidgetState(id: .battery, revision: 1,
                            content: .battery(BatterySnapshot(presence: .internalBattery, percentage: 100)))),
        .update(WidgetState(id: .clock, revision: 1,
                            content: .clock(ClockSnapshot(date: Date(timeIntervalSince1970: 1_800_000_000))))),
        .update(WidgetState(id: .network, revision: 1,
                            content: .network(NetworkSnapshot(isConnected: true, kind: .wifi)))),
        .update(WidgetState(id: .volume, revision: 1,
                            content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0, isMuted: true))))
    ])
    // The right half of a notched display's 762pt auxiliary region, less the
    // housing clearance the geometry applies.
    content.frame = NSRect(x: 0, y: 0, width: 752, height: metrics.height)
    content.layoutSubtreeIfNeeded()

    let fields = textFields(in: content)
    #expect(fields.count >= 4)
    for field in fields {
        expectNoTruncation(field, field.stringValue)
        // The group is anchored inside the row inset and never runs past the panel.
        #expect(field.frame.maxX <= content.bounds.width - metrics.rowInset + 0.5)
    }
}

/// The battery, network and volume symbols draw wider than the old square box
/// (#0057), so the right cluster must still fit the notched display's auxiliary
/// region at the largest text size with every label intact.
@MainActor
@Test func defaultRightGroupStillFitsAtTheLargestTextSize() {
    let metrics = BarMetrics.scaled(textSize: 20)
    let content = BarContentView(side: .right, items: BarLayout.default.right, metrics: metrics)
    content.applyInitialState()
    content.apply([
        .update(WidgetState(id: .battery, revision: 1,
                            content: .battery(BatterySnapshot(presence: .internalBattery, percentage: 100, isCharging: true)))),
        .update(WidgetState(id: .clock, revision: 1,
                            content: .clock(ClockSnapshot(date: Date(timeIntervalSince1970: 1_800_000_000))))),
        .update(WidgetState(id: .network, revision: 1,
                            content: .network(NetworkSnapshot(isConnected: true, kind: .wifi)))),
        .update(WidgetState(id: .volume, revision: 1,
                            content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0, isMuted: true))))
    ])
    content.frame = NSRect(x: 0, y: 0, width: 752, height: metrics.height)
    content.layoutSubtreeIfNeeded()

    let fields = textFields(in: content)
    #expect(fields.count >= 4)
    for field in fields {
        expectNoTruncation(field, field.stringValue)
        #expect(field.frame.maxX <= content.bounds.width - metrics.rowInset + 0.5)
    }
}

@MainActor
@Test func itemViewWithoutAnIconIsJustTheText() {
    let view = BarItemView()
    view.update(WidgetPresentation(symbolName: nil, text: "Ghostty", accessibilityLabel: "Frontmost application: Ghostty"),
                action: .none)
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let field = try! #require(textFields(in: view).first)
    #expect(field.frame.minX == 0)
    expectNoTruncation(field, "front app")
}

@MainActor
@Test func chipStyleAddsContentPaddingToItemView() {
    let presentation = WidgetPresentation(symbolName: "battery.25", text: "50%", accessibilityLabel: "Battery: 50%")

    // Without chip style, view is compact with no padding.
    let viewWithoutChip = BarItemView(enablesChipStyle: false)
    viewWithoutChip.update(presentation, action: .none)
    viewWithoutChip.frame = NSRect(origin: .zero, size: viewWithoutChip.intrinsicContentSize)
    viewWithoutChip.layoutSubtreeIfNeeded()
    let sizeWithoutChip = viewWithoutChip.intrinsicContentSize

    // With chip style, view has padding around content.
    let viewWithChip = BarItemView(enablesChipStyle: true)
    viewWithChip.update(presentation, action: .none)
    viewWithChip.frame = NSRect(origin: .zero, size: viewWithChip.intrinsicContentSize)
    viewWithChip.layoutSubtreeIfNeeded()
    let sizeWithChip = viewWithChip.intrinsicContentSize

    // Chip style adds padding (4 points on each side = 8 points total per dimension).
    #expect(sizeWithChip.width == sizeWithoutChip.width + 8)
    #expect(sizeWithChip.height == sizeWithoutChip.height + 8)
}

@MainActor
@Test func networkItemWithWifiNameShowsText() {
    let view = BarItemView()
    let wifiNameOptions = NetworkFormatOptions(showWifiName: true)
    let presentation = WidgetPresenter.present(
        id: .network,
        state: WidgetState(id: .network, revision: 1,
                          content: .network(NetworkSnapshot(isConnected: true, kind: .wifi, wifiName: "MyNetwork"))),
        options: WidgetPresentationOptions(network: wifiNameOptions)
    )
    view.update(presentation, action: .openSettings(.network))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.count == 1)
    #expect(fields[0].stringValue == "MyNetwork")
    expectNoTruncation(fields[0], "wifi name")
}

@MainActor
@Test func networkItemWithoutWifiNameShowsOnlyIcon() {
    let view = BarItemView()
    let noWifiNameOptions = NetworkFormatOptions(showWifiName: false)
    let presentation = WidgetPresenter.present(
        id: .network,
        state: WidgetState(id: .network, revision: 1,
                          content: .network(NetworkSnapshot(isConnected: true, kind: .wifi, wifiName: "MyNetwork"))),
        options: WidgetPresentationOptions(network: noWifiNameOptions)
    )
    view.update(presentation, action: .openSettings(.network))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.isEmpty || fields[0].stringValue.isEmpty)
    // Icon-only width: icon size + no spacing when no text
    let iconOnlySize = view.intrinsicContentSize
    #expect(iconOnlySize.width > 0)
}

@MainActor
@Test func networkItemWithoutWifiNameDoesNotReserveSpace() {
    let view = BarItemView()
    let metrics = BarMetrics.default

    // With wifi name shown
    let withNameOptions = NetworkFormatOptions(showWifiName: true)
    let withNamePresentation = WidgetPresenter.present(
        id: .network,
        state: WidgetState(id: .network, revision: 1,
                          content: .network(NetworkSnapshot(isConnected: true, kind: .wifi, wifiName: "MyNetwork"))),
        options: WidgetPresentationOptions(network: withNameOptions)
    )
    view.update(withNamePresentation, action: .openSettings(.network))
    let sizeWithName = view.intrinsicContentSize

    // Without wifi name shown - should be narrower
    let withoutNameOptions = NetworkFormatOptions(showWifiName: false)
    let withoutNamePresentation = WidgetPresenter.present(
        id: .network,
        state: WidgetState(id: .network, revision: 1,
                          content: .network(NetworkSnapshot(isConnected: true, kind: .wifi, wifiName: "MyNetwork"))),
        options: WidgetPresentationOptions(network: withoutNameOptions)
    )
    view.update(withoutNamePresentation, action: .openSettings(.network))
    let sizeWithoutName = view.intrinsicContentSize

    // Icon-only should be much narrower than icon + name + spacing
    #expect(sizeWithoutName.width < sizeWithName.width - metrics.iconSpacing)
}

@MainActor
@Test func networkItemWithUnavailableNameShowsOnlyIcon() {
    let view = BarItemView()
    let showNameOptions = NetworkFormatOptions(showWifiName: true)
    // No wifi name available (wifiName is nil)
    let presentation = WidgetPresenter.present(
        id: .network,
        state: WidgetState(id: .network, revision: 1,
                          content: .network(NetworkSnapshot(isConnected: true, kind: .wifi, wifiName: nil))),
        options: WidgetPresentationOptions(network: showNameOptions)
    )
    view.update(presentation, action: .openSettings(.network))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.isEmpty || fields[0].stringValue.isEmpty)
    // Should be icon-only width, no reserved gap
}

@MainActor
@Test func volumeItemWithPercentageShown() {
    let view = BarItemView()
    let volumeOptions = VolumeFormatOptions(showPercent: true, showMuted: false)
    let presentation = WidgetPresenter.present(
        id: .volume,
        state: WidgetState(id: .volume, revision: 1,
                          content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: false))),
        options: WidgetPresentationOptions(volume: volumeOptions)
    )
    view.update(presentation, action: .openSettings(.sound))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.count == 1)
    #expect(fields[0].stringValue == "50%")
    expectNoTruncation(fields[0], "volume percentage")
}

@MainActor
@Test func volumeItemWithoutPercentageShowsOnlyIcon() {
    let view = BarItemView()
    let volumeOptions = VolumeFormatOptions(showPercent: false, showMuted: false)
    let presentation = WidgetPresenter.present(
        id: .volume,
        state: WidgetState(id: .volume, revision: 1,
                          content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: false))),
        options: WidgetPresentationOptions(volume: volumeOptions)
    )
    view.update(presentation, action: .openSettings(.sound))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.isEmpty || fields[0].stringValue.isEmpty)
}

@MainActor
@Test func volumeItemWithoutOptionalContentDoesNotReserveSpace() {
    let view = BarItemView()
    let metrics = BarMetrics.default

    // With percentage shown
    let withPercentOptions = VolumeFormatOptions(showPercent: true, showMuted: false)
    let withPercentPresentation = WidgetPresenter.present(
        id: .volume,
        state: WidgetState(id: .volume, revision: 1,
                          content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: false))),
        options: WidgetPresentationOptions(volume: withPercentOptions)
    )
    view.update(withPercentPresentation, action: .openSettings(.sound))
    let sizeWithPercent = view.intrinsicContentSize

    // Without percentage shown
    let withoutPercentOptions = VolumeFormatOptions(showPercent: false, showMuted: false)
    let withoutPercentPresentation = WidgetPresenter.present(
        id: .volume,
        state: WidgetState(id: .volume, revision: 1,
                          content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: false))),
        options: WidgetPresentationOptions(volume: withoutPercentOptions)
    )
    view.update(withoutPercentPresentation, action: .openSettings(.sound))
    let sizeWithoutPercent = view.intrinsicContentSize

    // Icon-only should be much narrower
    #expect(sizeWithoutPercent.width < sizeWithPercent.width - metrics.iconSpacing)
}

@MainActor
@Test func volumeItemMutedWithLabelShown() {
    let view = BarItemView()
    let volumeOptions = VolumeFormatOptions(showPercent: false, showMuted: true)
    let presentation = WidgetPresenter.present(
        id: .volume,
        state: WidgetState(id: .volume, revision: 1,
                          content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: true))),
        options: WidgetPresentationOptions(volume: volumeOptions)
    )
    view.update(presentation, action: .openSettings(.sound))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.count == 1)
    #expect(fields[0].stringValue == "Muted")
    expectNoTruncation(fields[0], "volume muted")
}

@MainActor
@Test func volumeItemMutedWithoutLabelShowsOnlyIcon() {
    let view = BarItemView()
    let volumeOptions = VolumeFormatOptions(showPercent: false, showMuted: false)
    let presentation = WidgetPresenter.present(
        id: .volume,
        state: WidgetState(id: .volume, revision: 1,
                          content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: true))),
        options: WidgetPresentationOptions(volume: volumeOptions)
    )
    view.update(presentation, action: .openSettings(.sound))
    view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
    view.layoutSubtreeIfNeeded()

    let fields = textFields(in: view)
    #expect(fields.isEmpty || fields[0].stringValue.isEmpty)
}

// MARK: - Item spacing and the right-edge inset (#0060)

/// The fixed subviews of a laid-out `BarContentView`, so a test can measure the
/// gaps between them exactly as the bar draws them.
@MainActor
private func laidOutContent(side: BarSide,
                            items: [BarItemID],
                            metrics: BarMetrics,
                            showsAppIcon: Bool = true) -> (icon: DivotAppIconButton?, items: [BarItemView]) {
    let content = BarContentView(side: side, items: items, showsAppIcon: showsAppIcon, metrics: metrics)
    content.applyInitialState()
    content.frame = NSRect(x: 0, y: 0, width: 600, height: metrics.height)
    content.layoutSubtreeIfNeeded()
    return (content.subviews.compactMap { $0 as? DivotAppIconButton }.first,
            content.subviews.compactMap { $0 as? BarItemView })
}

@MainActor
@Test func rightGroupItemsAreEightPointsApartByDefault() {
    let layout = laidOutContent(side: .right, items: [.battery, .network, .volume], metrics: .default)
    #expect(layout.items.count == 3)
    for index in 0..<(layout.items.count - 1) {
        let gap = layout.items[index + 1].frame.minX - layout.items[index].frame.maxX
        #expect(abs(gap - 8) < 0.5, "right gap \(index) was \(gap), expected 8")
    }
}

@MainActor
@Test func rightGroupLeavesTheFixedSeventeenPointScreenEdgeInset() {
    // The content view spans the right panel, whose trailing edge is the screen
    // edge in the default layout, so the 17 pt inset lands between the rightmost
    // item and the screen edge (#0060).
    let width: CGFloat = 600
    let content = BarContentView(side: .right, items: [.battery, .network, .volume], showsAppIcon: false)
    content.applyInitialState()
    content.frame = NSRect(x: 0, y: 0, width: width, height: BarMetrics.default.height)
    content.layoutSubtreeIfNeeded()
    let items = content.subviews.compactMap { $0 as? BarItemView }
    let rightmost = items.map(\.frame.maxX).max() ?? 0
    #expect(abs((width - rightmost) - BarMetrics.rightEdgeInset) < 0.5)
}

@MainActor
@Test func leftGroupUsesTheUniformItemSpacingAfterTheDivotIconByDefault() {
    let metrics = BarMetrics.default
    let layout = laidOutContent(side: .left, items: [.time, .network], metrics: metrics)
    let icon = try! #require(layout.icon)
    #expect(layout.items.count == 2)
    // The Divot-mark-to-first-item gap and the gap between the two left items
    // are both the uniform 8 pt default.
    #expect(abs(layout.items[0].frame.minX - icon.frame.maxX - 8) < 0.5)
    #expect(abs(layout.items[1].frame.minX - layout.items[0].frame.maxX - 8) < 0.5)
}

@MainActor
@Test func defaultLeftOrderUsesUniformSpacingBeforeTheFrontApp() {
    // The maintainer's order is workspaces then front-app; this exercises the
    // same shape with status items so the front app is directly after an item.
    let metrics = BarMetrics.default
    let layout = laidOutContent(side: .left, items: [.time, .frontApp], metrics: metrics)
    let icon = try! #require(layout.icon)
    #expect(layout.items.count == 2)
    // Both gaps are the uniform 8 pt; the pre-#0054 12 pt front-app gap is gone.
    #expect(abs(layout.items[0].frame.minX - icon.frame.maxX - 8) < 0.5)
    #expect(abs(layout.items[1].frame.minX - layout.items[0].frame.maxX - 8) < 0.5)
}

@MainActor
@Test func frontAppGapFollowsTheLeftSpacingWhenItChanges() {
    func gaps(left: CGFloat, right: CGFloat) -> (iconToFrontApp: CGFloat, frontAppToNext: CGFloat) {
        let metrics = BarMetrics.scaled(textSize: 14, rightItemSpacing: right, leftItemSpacing: left)
        let layout = laidOutContent(side: .left, items: [.frontApp, .time], metrics: metrics)
        let icon = layout.icon!
        return (layout.items[0].frame.minX - icon.frame.maxX,
                layout.items[1].frame.minX - layout.items[0].frame.maxX)
    }

    // Every left gap, including the one before the front app, uses the left
    // spacing uniformly (#0060).
    let tight = gaps(left: 8, right: 8)
    #expect(abs(tight.iconToFrontApp - 8) < 0.5)
    #expect(abs(tight.frontAppToNext - 8) < 0.5)

    let wide = gaps(left: 24, right: 30)
    #expect(abs(wide.iconToFrontApp - 24) < 0.5)
    #expect(abs(wide.frontAppToNext - 24) < 0.5)
}

@MainActor
private final class WidgetSpacingIconProvider: WorkspaceIconProviding {
    func icon(for bundleID: String, pointSize: CGFloat) -> NSImage? { nil }
}

@MainActor
@Test func defaultWorkspaceOrderUsesTheUniformGapAfterTheIconAndBeforeTheFrontApp() {
    let metrics = BarMetrics.default
    // The real `DivotConfiguration.defaultLeft` order with a live workspace row,
    // not a status-item surrogate, so the elastic workspace width is exercised.
    let content = BarContentView(side: .left,
                                 items: [.workspaces, .frontApp],
                                 showsAppIcon: true,
                                 workspaceFeed: WorkspaceFeed(),
                                 workspaceIcons: WidgetSpacingIconProvider(),
                                 metrics: metrics)
    content.applyInitialState()
    content.frame = NSRect(x: 0, y: 0, width: 600, height: metrics.height)
    content.layoutSubtreeIfNeeded()

    let icon = try! #require(content.subviews.compactMap { $0 as? DivotAppIconButton }.first)
    let workspaceRow = try! #require(content.subviews.compactMap { $0 as? WorkspaceBarView }.first)
    let frontApp = try! #require(content.subviews.compactMap { $0 as? BarItemView }.first)

    // Both gaps are the uniform 8 pt default (#0060).
    #expect(abs(workspaceRow.frame.minX - icon.frame.maxX - 8) < 0.5)
    #expect(abs(frontApp.frame.minX - workspaceRow.frame.maxX - 8) < 0.5)
}
