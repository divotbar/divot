import CoreLocation
import CoreWLAN
import DivotCore
import Foundation

/// Scans nearby Wi-Fi networks with the public CoreWLAN API only.
///
/// The scan is requested once per popover open, never on a timer, and the
/// blocking `scanForNetworks` call runs on its own serial queue rather than the
/// main actor. A scan is permission-gated first because macOS only returns
/// network names to an app with Location authorization; without it the popover
/// shows the permission state instead of an empty list. The timeout bounds a
/// wedged scan so the popover always settles.
public final class CoreWLANNetworkScanner: WifiNetworkScanning, @unchecked Sendable {
    private let locationTracker: any LocationAuthorizationTracking
    private let timeout: Duration
    private let scanQueue = DispatchQueue(label: "divot.wifi-scan", qos: .userInitiated)

    public init(locationTracker: any LocationAuthorizationTracking = LocationAuthorizationTracker(),
                timeout: Duration = .seconds(8)) {
        self.locationTracker = locationTracker
        self.timeout = timeout
    }

    public func scan() async -> WifiScanResponse {
        guard locationTracker.currentStatus().isAuthorizedForWifiName else {
            return .permissionDenied
        }
        return await raceWithTimeout { [scanQueue] in
            await withCheckedContinuation { continuation in
                scanQueue.async {
                    continuation.resume(returning: Self.readNetworks())
                }
            }
        }
    }

    /// Read the interface and scan synchronously, on the serial queue. The
    /// current network is read from `interface.ssid()`, which the same Location
    /// gate protects.
    private static func readNetworks() -> WifiScanResponse {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            // No Wi-Fi interface (a desktop, or a build with no backing device).
            return .unavailable
        }
        let currentSSID = interface.ssid()
        do {
            let found = try interface.scanForNetworks(withSSID: nil)
            let scanned: [WifiScannedNetwork] = found.compactMap { network in
                // Hidden networks report a nil or empty SSID; skip them rather
                // than invent a placeholder name.
                guard let ssid = network.ssid, !ssid.isEmpty else { return nil }
                let isSecure = !network.supportsSecurity(.none)
                return WifiScannedNetwork(ssid: ssid, rssi: network.rssiValue, isSecure: isSecure)
            }
            return .scanned(networks: scanned, currentSSID: currentSSID)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Resume once with whichever finishes first: the scan or the timeout. The
    /// blocked scan task keeps running to completion but its late result is
    /// dropped, so a hung CoreWLAN call cannot hold the popover open.
    private func raceWithTimeout(
        _ operation: @escaping @Sendable () async -> WifiScanResponse
    ) async -> WifiScanResponse {
        await withCheckedContinuation { continuation in
            let gate = ResumeGate(continuation: continuation)
            Task {
                let result = await operation()
                gate.resume(with: result)
            }
            Task {
                try? await Task.sleep(for: timeout)
                gate.resume(with: .failed("The scan timed out."))
            }
        }
    }

    /// Guards a `CheckedContinuation` so only the first of two racing tasks
    /// resumes it. The loser's value is ignored.
    private final class ResumeGate: @unchecked Sendable {
        private let lock = NSLock()
        private var finished = false
        private let continuation: CheckedContinuation<WifiScanResponse, Never>

        init(continuation: CheckedContinuation<WifiScanResponse, Never>) {
            self.continuation = continuation
        }

        func resume(with value: WifiScanResponse) {
            lock.lock()
            if finished {
                lock.unlock()
                return
            }
            finished = true
            lock.unlock()
            continuation.resume(returning: value)
        }
    }
}
