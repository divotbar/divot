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
                timeout: Duration = .seconds(20)) {
        self.locationTracker = locationTracker
        self.timeout = timeout
    }

    /// The scan bound, exposed so tests pin the raised timeout.
    var timeoutForTesting: Duration { timeout }

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

}

/// Joins a Wi-Fi network with the public CoreWLAN API only.
///
/// Association changes system state, so this runs on the same serial queue as
/// the scanner, off the main actor. Passwords arrive only as this call's
/// argument and are never persisted or logged: on success macOS keeps the
/// credential in the keychain, and Divot records only the SSID and time in
/// its own join history.
public final class CoreWLANWifiConnector: WifiNetworkConnecting, @unchecked Sendable {
    private let connectQueue = DispatchQueue(label: "divot.wifi-connect", qos: .userInitiated)

    public init() {}

    public func connect(ssid: String, isSecure: Bool, password: String?) async -> WifiConnectOutcome {
        await withCheckedContinuation { continuation in
            connectQueue.async {
                continuation.resume(returning: Self.associate(ssid: ssid, isSecure: isSecure, password: password))
            }
        }
    }

    private static func associate(ssid: String, isSecure: Bool, password: String?) -> WifiConnectOutcome {
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failed("That network has no name to join.") }
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            return .failed("Wi-Fi is not available on this Mac.")
        }
        do {
            // Always attempt the association first, even for a secured
            // network with no password: a keychain-saved network joins
            // without one, and only a rejected passwordless attempt (the
            // authorization-failure path below) asks for a password.
            // Association takes a `CWNetwork`, so run a directed scan for the
            // SSID first and join the match. A network that left range since
            // the list painted reports honestly instead of joining the wrong one.
            let found = try interface.scanForNetworks(withSSID: Data(trimmed.utf8))
            guard let target = found.first(where: { $0.ssid == trimmed }) ?? found.first else {
                return .failed("“\(trimmed)” is not in range right now.")
            }
            try interface.associate(to: target, password: password)
            return .connected(ssid: trimmed)
        } catch {
            let message = error.localizedDescription
            if password == nil, isAuthorizationFailure(message) {
                return .requiresPassword
            }
            return .failed(message)
        }
    }

    /// CoreWLAN reports a rejected passwordless association through several
    /// localized wordings; match the stable core ("password", "credential",
    /// "authoriz", "authenticat") rather than one exact string.
    private static func isAuthorizationFailure(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("password") || lowered.contains("credential")
            || lowered.contains("authoriz") || lowered.contains("authenticat")
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
