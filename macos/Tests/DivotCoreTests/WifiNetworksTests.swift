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
