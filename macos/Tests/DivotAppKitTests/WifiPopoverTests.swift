import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The Wi-Fi popover's network list: it fits its rows up to 90% of the screen
/// height and scrolls beyond that, so a long list of nearby networks cannot grow
/// the popover without bound.
@MainActor
@Suite("Wi-Fi network list scrolling")
struct WifiPopoverNetworkListTests {
    /// Networks whose total row height comfortably exceeds a 1000 pt screen cap.
    private func networks(_ count: Int) -> [WifiNetwork] {
        (0..<count).map { index in
            WifiNetwork(ssid: "Network \(index)",
                        rssi: -40 - index,
                        isSecure: index.isMultiple(of: 2),
                        isCurrent: index == 0)
        }
    }

    /// The list view, its scroll view, and the stacked rows, found by walking the
    /// content view.
    private func networkList(in view: NSView)
        -> (list: WifiNetworkListView, scroll: NSScrollView, rows: NSStackView)? {
        if let list = view as? WifiNetworkListView,
           let scroll = list.subviews.compactMap({ $0 as? NSScrollView }).first,
           let rows = scroll.documentView as? NSStackView {
            return (list, scroll, rows)
        }
        for subview in view.subviews {
            if let found = networkList(in: subview) { return found }
        }
        return nil
    }

    @Test func capsAtNinetyPercentOfTheScreenHeight() {
        #expect(WifiNetworkListView.maximumHeightFraction == 0.9)

        let controller = WifiPopoverContentController()
        _ = controller.view
        let list = controller.networkListForTesting
        list.screenHeightOverride = 1000
        controller.render(.networks(networks(60)))

        #expect(abs(list.cappedHeight - 900) < 0.5,
                "the list caps at 90% of the screen height (got \(list.cappedHeight))")
    }

    @Test func aShortListFitsItsContentAndDoesNotScroll() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        let list = controller.networkListForTesting
        list.screenHeightOverride = 1000
        controller.render(.networks(networks(1)))
        _ = controller.preferredSize

        guard let found = networkList(in: controller.view) else {
            Issue.record("expected a network list in the popover")
            return
        }
        #expect(found.list.cappedHeight < 900, "a short list is not pinned to the cap")
        #expect(found.rows.fittingSize.height <= found.list.cappedHeight + 1,
                "a short list fits its rows without scrolling")
    }

    @Test func aLongListScrollsAndKeepsEveryRow() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.networkListForTesting.screenHeightOverride = 1000
        controller.render(.networks(networks(60)))
        _ = controller.preferredSize

        guard let found = networkList(in: controller.view) else {
            Issue.record("expected a network list in the popover")
            return
        }
        #expect(found.scroll.hasVerticalScroller, "the list scrolls vertically")
        #expect(found.rows.arrangedSubviews.count == 60, "every network still has a row")
        #expect(found.rows.fittingSize.height > found.list.cappedHeight + 1,
                "the rows are taller than the cap, so the list scrolls (rows \(found.rows.fittingSize.height), cap \(found.list.cappedHeight))")
    }

    @Test func anEmptyResultShowsTheMessageInsteadOfAList() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.render(.networks([]))

        #expect(networkList(in: controller.view) == nil,
                "an empty scan shows a message, not an empty scroll view")
    }
}
