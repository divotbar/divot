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

// MARK: - Clickable rows, scanning animation, previously joined

/// Synchronous scanner state, kept out of the async context so `NSLock` is only
/// used from non-async functions.
private final class FakeWifiScanState: @unchecked Sendable {
    private let lock = NSLock()
    private let response: WifiScanResponse
    private var calls = 0

    init(response: WifiScanResponse) {
        self.response = response
    }

    var scanCount: Int {
        lock.withLock { calls }
    }

    func nextResponse() -> WifiScanResponse {
        lock.withLock {
            calls += 1
            return response
        }
    }
}

/// A scanner that returns one response and counts calls, so controller tests
/// assert the cache-first paint and the always-live rescan.
private final class FakeWifiScanResponder: WifiNetworkScanning, @unchecked Sendable {
    private let state: FakeWifiScanState

    init(response: WifiScanResponse) {
        self.state = FakeWifiScanState(response: response)
    }

    var scanCount: Int { state.scanCount }

    func scan() async -> WifiScanResponse {
        state.nextResponse()
    }
}

/// Synchronous connector state, kept out of the async context so `NSLock` is
/// only used from non-async functions.
private final class FakeWifiConnectState: @unchecked Sendable {
    private let lock = NSLock()
    private let outcomes: [WifiConnectOutcome]
    private var calls: [(ssid: String, isSecure: Bool, password: String?)] = []

    init(outcomes: [WifiConnectOutcome]) {
        self.outcomes = outcomes
    }

    var recordedCalls: [(ssid: String, isSecure: Bool, password: String?)] {
        lock.withLock { calls }
    }

    func record(ssid: String, isSecure: Bool, password: String?) -> WifiConnectOutcome {
        lock.withLock {
            calls.append((ssid, isSecure, password))
            return outcomes[min(calls.count - 1, outcomes.count - 1)]
        }
    }
}

/// A connector that answers from a queued list of outcomes and records every
/// call, so tests join networks without touching system state.
private final class FakeWifiConnector: WifiNetworkConnecting, @unchecked Sendable {
    private let state: FakeWifiConnectState

    init(outcomes: [WifiConnectOutcome]) {
        self.state = FakeWifiConnectState(outcomes: outcomes)
    }

    var recordedCalls: [(ssid: String, isSecure: Bool, password: String?)] {
        state.recordedCalls
    }

    func connect(ssid: String, isSecure: Bool, password: String?) async -> WifiConnectOutcome {
        state.record(ssid: ssid, isSecure: isSecure, password: password)
    }
}

@MainActor
private func allButtons(in view: NSView) -> [NSButton] {
    var found: [NSButton] = []
    if let button = view as? NSButton { found.append(button) }
    for subview in view.subviews { found += allButtons(in: subview) }
    return found
}

@MainActor
private func allLabels(in view: NSView) -> [NSTextField] {
    var found: [NSTextField] = []
    if let label = view as? NSTextField { found.append(label) }
    for subview in view.subviews { found += allLabels(in: subview) }
    return found
}

@MainActor
private func allSpinners(in view: NSView) -> [NSProgressIndicator] {
    var found: [NSProgressIndicator] = []
    if let spinner = view as? NSProgressIndicator { found.append(spinner) }
    for subview in view.subviews { found += allSpinners(in: subview) }
    return found
}

/// Every explicit accessibility label in the hierarchy, including the ones set
/// on container rows (which `allLabels` misses: the label lives on the row,
/// not on its text field).
@MainActor
private func allAccessibilityLabels(in view: NSView) -> [String] {
    var found = [view.accessibilityLabel() ?? ""]
    for subview in view.subviews { found += allAccessibilityLabels(in: subview) }
    return found
}

/// The clickable network rows: buttons whose labels carry the signal summary.
@MainActor
private func networkRowButtons(in view: NSView) -> [NSButton] {
    allButtons(in: view).filter { ($0.accessibilityLabel() ?? "").contains(" of 4 bars") }
}

@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<200 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
@Suite("Wi-Fi popover rows and scanning state", .windowless)
struct WifiPopoverRowsTests {
    private func networks() -> [WifiNetwork] {
        [
            WifiNetwork(ssid: "Home", rssi: -42, isSecure: true, isCurrent: true),
            WifiNetwork(ssid: "Cafe", rssi: -70, isSecure: false, isCurrent: false)
        ]
    }

    @Test func everyNetworkRowIsAClickableButton() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        var selected: [String] = []
        controller.onSelect = { selected.append($0.ssid) }
        controller.renderList(networks: networks())

