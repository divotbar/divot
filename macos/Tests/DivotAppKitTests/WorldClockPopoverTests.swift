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
@Suite("World clock popover with ConfigurationStore")
struct WorldClockPopoverConfigurationStoreTests {
    @Test func addsAndPersistsATimezoneFromSearchResults() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("config.json")
        let store = ConfigurationStore(configURL: configURL, fileManager: .default)

        let monitor = StubPopoverMonitor()
        let host = BarPopoverHost(monitors: monitor)
        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                   styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)

        let contentController = WorldClockPopoverContentController()
        contentController.theme = .systemDefault
        contentController.onUpdateTimezones = { timezones in
            var config = store.current
            config.widgets.time.timezones = timezones
            try? store.save(config)
        }

        host.present(contentController, relativeTo: anchor)
        defer { host.dismiss() }

        contentController.render(timezones: [], timeFormat: .twentyFourHour, showSeconds: false)

        var searchField: NSSearchField?
        func walk(_ view: NSView) {
            if let field = view as? NSSearchField {
                searchField = field
            }
            view.subviews.forEach(walk)
        }
        walk(contentController.view)

        guard let search = searchField else {
            Issue.record("expected a search field")
            return
        }

        search.stringValue = "los"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)

        var tableView: NSTableView?
        func walkForScrollView(_ view: NSView) {
            if let scroll = view as? NSScrollView, let doc = scroll.documentView as? NSTableView {
                tableView = doc
            }
            view.subviews.forEach(walkForScrollView)
        }
        walkForScrollView(contentController.view)

        guard let table = tableView, table.numberOfRows > 0 else {
            Issue.record("expected search results")
            return
        }

        var losAngelesRowIndex: Int?
        for rowIndex in 0..<table.numberOfRows {
            guard let rowView = table.rowView(atRow: rowIndex, makeIfNecessary: true) else {
                continue
            }
            var foundSanFrancisco = false
            func walkRow(_ view: NSView) {
                if let textField = view as? NSTextField, textField.stringValue.contains("San Francisco") {
                    foundSanFrancisco = true
                }
                view.subviews.forEach(walkRow)
            }
            walkRow(rowView)
            if foundSanFrancisco {
                losAngelesRowIndex = rowIndex
                break
            }
        }

        guard let rowIndex = losAngelesRowIndex else {
            Issue.record("expected San Francisco in results")
            return
        }

        table.selectRowIndexes([rowIndex], byExtendingSelection: false)
        table.sendAction(table.doubleAction, to: table.target)

        #expect(store.current.widgets.time.timezones == ["America/Los_Angeles"],
                "timezone should be persisted to store")
    }

    @Test func defaultsAppearWhenConfigIsAbsent() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("config.json")
        let store = ConfigurationStore(configURL: configURL, fileManager: .default)

        let controller = WorldClockPopoverContentController()
        controller.theme = .systemDefault

        let entries = WorldClock.entries(for: ["America/Los_Angeles", "Europe/London", "Asia/Singapore"],
                                        at: Date(),
                                        localTimeZone: .current,
                                        calendar: .current)

        #expect(entries.count == 3)
        #expect(entries[0].displayName == "San Francisco")
        #expect(entries[1].displayName == "London")
        #expect(entries[2].displayName == "Singapore")
    }

    @Test func explicitEmptyListPersistsAcrossReload() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("config.json")
        var store = ConfigurationStore(configURL: configURL, fileManager: .default)

        var config = store.current
        config.widgets.time.timezones = []
        try store.save(config)

        let store2 = ConfigurationStore(configURL: configURL, fileManager: .default)
        store2.load()

        #expect(store2.current.widgets.time.timezones == [],
                "explicit empty list should persist")
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

        // Simulate typing into the search field by setting its value and posting the notification
        search.stringValue = "los"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)

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

        // Find the row containing "San Francisco" (friendly name for America/Los_Angeles)
        var losAngelesRowIndex: Int?
        for rowIndex in 0..<table.numberOfRows {
            guard let rowView = table.rowView(atRow: rowIndex, makeIfNecessary: true) else {
                continue
            }

            var foundSanFrancisco = false
            func walkRow(_ view: NSView) {
                if let textField = view as? NSTextField,
                   textField.stringValue.contains("San Francisco") {
                    foundSanFrancisco = true
                }
                view.subviews.forEach(walkRow)
            }
            walkRow(rowView)

            if foundSanFrancisco {
                losAngelesRowIndex = rowIndex
                break
            }
        }

        guard let rowIndex = losAngelesRowIndex else {
            Issue.record("expected to find San Francisco in search results")
            return
        }

        // Double-click the result to select it
        table.selectRowIndexes([rowIndex], byExtendingSelection: false)
        table.sendAction(table.doubleAction, to: table.target)

        // Verify the timezone was added to the callback and search closed
        guard let reported = reportedTimezones, reported.count == 1 else {
            Issue.record("expected one timezone to be reported after selection")
            return
        }
        #expect(reported[0] == "America/Los_Angeles",
                "selected timezone should match Los Angeles identifier")

        // Verify the search cleared and rows rebuilt: search field should be empty
        #expect(search.stringValue == "",
                "search field should clear after selecting a timezone")
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
