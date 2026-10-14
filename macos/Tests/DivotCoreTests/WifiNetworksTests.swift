import Foundation
import Testing
@testable import DivotCore

/// Synchronous scanner state, kept out of the async context so `NSLock` is only
/// used from non-async functions.
private final class FakeWifiScannerState: @unchecked Sendable {
    private let lock = NSLock()
    private let response: WifiScanResponse
    private var count = 0

    init(response: WifiScanResponse) {
        self.response = response
    }

    var scanCount: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    func nextResponse() -> WifiScanResponse {
        lock.lock(); defer { lock.unlock() }
        count += 1
        return response
    }
}

/// A scanner that returns a fixed response and counts how often it was called.
private final class FakeWifiScanner: WifiNetworkScanning, @unchecked Sendable {
    private let state: FakeWifiScannerState

    init(response: WifiScanResponse) {
        self.state = FakeWifiScannerState(response: response)
    }

    var scanCount: Int { state.scanCount }

    func scan() async -> WifiScanResponse {
        state.nextResponse()
    }
}

@Suite("Wi-Fi network list shaping")
struct WifiNetworksTests {
    @Test func organizeKeepsTheStrongestDuplicateAndDropsHiddenSSIDs() {
        let scanned = [
            WifiScannedNetwork(ssid: "Home", rssi: -55, isSecure: true),
            WifiScannedNetwork(ssid: "Home", rssi: -40, isSecure: true),
            WifiScannedNetwork(ssid: "Cafe", rssi: -60, isSecure: false),
            // Hidden networks report no SSID; the scanner drops them before this
            // shape, and a blank name is dropped again here as a safety net.
            WifiScannedNetwork(ssid: "   ", rssi: -30, isSecure: false)
        ]

        let rows = WifiNetworks.organize(scanned, currentSSID: nil)

        #expect(rows.map(\.ssid) == ["Home", "Cafe"])
        #expect(rows.first?.rssi == -40)
    }

    @Test func organizeSortsBySignalDescending() {
        let scanned = [
            WifiScannedNetwork(ssid: "Weak", rssi: -80, isSecure: false),
            WifiScannedNetwork(ssid: "Strong", rssi: -45, isSecure: true),
            WifiScannedNetwork(ssid: "Middle", rssi: -62, isSecure: false)
        ]

        let rows = WifiNetworks.organize(scanned, currentSSID: nil)

        #expect(rows.map(\.ssid) == ["Strong", "Middle", "Weak"])
    }

    @Test func organizeMarksAndPinsTheCurrentNetworkFirst() {
        let scanned = [
            WifiScannedNetwork(ssid: "Stronger", rssi: -40, isSecure: true),
            WifiScannedNetwork(ssid: "Current", rssi: -75, isSecure: true)
        ]

        let rows = WifiNetworks.organize(scanned, currentSSID: "Current")

        #expect(rows.first?.ssid == "Current")
        #expect(rows.first?.isCurrent == true)
        #expect(rows.dropFirst().allSatisfy { !$0.isCurrent })
    }

    @Test func organizeKeepsTheLockOnASignalTie() {
        let scanned = [
            WifiScannedNetwork(ssid: "Tie", rssi: -50, isSecure: false),
            WifiScannedNetwork(ssid: "Tie", rssi: -50, isSecure: true)
        ]

        let rows = WifiNetworks.organize(scanned, currentSSID: nil)

        #expect(rows.count == 1)
        #expect(rows.first?.isSecure == true)
    }

    @Test func signalLevelUsesTheConventionalBands() {
        #expect(WifiNetworks.signalLevel(rssi: -40) == 4)
        #expect(WifiNetworks.signalLevel(rssi: -50) == 4)
        #expect(WifiNetworks.signalLevel(rssi: -55) == 3)
        #expect(WifiNetworks.signalLevel(rssi: -65) == 2)
        #expect(WifiNetworks.signalLevel(rssi: -75) == 1)
        #expect(WifiNetworks.signalLevel(rssi: -95) == 0)
    }

    @Test func stateMapsEveryResponseHonestly() {
        #expect(WifiNetworks.state(from: .permissionDenied) == .permissionDenied)
        #expect(WifiNetworks.state(from: .unavailable) == .unavailable)
        #expect(WifiNetworks.state(from: .failed("boom")) == .failed("boom"))
        let empty = WifiNetworks.state(from: .scanned(networks: [], currentSSID: nil))
        #expect(empty == .networks([]))
    }
}

@Suite("Wi-Fi scan model")
@MainActor
struct WifiScanModelTests {
    @Test func modelSurfacesPermissionDeniedFromTheScannerSeam() async {
        let scanner = FakeWifiScanner(response: .permissionDenied)
        let model = WifiScanModel(scanner: scanner)

        let state = await model.scan()

        #expect(state == .permissionDenied)
        #expect(model.state == .permissionDenied)
        #expect(scanner.scanCount == 1)
    }

    @Test func modelMapsAScannedResponseThroughThePureListLogic() async {
        let scanner = FakeWifiScanner(response: .scanned(
            networks: [
                WifiScannedNetwork(ssid: "Home", rssi: -42, isSecure: true),
                WifiScannedNetwork(ssid: "Cafe", rssi: -70, isSecure: false)
            ],
            currentSSID: "Home"))
        let model = WifiScanModel(scanner: scanner)

        let state = await model.scan()

        guard case .networks(let rows) = state else {
            Issue.record("expected a network list, got \(state)")
            return
        }
        #expect(rows.map(\.ssid) == ["Home", "Cafe"])
        #expect(rows.first?.isCurrent == true)
    }
}