        let rows = networkRowButtons(in: controller.view)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.isEnabled })
        for row in rows { row.performClick(row) }
        #expect(selected.sorted() == ["Cafe", "Home"],
                "clicking a row asks to join that network")
    }

    @Test func networkRowsDrawNoButtonCellTitle() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.renderList(networks: networks())

        let rows = networkRowButtons(in: controller.view)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.title.isEmpty },
                "an NSButton defaults its title to \"Button\" and its cell draws it over the row's own icon and name")
    }

    @Test func scanningAnimatesInsteadOfStaticText() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.render(.scanning)

        #expect(allSpinners(in: controller.view).count == 1,
                "the scanning state shows a spinning indicator")
        #expect(!allLabels(in: controller.view).contains {
            $0.stringValue == "Scanning for networks…"
        }, "the static waiting text is gone")
    }

    @Test func cachedFirstPaintShowsItsAgeBesideTheSpinner() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.renderList(networks: networks(),
                              isScanning: true,
                              cacheSummary: "Updated 5s ago")

        let texts = allLabels(in: controller.view).map(\.stringValue)
        #expect(texts.contains("Updated 5s ago"))
        #expect(allSpinners(in: controller.view).count == 1,
                "the background rescan animates while the cache stays visible")
        #expect(networkRowButtons(in: controller.view).count == 2,
                "the cached rows stay visible until the live list lands")
    }

    @Test func joiningDisablesRowsAndMarksTheJoiningOne() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.renderList(networks: networks(), connectingSSID: "Cafe")

        #expect(networkRowButtons(in: controller.view).allSatisfy { !$0.isEnabled },
                "taps hold still while one network joins")
        #expect(allLabels(in: controller.view).contains { $0.stringValue == "Connecting…" })
        #expect(allSpinners(in: controller.view).count == 1)
    }

    @Test func previouslyJoinedNetworksStandApartFromInRangeOnes() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.renderList(
            networks: networks(),
            recentJoins: [
                WifiJoinedNetwork(ssid: "Office", lastJoinedAt: Date()),
                WifiJoinedNetwork(ssid: "Cabin", lastJoinedAt: Date())
            ])

        let texts = allLabels(in: controller.view).map(\.stringValue)
        let roles = allAccessibilityLabels(in: controller.view)
        #expect(roles.contains("Office, previously joined"))
        #expect(roles.contains("Cabin, previously joined"))
        #expect(!roles.contains("Home, previously joined"),
                "an in-range network is never repeated in the previous section")
        #expect(networkRowButtons(in: controller.view).count == 2,
                "the previous section is shown, not joined: it adds no buttons")
    }

    @Test func scanTimeoutIsTwentySeconds() {
        #expect(CoreWLANNetworkScanner().timeoutForTesting == .seconds(20))
    }

    @Test func themeChangeKeepsAFallbackMessage() {
        let controller = WifiPopoverContentController()
        _ = controller.view
        controller.render(.permissionDenied)
        controller.theme = .systemDefault

        let texts = allLabels(in: controller.view).map(\.stringValue)
        #expect(texts.contains { $0.contains("Location access is needed") },
                "restyling rebuilds the message, not an empty list")
    }
}

@MainActor
@Suite("Wi-Fi popover join flow", .windowless)
struct WifiPopoverJoinTests {
    private func scanned() -> WifiScanResponse {
        .scanned(networks: [
            WifiScannedNetwork(ssid: "Home", rssi: -42, isSecure: true),
            WifiScannedNetwork(ssid: "Cafe", rssi: -70, isSecure: false)
        ], currentSSID: "Home")
    }

    private func makeController(scanner: FakeWifiScanResponder,
                                connector: FakeWifiConnector,
                                joinStore: InMemoryWifiJoinHistoryStore = InMemoryWifiJoinHistoryStore(),
                                passwordProvider: (@MainActor (String) async -> String?)? = { _ in nil })
    -> (WifiPopoverController, NSView) {
        let presenter = RecordingWindowPresenter()
        let host = BarPopoverHost(monitors: NoopPopoverMonitor(), presenter: presenter)
        let controller = WifiPopoverController(
            scanner: scanner,
            connector: connector,
            joinStore: joinStore,
            passwordProvider: passwordProvider,
            openWifiSettings: {}, openLocationSettings: {},
            testingHost: host)
        return (controller, NSView())
    }

    private func clickRow(ssid: String, in controller: WifiPopoverController) {
        guard let content = controller.contentForTesting,
              let row = networkRowButtons(in: content.view).first(where: {
                  ($0.accessibilityLabel() ?? "").hasPrefix("\(ssid),")
              }) else {
            Issue.record("expected a row button for \(ssid)")
            return
        }
        row.performClick(row)
    }

