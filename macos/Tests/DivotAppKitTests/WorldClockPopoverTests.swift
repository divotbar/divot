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
@Suite("World clock popover with ConfigurationStore", .windowless)
struct WorldClockPopoverConfigurationStoreTests {
    @Test func addsAndPersistsATimezoneFromSearchResults() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configURL = tempDir.appendingPathComponent("config.json")
        let store = ConfigurationStore(configURL: configURL, fileManager: .default)

        let monitor = StubPopoverMonitor()
        let presenter = RecordingWindowPresenter()
        let host = BarPopoverHost(monitors: monitor, presenter: presenter)
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
@Suite("World clock popover real flow", .windowless)
struct WorldClockPopoverRealFlowTests {
    /// The remove buttons, matched by the timezone identifier they carry, so a
    /// rebuilt row can be identified without trusting a row index.
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

    private func firstSearchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        for subview in view.subviews {
            if let found = firstSearchField(in: subview) { return found }
        }
        return nil
    }

    @Test func utcOffsetLabelFormatting() {
        #expect(WorldClock.utcOffsetLabel(forOffsetSeconds: 0) == "UTC+0")
        #expect(WorldClock.utcOffsetLabel(forOffsetSeconds: 25200) == "UTC+7")
        #expect(WorldClock.utcOffsetLabel(forOffsetSeconds: 19800) == "UTC+5:30")
        #expect(WorldClock.utcOffsetLabel(forOffsetSeconds: 20700) == "UTC+5:45")
        #expect(WorldClock.utcOffsetLabel(forOffsetSeconds: -28800) == "UTC-8")
        #expect(WorldClock.utcOffsetLabel(forOffsetSeconds: -12600) == "UTC-3:30")
    }

    @Test func searchingForATimezoneAndSelectingItAddsTheZoneAndPersistsIt() {
        // Instantiate the real controller path with BarPopoverHost. The recording
        // presenter keeps the run windowless (#0091).
        let monitor = StubPopoverMonitor()
        let presenter = RecordingWindowPresenter()
        let host = BarPopoverHost(monitors: monitor, presenter: presenter)

        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                   styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)

        let controller = WorldClockPopoverContentController()
        controller.theme = .systemDefault

        var reportedTimezones: [String]?
        // Mirror the live outer controller: persist the new list, then re-render
        // so the rows rebuild (the second render).
        controller.onUpdateTimezones = { [weak controller] reported in
            reportedTimezones = reported
            controller?.render(timezones: reported, timeFormat: .twentyFourHour, showSeconds: false)
        }

        host.present(controller, relativeTo: anchor)
        defer { host.dismiss() }
        #expect(presenter.wouldPresent, "the host asks the presenter to show the panel")

        // Render initial empty state
        controller.render(timezones: [], timeFormat: .twentyFourHour, showSeconds: false)

        guard let search = firstSearchField(in: controller.view) else {
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

        // The add rebuilt the rows (second render): exactly one zone row, carrying
        // the added identifier, showing the added zone's city name.
        let rows = removeButtons(in: controller.view)
        #expect(rows.count == 1, "the rebuilt list shows exactly the added zone")
        #expect(rows.first?.identifier?.rawValue == "America/Los_Angeles",
                "the rebuilt row carries the added identifier")

        var foundAddedCity = false
        func walkForAddedCity(_ view: NSView) {
            if let field = view as? NSTextField, field.stringValue == "San Francisco" {
                foundAddedCity = true
            }
            view.subviews.forEach(walkForAddedCity)
        }
        walkForAddedCity(controller.view)
        #expect(foundAddedCity, "the rebuilt row shows the added zone's city name")

        // The rebuilt popover carries a fresh, empty search field.
        #expect(firstSearchField(in: controller.view)?.stringValue == "",
                "the rebuilt search field should be clear after adding")
    }
}

