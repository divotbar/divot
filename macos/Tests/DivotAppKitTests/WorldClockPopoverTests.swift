import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The world clock popover's content rows and their remove controls. Rows are
/// built from `WorldClock.entries`, which drops invalid identifiers and
/// collapses duplicates, so removal must target the timezone identifier rather
/// than the visible row index.
@MainActor
@Suite("World clock popover content")
struct WorldClockPopoverContentTests {
    private func makeController() -> WorldClockPopoverContentController {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        return controller
    }

    @Test func emptyStateShowsHintText() {
        let controller = makeController()
        controller.render(timezones: [], timeFormat: .twentyFourHour, showSeconds: false)

        var foundHint = false
        func walk(_ view: NSView) {
            if let field = view as? NSTextField {
                if field.stringValue == "No other timezones. Add one below." {
                    foundHint = true
                }
            }
            view.subviews.forEach(walk)
        }
        walk(controller.view)

        #expect(foundHint, "empty state should show hint text")
    }

    /// The remove buttons, matched by the timezone identifier they carry.
    private func removeButtons(in view: NSView) -> [NSButton] {
        var result: [NSButton] = []
        func walk(_ v: NSView) {
            if let button = v as? NSButton,
               let identifier = button.identifier?.rawValue,
               TimeZone.knownTimeZoneIdentifiers.contains(identifier) {
                result.append(button)
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return result
    }

    @Test func removeButtonCarriesTheTimezoneIdentifierNotTheRowIndex() {
        let controller = makeController()
        // A stale invalid identifier and a duplicate ahead of the visible row
        // make an index-based removal delete the wrong zone.
        let stored = ["Invalid/Timezone", "Asia/Tokyo", "Asia/Tokyo", "America/Los_Angeles"]
        controller.render(timezones: stored, timeFormat: .twentyFourHour, showSeconds: false)

        let buttons = removeButtons(in: controller.view)
        #expect(buttons.count == 2, "invalid identifiers are dropped and duplicates collapse to two rows")

        var reported: [String]?
        controller.onUpdateTimezones = { reported = $0 }

        guard let losAngeles = buttons.first(where: { $0.identifier?.rawValue == "America/Los_Angeles" }) else {
            Issue.record("expected a remove button for America/Los_Angeles")
            return
        }
        losAngeles.sendAction(losAngeles.action, to: losAngeles.target)

        #expect(reported == ["Invalid/Timezone", "Asia/Tokyo", "Asia/Tokyo"],
                "removing Los Angeles must keep the stale invalid entry and both duplicate Tokyo entries")
    }

    @Test func removingADuplicatedZoneRemovesEveryStoredCopy() {
        let controller = makeController()
        controller.render(timezones: ["Asia/Tokyo", "Asia/Tokyo", "America/Los_Angeles"],
                          timeFormat: .twentyFourHour,
                          showSeconds: false)

        var reported: [String]?
        controller.onUpdateTimezones = { reported = $0 }

        let buttons = removeButtons(in: controller.view)
        guard let tokyo = buttons.first(where: { $0.identifier?.rawValue == "Asia/Tokyo" }) else {
            Issue.record("expected a remove button for Asia/Tokyo")
            return
        }
        tokyo.sendAction(tokyo.action, to: tokyo.target)

        #expect(reported == ["America/Los_Angeles"])
    }
}

@MainActor
@Suite("World clock popover real flow")
struct WorldClockPopoverRealFlowTests {
    @Test func compactOffsetFormatting() {
        let controller = WorldClockPopoverContentController()
        _ = controller.view

        #expect(controller.formatCompactOffset(0) == "+0")
        #expect(controller.formatCompactOffset(25200) == "+7")
        #expect(controller.formatCompactOffset(19800) == "+5:30")
        #expect(controller.formatCompactOffset(20700) == "+5:45")
        #expect(controller.formatCompactOffset(-28800) == "-8")
        #expect(controller.formatCompactOffset(-12600) == "-3:30")
    }

    @Test func searchingForATimezoneAndSelectingItAddsTheZoneAndPersistsIt() {
        // Instantiate the real controller path with BarPopoverHost
        let monitor = StubPopoverMonitor()
        let host = BarPopoverHost(monitors: monitor)

        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                   styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)

        let controller = WorldClockPopoverContentController()
        controller.theme = .systemDefault

        var reportedTimezones: [String]?
        controller.onUpdateTimezones = { reported in
            reportedTimezones = reported
        }

        host.present(controller, relativeTo: anchor)
        defer { host.dismiss() }

        // Render initial empty state
        controller.render(timezones: [], timeFormat: .twentyFourHour, showSeconds: false)

        // Find the search field
        var searchField: NSSearchField?
        func walk(_ view: NSView) {
            if let field = view as? NSSearchField {
                searchField = field
            }
            view.subviews.forEach(walk)
        }
        walk(controller.view)

        guard let search = searchField else {
            Issue.record("expected a search field in the popover")
            return
        }

        // Simulate typing into the search field by setting its value and triggering the action
        search.stringValue = "los"
        search.sendAction(search.action, to: search.target)

        // Find the results table to verify results appeared
        var tableView: NSTableView?
        func walkForTable(_ view: NSView) {
            if let table = view as? NSTableView {
                tableView = table
            }
            view.subviews.forEach(walkForTable)
        }

        func walkForScrollView(_ view: NSView) {
            if let scroll = view as? NSScrollView, let doc = scroll.documentView as? NSTableView {
                tableView = doc
            }
            view.subviews.forEach(walkForScrollView)
        }
        walkForTable(controller.view)
        walkForScrollView(controller.view)

        guard let table = tableView, table.numberOfRows > 0 else {
            Issue.record("expected search results to appear in the table view")
            return
        }

        // Double-click the first result to select it
        table.selectRowIndexes([0], byExtendingSelection: false)
        table.sendAction(table.doubleAction, to: table.target)

        // Verify the timezone was added and persisted
        guard let reported = reportedTimezones, reported.count == 1 else {
            Issue.record("expected one timezone to be reported after selection")
            return
        }

        // The first Los Angeles match should be America/Los_Angeles
        #expect(reported[0] == "America/Los_Angeles")
    }
}

// Stub monitor from BarPopoverTests for use in real flow tests
@MainActor
private final class StubPopoverMonitor: PopoverEventMonitoring {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var isMonitoring = false

    func start(action: @escaping (NSEvent) -> PopoverPressAction, onDismiss: @escaping () -> Void) {
        startCount += 1
        isMonitoring = true
    }

    func stop() {
        stopCount += 1
        isMonitoring = false
    }
}