    @Test func cachedSecondOpenPaintsAtOnceAndStillRescansLive() async {
        let scanner = FakeWifiScanResponder(response: scanned())
        let (controller, anchor) = makeController(
            scanner: scanner, connector: FakeWifiConnector(outcomes: [.failed("offline")]))

        controller.present(relativeTo: anchor)
        #expect(controller.firstPaintInterval == nil, "no cache on the first open")
        await waitUntil { controller.liveListInterval != nil }
        #expect(controller.firstPaintInterval != nil)
        #expect(scanner.scanCount == 1)

        controller.present(relativeTo: anchor)
        #expect(controller.firstPaintInterval != nil,
                "the fresh cache paints synchronously on open")
        #expect(controller.liveListInterval == nil,
                "the live scan still runs in the background")
        #expect(controller.cachedNetworksIfFresh?.summary.hasPrefix("Updated ") == true)
        await waitUntil { controller.liveListInterval != nil }
        #expect(scanner.scanCount == 2,
                "a live scan runs on every open, regardless of cache age")
        #expect(controller.liveListInterval != nil)
    }

    @Test func clickingAnInRangeNetworkConnectsAndMarksItCurrent() async throws {
        let scanner = FakeWifiScanResponder(response: scanned())
        let connector = FakeWifiConnector(outcomes: [.connected(ssid: "Cafe")])
        let store = InMemoryWifiJoinHistoryStore()
        let (controller, anchor) = makeController(
            scanner: scanner, connector: connector, joinStore: store)
        controller.present(relativeTo: anchor)
        await waitUntil { controller.liveListInterval != nil }

        clickRow(ssid: "Cafe", in: controller)
        await waitUntil { store.load().map(\.ssid) == ["Cafe"] }

        #expect(connector.recordedCalls.count == 1)
        #expect(connector.recordedCalls.first?.ssid == "Cafe")
        #expect(connector.recordedCalls.first?.password == nil)
        let roles = networkRowButtons(in: controller.contentForTesting!.view)
            .map { $0.accessibilityLabel() ?? "" }
        #expect(roles.contains { $0.hasPrefix("Cafe,") && $0.contains("connected") },
                "the popover shows the new current network")
        #expect(store.load().count <= WifiJoinHistory.maximumRecentJoins)
    }

    @Test func securedNetworkAsksForAPasswordWithoutStoringIt() async throws {
        let scanner = FakeWifiScanResponder(response: scanned())
        let connector = FakeWifiConnector(outcomes: [.requiresPassword, .connected(ssid: "Home")])
        let store = InMemoryWifiJoinHistoryStore()
        let (controller, anchor) = makeController(
            scanner: scanner, connector: connector, joinStore: store,
            passwordProvider: { _ in "s3cret" })
        controller.present(relativeTo: anchor)
        await waitUntil { controller.liveListInterval != nil }

        clickRow(ssid: "Home", in: controller)
        await waitUntil { store.load().map(\.ssid) == ["Home"] }

        #expect(connector.recordedCalls.count == 2)
        #expect(connector.recordedCalls[0].password == nil)
        #expect(connector.recordedCalls[1].password == "s3cret")
        let stored = try JSONEncoder().encode(store.load())
        #expect(!String(data: stored, encoding: .utf8)!.contains("s3cret"),
                "the password is never written to Divot's state")
    }

    @Test func cancelledPasswordLeavesTheListAlone() async {
        let scanner = FakeWifiScanResponder(response: scanned())
        let connector = FakeWifiConnector(outcomes: [.requiresPassword])
        let store = InMemoryWifiJoinHistoryStore()
        let (controller, anchor) = makeController(
            scanner: scanner, connector: connector, joinStore: store)
        controller.present(relativeTo: anchor)
        await waitUntil { controller.liveListInterval != nil }

        clickRow(ssid: "Home", in: controller)
        await waitUntil { connector.recordedCalls.count == 1 }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(store.load() == [])
        #expect(networkRowButtons(in: controller.contentForTesting!.view).allSatisfy { $0.isEnabled },
                "cancelling returns to the enabled list with no error")
    }

    @Test func failedJoinShowsTheMacOSErrorBesideTheList() async {
        let scanner = FakeWifiScanResponder(response: scanned())
        let connector = FakeWifiConnector(outcomes: [.failed("Association failed.")])
        let (controller, anchor) = makeController(scanner: scanner, connector: connector)
        controller.present(relativeTo: anchor)
        await waitUntil { controller.liveListInterval != nil }

        clickRow(ssid: "Cafe", in: controller)
        await waitUntil {
            allLabels(in: controller.contentForTesting!.view).contains {
                $0.stringValue.contains("Couldn't join")
            }
        }

        let texts = allLabels(in: controller.contentForTesting!.view).map(\.stringValue)
        #expect(texts.contains { $0.contains("Association failed.") },
                "the macOS reason is shown verbatim")
        #expect(networkRowButtons(in: controller.contentForTesting!.view).count == 2,
                "the list stays visible beside the error")
    }
}