@Suite("Wi-Fi settings links")
struct WifiSettingsLinkTests {
    @Test func locationServicesPaneHasThePrivacyDeepLink() {
        #expect(WidgetSettingsPane.locationServices.url?.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        #expect(WidgetSettingsPane.locationServices.fallbackURL == nil)
    }
}

@Suite("Wi-Fi scan cache")
@MainActor
struct WifiScanCacheTests {
    private func scanned() -> WifiScanResponse {
        .scanned(networks: [WifiScannedNetwork(ssid: "Home", rssi: -42, isSecure: true)],
                 currentSSID: "Home")
    }

    @Test func freshCachePaintsAtOnceWithItsAge() async {
        let scanner = FakeWifiScanner(response: scanned())
        let model = WifiScanModel(scanner: scanner)
        let now = Date()
        _ = await model.scan(now: now)

        guard let cached = model.cachedNetworksIfFresh(now: now) else {
            Issue.record("expected a fresh cache right after a scan")
            return
        }
        #expect(cached.networks.map(\.ssid) == ["Home"])
        #expect(cached.summary == "Updated 0s ago")
        #expect(model.cachedStateIfFresh(now: now) == .networks(cached.networks))
    }

    @Test func cacheExpiresAfterTenMinutes() async {
        let scanner = FakeWifiScanner(response: scanned())
        let model = WifiScanModel(scanner: scanner)
        let finished = Date()
        _ = await model.scan(now: finished)

        #expect(model.cachedNetworksIfFresh(now: finished.addingTimeInterval(9 * 60 + 59)) != nil,
                "a scan from 9:59 ago still paints at once")
        #expect(model.cachedNetworksIfFresh(now: finished.addingTimeInterval(10 * 60 + 1)) == nil,
                "a scan from 10:01 ago no longer paints")
    }

    @Test func ageSummaryCountsSecondsThenWholeMinutes() {
        let cache = WifiScanCache(networks: [], finishedAt: Date(timeIntervalSince1970: 1_000))
        #expect(cache.ageSummary(now: Date(timeIntervalSince1970: 1_005)) == "Updated 5s ago")
        #expect(cache.ageSummary(now: Date(timeIntervalSince1970: 1_059)) == "Updated 59s ago")
        #expect(cache.ageSummary(now: Date(timeIntervalSince1970: 1_180)) == "Updated 3m ago")
    }

    @Test func failedScansLeaveThePreviousCacheAlone() async {
        let scanner = FakeWifiScanner(response: scanned())
        let model = WifiScanModel(scanner: scanner)
        _ = await model.scan(now: Date())
        // The fake always returns the same response; a failure must not clear
        // the cache, so this is asserted through a second model whose only
        // scan fails from the start.
        let failing = WifiScanModel(scanner: FakeWifiScanner(response: .failed("boom")))
        _ = await failing.scan(now: Date())
        #expect(failing.lastCompleted == nil)
        #expect(failing.cachedNetworksIfFresh() == nil)
        #expect(model.lastCompleted != nil)
    }

    @Test func markCurrentRepointsTheCacheWithoutRescanning() async {
        let scanner = FakeWifiScanner(response: scanned())
        let model = WifiScanModel(scanner: scanner)
        _ = await model.scan(now: Date())

        model.markCurrent(ssid: "Home")

        #expect(model.lastCompleted?.currentSSID == "Home")
        #expect(model.lastCompleted?.networks.first?.isCurrent == true)
    }
}

@Suite("Wi-Fi join history")
struct WifiJoinHistoryTests {
    @Test func recordedMovesToFrontDedupesAndCapsAtFive() {
        let base = Date(timeIntervalSince1970: 1_000)
        var joins: [WifiJoinedNetwork] = []
        for name in ["A", "B", "C", "D", "E", "F"] {
            joins = WifiJoinHistory.recorded(joins, ssid: name, at: base)
        }

        #expect(joins.map(\.ssid) == ["F", "E", "D", "C", "B"])
        #expect(joins.first?.lastJoinedAt == base)

        let rejoined = WifiJoinHistory.recorded(joins, ssid: "B", at: base.addingTimeInterval(60))
        #expect(rejoined.map(\.ssid) == ["B", "F", "E", "D", "C"],
                "rejoining moves the network to the front without duplicating it")
    }

    @Test func recordedIgnoresBlankNames() {
        #expect(WifiJoinHistory.recorded([], ssid: "   ") == [])
    }

    @Test func recentSkipsNetworksThatAreInRangeNow() {
        let joins = [
            WifiJoinedNetwork(ssid: "Home", lastJoinedAt: Date()),
            WifiJoinedNetwork(ssid: "Cafe", lastJoinedAt: Date()),
            WifiJoinedNetwork(ssid: "Office", lastJoinedAt: Date())
        ]

        let recent = WifiJoinHistory.recent(joins, excludingInRange: ["Home", "Office"])

        #expect(recent.map(\.ssid) == ["Cafe"],
                "in-range networks already have live rows; only the rest show below")
    }

    @Test func fileStoreRoundTripsOnlySSIDsAndTimes() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("divot-wifi-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileWifiJoinHistoryStore(fileURL: url)
        #expect(store.load() == [])

        let joins = [WifiJoinedNetwork(ssid: "Home", lastJoinedAt: Date(timeIntervalSince1970: 2_000))]
        store.save(joins)
        #expect(FileWifiJoinHistoryStore(fileURL: url).load() == joins)

        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.lowercased().contains("password"),
                "the join history holds no secret, only SSIDs and times")
    }

    @Test func inMemoryStoreKeepsTheLatestSave() {
        let store = InMemoryWifiJoinHistoryStore()
        let joins = [WifiJoinedNetwork(ssid: "Cafe", lastJoinedAt: Date())]
        store.save(joins)
        #expect(store.load() == joins)
    }
}