/// The real `WorldClockPopoverController` path — present → render → search →
/// select → rebuild — through a recording (windowless) host, plus the
/// absent/empty/unset and panel-height rules the task calls for.
@MainActor
@Suite("World clock popover through the real controller", .windowless)
struct WorldClockPopoverRealControllerTests {
    private func makeTempStore() throws -> (ConfigurationStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ConfigurationStore(configURL: dir.appendingPathComponent("config.json"), fileManager: .default)
        return (store, dir)
    }

    /// Present the real controller against a recording host and return it with
    /// the anchor window (kept alive) and anchor so a reopen can be driven.
    private func presentingController(store: ConfigurationStore) -> (WorldClockPopoverController, NSWindow, NSView) {
        let host = BarPopoverHost(monitors: StubPopoverMonitor(), presenter: RecordingWindowPresenter())
        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                    styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)
        let controller = WorldClockPopoverController(
            testingHost: host,
            openDateTimeSettings: {},
            getConfiguration: { store.current },
            updateTimezones: { updated in
                var config = store.current
                config.widgets.time.timezones = updated
                try? store.save(config)
            })
        controller.present(relativeTo: anchor)
        return (controller, anchorWindow, anchor)
    }

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

    private func firstSearchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField { return field }
        for subview in view.subviews {
            if let found = firstSearchField(in: subview) { return found }
        }
        return nil
    }

    private func firstTableView(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for subview in view.subviews {
            if let found = firstTableView(in: subview) { return found }
        }
        return nil
    }

    /// The visible city-name text of each result row, in list order. A row now
    /// holds a leading name field and a trailing UTC-offset field, so the name is
    /// the first non-empty field found in the row.
    private func resultRowNames(in view: NSView) -> [String] {
        guard let table = firstTableView(in: view) else { return [] }
        return (0..<table.numberOfRows).compactMap { row in
            guard let rowView = table.rowView(atRow: row, makeIfNecessary: true) else { return nil }
            var name: String?
            func walk(_ v: NSView) {
                if name == nil, let field = v as? NSTextField, !field.stringValue.isEmpty {
                    name = field.stringValue
                }
                v.subviews.forEach(walk)
            }
            walk(rowView)
            return name
        }
    }

    private func containsHint(_ view: NSView) -> Bool {
        var found = false
        func walk(_ v: NSView) {
            if let field = v as? NSTextField, field.stringValue == "No other timezones. Add one below." {
                found = true
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return found
    }

    @Test func absentKeyShowsTheResolvedDefaultsWithoutWritingTheFile() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(store.current.widgets.time.timezones == nil)

        let (controller, window, _) = presentingController(store: store)
        defer { controller.dismiss(); _ = window }

        guard let content = controller.contentForTesting else {
            Issue.record("expected live content after present")
            return
        }
        let expected = WorldClock.resolvedTimezones(configured: nil)
        #expect(removeButtons(in: content.view).count == expected.count,
                "an absent key renders the resolved defaults")
        #expect(store.current.widgets.time.timezones == nil,
                "rendering the defaults never writes the file")
    }

    @Test func removingOneDefaultPersistsTheRemainingZones() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let (controller, window, _) = presentingController(store: store)
        defer { controller.dismiss(); _ = window }

        guard let content = controller.contentForTesting else {
            Issue.record("expected live content after present")
            return
        }
        let resolved = WorldClock.resolvedTimezones(configured: nil)
        let buttons = removeButtons(in: content.view)
        #expect(buttons.count == resolved.count)

        guard let first = buttons.first, let removed = first.identifier?.rawValue else {
            Issue.record("expected a remove button")
            return
        }
        first.sendAction(first.action, to: first.target)

        #expect(store.current.widgets.time.timezones == resolved.filter { $0 != removed },
                "the remaining zones persist and the defaults never return")
        #expect(removeButtons(in: content.view).count == resolved.count - 1)
    }

    @Test func removingEveryZoneThenAddingFromEmptyAndReopeningKeepsTheAddedZone() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let (controller, window, anchor) = presentingController(store: store)
        defer { controller.dismiss(); _ = window }

        guard let content = controller.contentForTesting else {
            Issue.record("expected live content after present")
            return
        }

        // Remove every zone the empty (absent) key resolved to.
        for _ in WorldClock.resolvedTimezones(configured: nil) {
            let buttons = removeButtons(in: content.view)
            guard let first = buttons.first else { break }
            first.sendAction(first.action, to: first.target)
        }

        #expect(store.current.widgets.time.timezones == [],
                "removing the last zone persists an explicit empty list, not the defaults")
        #expect(removeButtons(in: content.view).isEmpty)
        #expect(containsHint(content.view), "the empty state keeps its hint and Add row")

        // Add a zone from the empty state through the real search field.
        guard let search = firstSearchField(in: content.view) else {
            Issue.record("expected a search field in the empty state")
            return
        }
        search.stringValue = "tokyo"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)

        let names = resultRowNames(in: content.view)
        #expect(names.contains("Tokyo"), "the empty state's search still returns results (got \(names))")

        guard let table = firstTableView(in: content.view),
              let row = names.firstIndex(of: "Tokyo") else {
            Issue.record("expected a Tokyo result row")
            return
        }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.sendAction(table.doubleAction, to: table.target)

        #expect(store.current.widgets.time.timezones == ["Asia/Tokyo"],
                "adding from the empty state persists and shows the zone")
        #expect(removeButtons(in: content.view).map { $0.identifier?.rawValue } == ["Asia/Tokyo"])

        // Reopen: the popover rebuilds from the stored list, still just Tokyo.
        controller.dismiss()
        controller.present(relativeTo: anchor)
        guard let reopened = controller.contentForTesting else {
            Issue.record("expected content after reopen")
            return
        }
        #expect(removeButtons(in: reopened.view).map { $0.identifier?.rawValue } == ["Asia/Tokyo"],
                "reopening keeps the added zone and never resurrects the defaults")
    }

    @Test func unsettingTheKeyRestoresTheDefaults() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // The user emptied the list, then ran `divot config unset widgets.time.timezones`
        // (the schema writes nil for the key).
        var emptied = store.current
        emptied.widgets.time.timezones = []
        try store.save(emptied)

        var document = store.current
        try ConfigurationSchema.apply(.null, to: "widgets.time.timezones", in: &document)
        try store.save(document)
        #expect(store.current.widgets.time.timezones == nil, "unset clears the key")

        let (controller, window, _) = presentingController(store: store)
        defer { controller.dismiss(); _ = window }
        guard let content = controller.contentForTesting else {
            Issue.record("expected live content after present")
            return
        }
        #expect(removeButtons(in: content.view).count == WorldClock.resolvedTimezones(configured: nil).count,
                "unsetting the key brings the defaults back")
    }

    @Test func searchRanksCityMatchesFirst() {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        controller.render(timezones: [], timeFormat: .twentyFourHour, showSeconds: false)

        guard let search = firstSearchField(in: controller.view) else {
            Issue.record("expected a search field")
            return
        }

        search.stringValue = "san"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        let sanNames = resultRowNames(in: controller.view)
        #expect(sanNames.first == "San Francisco",
                "a city-name prefix match is ranked first (got \(sanNames))")
        #expect(!sanNames.isEmpty, "the query returns matches")

        search.stringValue = "los"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        #expect(resultRowNames(in: controller.view).contains("San Francisco"),
                "'los' still finds the Los Angeles zone")
    }

    /// Every match is listed — the results are no longer truncated at six — and
    /// a zone already in the user's list is shown marked "Already added" and
    /// cannot be added a second time (#0096).
    @Test func everyMatchIsListedAndAddedZonesAreMarked() {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        controller.render(timezones: ["Asia/Singapore"], timeFormat: .twentyFourHour, showSeconds: false)

        guard let search = firstSearchField(in: controller.view) else {
            Issue.record("expected a search field")
            return
        }

        search.stringValue = "singapore"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        let names = resultRowNames(in: controller.view)
        guard let singapore = names.first(where: { $0.contains("Singapore") }) else {
            Issue.record("expected Singapore in the results (got \(names))")
            return
        }
        #expect(singapore.contains("Already added"),
                "an already-added zone is marked 'Already added' (got \(singapore))")

        // A broad query returns more than the old six-row cap.
        search.stringValue = "america"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        #expect(resultRowNames(in: controller.view).count > 6,
                "every match is listed, not truncated at six")

        // The already-added row cannot be added again.
        search.stringValue = "singapore"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        var reported: [String]?
        controller.onUpdateTimezones = { reported = $0 }
        guard let table = firstTableView(in: controller.view),
              let row = resultRowNames(in: controller.view).firstIndex(where: { $0.contains("Singapore") }) else {
            Issue.record("expected a Singapore result row")
            return
        }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.sendAction(table.doubleAction, to: table.target)
        #expect(reported == nil, "an already-added row cannot be added again")
    }

    /// Arrow keys skip an already-added headline match so they land on a row
    /// that can actually be added (#0096 review round 2).
    @Test func arrowKeysSkipAlreadyAddedResults() {
        let controller = WorldClockPopoverContentController()
        _ = controller.view
        controller.render(timezones: ["Asia/Singapore"], timeFormat: .twentyFourHour, showSeconds: false)

        guard let search = firstSearchField(in: controller.view) else {
            Issue.record("expected a search field")
            return
        }
        search.stringValue = "sin"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)

        guard let results = controller.searchResultsForTesting,
              let table = firstTableView(in: controller.view) else {
            Issue.record("expected search results")
            return
        }
        #expect(results.results.first?.isAlreadyAdded == true,
                "Singapore ranks first and is already added (got \(results.results.map(\.displayName)))")

        table.keyDown(with: keyEvent(125)) // Down arrow
        #expect(table.selectedRow >= 0, "Down selects a row")
        #expect(results.results[table.selectedRow].isAlreadyAdded == false,
                "Down skips the already-added Singapore row")
    }

    @Test func zoneRowsAreCappedAtEightAndScrollBeyond() {
        let many = Array(TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") }.prefix(12))

        func controller(_ zones: [String]) -> WorldClockPopoverContentController {
            let controller = WorldClockPopoverContentController()
            _ = controller.view
            controller.render(timezones: zones, timeFormat: .twentyFourHour, showSeconds: false)
            return controller
        }

        let eight = controller(Array(many.prefix(8))).preferredSize.height
        let twelve = controller(many).preferredSize.height
        #expect(twelve <= eight + 4,
                "the panel height is capped beyond eight zones (8: \(eight), 12: \(twelve))")

        let tall = controller(many)
        _ = tall.preferredSize
        #expect(zoneListScrolls(in: tall.view), "the zone list scrolls past eight rows")
        #expect(removeButtons(in: tall.view).count == 12, "every zone still has a row")
    }

    /// True when a scroll view holds more than eight stacked rows and its content
    /// is taller than its clip view (so it actually scrolls).
    private func zoneListScrolls(in view: NSView) -> Bool {
        view.layoutSubtreeIfNeeded()
        var scrolls = false
        func walk(_ v: NSView) {
            if let scroll = v as? NSScrollView,
               let list = scroll.documentView as? NSStackView,
               list.arrangedSubviews.count > 8 {
                scrolls = scrolls || list.fittingSize.height > scroll.contentView.bounds.height + 1
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return scrolls
    }

    /// Present the real controller and also hand back its host, so a test can
    /// read the live panel frame (not just the content view's size).
    private func presentingControllerWithHost(store: ConfigurationStore)
        -> (WorldClockPopoverController, BarPopoverHost, NSWindow, NSView) {
        let host = BarPopoverHost(monitors: StubPopoverMonitor(), presenter: RecordingWindowPresenter())
        let anchorWindow = NSWindow(contentRect: NSRect(x: 200, y: 600, width: 200, height: 24),
                                    styleMask: .borderless, backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 24))
        anchorWindow.contentView?.addSubview(anchor)
        let controller = WorldClockPopoverController(
            testingHost: host,
            openDateTimeSettings: {},
            getConfiguration: { store.current },
            updateTimezones: { updated in
                var config = store.current
                config.widgets.time.timezones = updated
                try? store.save(config)
            })
        controller.present(relativeTo: anchor)
        return (controller, host, anchorWindow, anchor)
    }

    private func keyEvent(_ keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: keyCode)!
    }

    /// The results list appearing and disappearing must resize the real panel,
    /// not just the content view: the host is only told to resize on a full
    /// render otherwise, so a typed query used to overflow the panel.
    @Test func typingASearchQueryGrowsTheLivePanel() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        // An explicit empty list (not the defaults) so `los` is not already added
        // and therefore not excluded from the results.
        var config = store.current
        config.widgets.time.timezones = []
        try store.save(config)

        let (controller, host, window, _) = presentingControllerWithHost(store: store)
        defer { controller.dismiss(); _ = window }

        guard let content = controller.contentForTesting,
              let search = firstSearchField(in: content.view),
              let panel = host.panel else {
            Issue.record("expected a presented panel with a search field")
            return
        }

        let heightBefore = panel.frame.height
        search.stringValue = "los"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)

        #expect(!resultRowNames(in: content.view).isEmpty, "the query shows results")
        #expect(panel.frame.height > heightBefore,
                "the live panel grows when the results list appears (before \(heightBefore), after \(panel.frame.height))")

        let heightWithResults = panel.frame.height
        search.stringValue = ""
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        #expect(panel.frame.height < heightWithResults,
                "the live panel shrinks again when the results list hides")
    }

    /// A broad query grows the real panel to the 90% screen cap and the results
    /// scroll beyond it, rather than overflowing the screen (#0096). This drives
    /// the live panel through the host, not just the content view's size.
    @Test func manyResultsCapTheLivePanelAtNinetyPercentAndScroll() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        // An explicit empty list so a broad query is not dominated by added rows.
        var config = store.current
        config.widgets.time.timezones = []
        try store.save(config)

        let (controller, host, window, _) = presentingControllerWithHost(store: store)
        defer { controller.dismiss(); _ = window }

        guard let content = controller.contentForTesting,
              let search = firstSearchField(in: content.view),
              let panel = host.panel,
              let results = content.searchResultsForTesting else {
            Issue.record("expected a presented panel with a search field and results list")
            return
        }

        // Pin the screen the cap is computed from so the assertion is deterministic.
        content.screenHeightForTesting = 1000
        let heightBefore = panel.frame.height

        search.stringValue = "a"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)

        #expect(results.results.count > 6, "a broad query lists every match")
        #expect(panel.frame.height > heightBefore, "the live panel grows with the results")
        #expect(panel.frame.height <= 900 + 1,
                "the live panel stays within 90% of the screen height (got \(panel.frame.height))")
        #expect(results.cappedHeight < 900,
                "the results list scrolls below the panel cap (got \(results.cappedHeight))")
        let rowsHeight = CGFloat(results.results.count) * TimezoneSearchResultsController.rowHeight
        #expect(rowsHeight > results.cappedHeight + 1,
                "there are more rows than fit, so the list scrolls (rows \(rowsHeight), cap \(results.cappedHeight))")
        #expect(results.view.hasVerticalScroller, "the results list scrolls vertically")
    }

    /// Tab moves focus from the search field into the results list, Return adds
    /// the highlighted row, and Escape clears the search — the keyboard add flow
    /// on the live panel.
    @Test func searchResultsSupportTabReturnAndEscapeFocus() throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        // An explicit empty list so `los` is a real, addable result.
        var config = store.current
        config.widgets.time.timezones = []
        try store.save(config)

        let (controller, host, window, _) = presentingControllerWithHost(store: store)
        defer { controller.dismiss(); _ = window }

        guard let content = controller.contentForTesting,
              let search = firstSearchField(in: content.view),
              let panel = host.panel,
              let table = firstTableView(in: content.view) else {
            Issue.record("expected a presented panel with a search field and a results table")
            return
        }

        search.stringValue = "los"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search)
        #expect(!resultRowNames(in: content.view).isEmpty, "the query shows results")

        // Tab moves focus from the field into the results list.
        #expect(panel.makeFirstResponder(search), "the search field takes focus")
        search.keyDown(with: keyEvent(48)) // Tab
        #expect(panel.firstResponder === table, "Tab moves focus into the results list")

        // Return adds the highlighted row.
        table.selectRowIndexes([0], byExtendingSelection: false)
        table.keyDown(with: keyEvent(36)) // Return
        #expect(store.current.widgets.time.timezones == ["America/Los_Angeles"],
                "Return adds the highlighted result")

        // The rebuild leaves a fresh field: type again, Escape clears it and
        // hides the list, and Tab from the list returns focus to the field.
        guard let search2 = firstSearchField(in: content.view),
              let table2 = firstTableView(in: content.view) else {
            Issue.record("expected a rebuilt search field and results table")
            return
        }

        search2.stringValue = "tok"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search2)
        #expect(!resultRowNames(in: content.view).isEmpty, "the second query shows results")

        search2.keyDown(with: keyEvent(53)) // Escape
        #expect(search2.stringValue.isEmpty, "Escape clears the search field")
        #expect(table2.enclosingScrollView?.isHidden == true, "Escape hides the results list")

        search2.stringValue = "tok"
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: search2)
        #expect(panel.makeFirstResponder(table2), "the results list takes focus")
        table2.keyDown(with: keyEvent(48)) // Tab
        #expect(panel.firstResponder === search2.currentEditor(),
                "Tab returns focus to the search field")
    }
}

