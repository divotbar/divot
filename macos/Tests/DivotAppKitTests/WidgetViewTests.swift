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
