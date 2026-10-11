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