/// The search-result rows now carry a right-aligned current UTC offset per zone
/// (#0097), alongside the left-aligned city name.
@MainActor
@Suite("World clock search result offsets")
struct WorldClockSearchResultOffsetTests {
    /// 2026-01-01T00:00Z, so winter offsets (no DST) are deterministic.
    private let winter = Date(timeIntervalSince1970: 1_767_225_600)

    private func makeController() -> TimezoneSearchResultsController {
        TimezoneSearchResultsController(onSelect: { _ in }, theme: .systemDefault)
    }

    private func fields(in view: NSView) -> [NSTextField] {
        var result: [NSTextField] = []
        func walk(_ v: NSView) {
            if let field = v as? NSTextField { result.append(field) }
            v.subviews.forEach(walk)
        }
        walk(view)
        return result
    }

    @Test func resultsCarryPositiveNegativeAndZeroOffsets() {
        let controller = makeController()

        controller.updateResults(for: "tokyo", currentTimezones: [], at: winter)
        #expect(controller.results.first(where: { $0.identifier == "Asia/Tokyo" })?.utcOffset == "UTC+9",
                "a positive offset is shown")

        controller.updateResults(for: "new york", currentTimezones: [], at: winter)
        #expect(controller.results.first(where: { $0.identifier == "America/New_York" })?.utcOffset == "UTC-5",
                "a negative offset is shown")

        controller.updateResults(for: "abidjan", currentTimezones: [], at: winter)
        #expect(controller.results.first(where: { $0.identifier == "Africa/Abidjan" })?.utcOffset == "UTC+0",
                "a zero offset is shown as UTC+0 (got \(controller.results.map(\.utcOffset)))")
    }

    @Test func rowShowsTheNameOnTheLeftAndTheOffsetRightAligned() {
        let controller = makeController()
        controller.updateResults(for: "tokyo", currentTimezones: [], at: winter)

        guard let table = controller.view.documentView as? NSTableView,
              let row = table.rowView(atRow: 0, makeIfNecessary: true) else {
            Issue.record("expected a result row")
            return
        }
        row.frame = NSRect(x: 0, y: 0, width: 272, height: TimezoneSearchResultsController.rowHeight)
        row.layoutSubtreeIfNeeded()

        let rowFields = fields(in: row)
        guard let name = rowFields.first(where: { $0.stringValue == "Tokyo" }),
              let offset = rowFields.first(where: { $0.stringValue == "UTC+9" }) else {
            Issue.record("expected a Tokyo row with a UTC+9 offset (got \(rowFields.map(\.stringValue)))")
            return
        }

        #expect(name.frame.minX <= 1, "the city name sits in the leading column")
        #expect(offset.alignment == .right, "the offset is right-aligned within its field")
        #expect(offset.frame.minX > row.bounds.width * 0.6,
                "the offset sits at the trailing edge (name maxX \(name.frame.maxX), offset minX \(offset.frame.minX))")
        #expect(name.frame.maxX <= offset.frame.minX,
                "the city name never overlaps the offset column")
    }

    @Test func alreadyAddedRowStillShowsItsLabelAndRightAlignedOffset() {
        let controller = makeController()
        controller.updateResults(for: "singapore", currentTimezones: ["Asia/Singapore"], at: winter)

        guard let table = controller.view.documentView as? NSTableView,
              let row = table.rowView(atRow: 0, makeIfNecessary: true) else {
            Issue.record("expected a result row")
            return
        }
        row.frame = NSRect(x: 0, y: 0, width: 272, height: TimezoneSearchResultsController.rowHeight)
        row.layoutSubtreeIfNeeded()

        let rowFields = fields(in: row)
        guard let name = rowFields.first(where: { $0.stringValue.contains("Singapore") }),
              let offset = rowFields.first(where: { $0.stringValue == "UTC+8" }) else {
            Issue.record("expected a Singapore row with a UTC+8 offset (got \(rowFields.map(\.stringValue)))")
            return
        }

        #expect(name.stringValue.contains("Already added"), "an already-added row keeps its label")
        #expect(offset.alignment == .right, "the offset stays right-aligned")
        #expect(offset.frame.minX > row.bounds.width * 0.6,
                "the offset sits at the trailing edge while the label stays leading")
        #expect(name.frame.maxX <= offset.frame.minX,
                "the already-added label never overlaps the offset column")
    }
}

/// Typing a signed offset in the search field lists the zones whose current UTC
/// offset matches (#0098), while any non-offset query still searches names.
@MainActor
@Suite("World clock search by offset")
struct WorldClockSearchOffsetTests {
    /// 2026-01-01T00:00Z and 2026-07-01T00:00Z, so winter/summer offsets
    /// (and therefore DST) are deterministic.
    private let winter = Date(timeIntervalSince1970: 1_767_225_600)
    private let summer = Date(timeIntervalSince1970: 1_782_864_000)

    private func makeController() -> TimezoneSearchResultsController {
        TimezoneSearchResultsController(onSelect: { _ in }, theme: .systemDefault)
    }

    @Test func wholeHourQueryListsEveryZoneAtThatOffset() {
        let controller = makeController()
        controller.updateResults(for: "+7", currentTimezones: [], at: winter)

        let ids = Set(controller.results.map(\.identifier))
        #expect(ids.contains("Asia/Jakarta"), "Jakarta is UTC+7")
        #expect(ids.contains("Asia/Bangkok"), "Bangkok is UTC+7")
        #expect(ids.contains("Asia/Ho_Chi_Minh"), "Ho Chi Minh City is UTC+7")
        #expect(!ids.contains("Asia/Tokyo"), "Tokyo is UTC+9, not a +7 match")
        #expect(controller.results.allSatisfy { $0.utcOffset == "UTC+7" },
                "every result shows the queried offset")
    }

    @Test func negativeWholeHourQueryListsEveryZoneAtThatOffset() {
        let controller = makeController()
        controller.updateResults(for: "-8", currentTimezones: [], at: winter)

        let ids = Set(controller.results.map(\.identifier))
        #expect(ids.contains("America/Los_Angeles"), "Los Angeles is UTC-8 in winter")
        #expect(ids.contains("America/Vancouver"), "Vancouver is UTC-8 in winter")
        #expect(ids.contains("America/Tijuana"), "Tijuana is UTC-8 in winter")
        #expect(controller.results.allSatisfy { $0.utcOffset == "UTC-8" },
                "every result shows the queried offset")
    }

    @Test func halfHourQueryMatchesAndDecimalFormIsEquivalent() {
        let controller = makeController()
        controller.updateResults(for: "+5:30", currentTimezones: [], at: winter)
        let colon = Set(controller.results.map(\.identifier))
        #expect(colon.contains("Asia/Calcutta"), "Kolkata (Asia/Calcutta) is UTC+5:30")
        #expect(colon.contains("Asia/Colombo"), "Colombo is UTC+5:30")

        controller.updateResults(for: "+5.5", currentTimezones: [], at: winter)
        #expect(Set(controller.results.map(\.identifier)) == colon,
                "+5.5 matches the same zones as +5:30")
    }

    @Test func quarterHourQueryMatchesZonesAtThatOffset() {
        let controller = makeController()
        controller.updateResults(for: "+5:45", currentTimezones: [], at: winter)
        #expect(!controller.results.isEmpty, "a quarter-hour offset finds zones (Nepal is UTC+5:45)")
        #expect(controller.results.allSatisfy { $0.utcOffset == "UTC+5:45" },
                "every result shows the queried quarter-hour offset")
    }

    @Test func offsetMatchFollowsDaylightSaving() {
        let controller = makeController()
        controller.updateResults(for: "-8", currentTimezones: [], at: winter)
        #expect(controller.results.contains { $0.identifier == "America/Los_Angeles" },
                "Los Angeles is a -8 match in winter")

        controller.updateResults(for: "-7", currentTimezones: [], at: summer)
        #expect(controller.results.contains { $0.identifier == "America/Los_Angeles" },
                "Los Angeles shifts to UTC-7 in summer, so -7 finds it")

        controller.updateResults(for: "-8", currentTimezones: [], at: summer)
        #expect(!controller.results.contains { $0.identifier == "America/Los_Angeles" },
                "Los Angeles is no longer a -8 match in summer")
    }

    @Test func nonOffsetQueryStillSearchesByName() {
        let controller = makeController()
        controller.updateResults(for: "jakarta", currentTimezones: [], at: winter)
        #expect(controller.results.contains { $0.identifier == "Asia/Jakarta" },
                "a city-name query is still handled as a name search")

        controller.updateResults(for: "7", currentTimezones: [], at: winter)
        #expect(!controller.results.contains { $0.identifier == "Asia/Bangkok" },
                "an unsigned number is a name search, not an offset (Bangkok is +7)")
    }

    @Test func alreadyAddedZoneKeepsItsLabelInOffsetResults() {
        let controller = makeController()
        controller.updateResults(for: "+7", currentTimezones: ["Asia/Jakarta"], at: winter)

        guard let jakarta = controller.results.first(where: { $0.identifier == "Asia/Jakarta" }) else {
            Issue.record("expected Jakarta in the +7 results")
            return
        }
        #expect(jakarta.isAlreadyAdded, "a zone already in the list is marked 'Already added'")
        #expect(jakarta.utcOffset == "UTC+7", "an already-added row still shows its offset")
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
