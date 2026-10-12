import Foundation

// MARK: - Data

/// A nearby Wi-Fi network discovered by a scan, before dedupe and marking.
///
/// This is the raw, CoreWLAN-independent shape a scanner reports. Hidden
/// networks have no SSID and are therefore never represented here: CoreWLAN
/// reports their `ssid` as `nil`, so a scanner drops them rather than inventing
/// a placeholder name.
public struct WifiScannedNetwork: Equatable, Sendable {
    /// The network name. Never empty for a value that reaches this type.
    public let ssid: String
    /// Received signal strength in dBm; higher (closer to zero) is stronger.
    public let rssi: Int
    /// True when the network requires a password or other credentials.
    public let isSecure: Bool

    public init(ssid: String, rssi: Int, isSecure: Bool) {
        self.ssid = ssid
        self.rssi = rssi
        self.isSecure = isSecure
    }
}

/// One row of the read-only Wi-Fi popover: a network after dedupe and marking.
public struct WifiNetwork: Equatable, Sendable, Identifiable {
    public let ssid: String
    public let rssi: Int
    public let isSecure: Bool
    /// True for the network the interface is currently associated with.
    public let isCurrent: Bool

    public var id: String { ssid }
    /// 0–4 bars derived from `rssi`, mapped by `WifiNetworks.signalLevel`.
    public var signalLevel: Int { WifiNetworks.signalLevel(rssi: rssi) }

    public init(ssid: String, rssi: Int, isSecure: Bool, isCurrent: Bool) {
        self.ssid = ssid
        self.rssi = rssi
        self.isSecure = isSecure
        self.isCurrent = isCurrent
    }
}

/// What a scan call reported, in terms the menu can render honestly.
public enum WifiScanResponse: Equatable, Sendable {
    /// A completed scan. `currentSSID` is the associated network, if any; it is
    /// `nil` when the interface is not associated or the name is unavailable.
    case scanned(networks: [WifiScannedNetwork], currentSSID: String?)
    /// Location permission is missing, so macOS will not return network names.
    case permissionDenied
    /// There is no usable Wi-Fi interface (for example a desktop or a build
    /// without the framework's backing device).
    case unavailable
    /// The scan threw; the message is the underlying reason, shown verbatim.
    case failed(String)
}

/// The state the popover renders. Distinct from `WifiScanResponse` so the UI has
/// an explicit loading state and a settled list.
public enum WifiScanState: Equatable, Sendable {
    case idle
    case scanning
    case networks([WifiNetwork])
    case permissionDenied
    case unavailable
    case failed(String)
}

// MARK: - Seam

/// The seam the Wi-Fi popover scans through.
///
/// The live implementation uses CoreWLAN; tests supply a fake. `scan()` is
/// called once per popover open, never on a timer, and the implementation is
/// responsible for keeping any blocking CoreWLAN call off the main actor.
public protocol WifiNetworkScanning: Sendable {
    func scan() async -> WifiScanResponse
}

// MARK: - Pure list logic

/// Pure list shaping for a scan result. No CoreWLAN, no AppKit.
public enum WifiNetworks {
    /// Turn a raw scan response into the popover's state.
    public static func state(from response: WifiScanResponse) -> WifiScanState {
        switch response {
        case .scanned(let networks, let currentSSID):
            return .networks(organize(networks, currentSSID: currentSSID))
        case .permissionDenied:
            return .permissionDenied
        case .unavailable:
            return .unavailable
        case .failed(let message):
            return .failed(message)
        }
    }

    /// Shape raw scan entries into menu rows.
    ///
    /// Duplicate SSIDs are collapsed to the strongest signal (ties keep a secure
    /// entry, so a lock icon is never dropped); the current network is marked and
    /// sorted first; the remainder sort by signal descending, then by name.
    /// Entries with a blank SSID are hidden networks and are dropped.
    public static func organize(_ scanned: [WifiScannedNetwork],
                                currentSSID: String?) -> [WifiNetwork] {
        var strongest: [String: WifiScannedNetwork] = [:]
        for network in scanned {
            let ssid = network.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ssid.isEmpty else { continue }
            let candidate = WifiScannedNetwork(ssid: ssid,
                                               rssi: network.rssi,
                                               isSecure: network.isSecure)
            guard let existing = strongest[ssid] else {
                strongest[ssid] = candidate
                continue
            }
            if candidate.rssi > existing.rssi {
                strongest[ssid] = candidate
            } else if candidate.rssi == existing.rssi, candidate.isSecure, !existing.isSecure {
                strongest[ssid] = candidate
            }
        }

        let current = currentSSID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return strongest.values
            .map { entry in
                WifiNetwork(ssid: entry.ssid,
                            rssi: entry.rssi,
                            isSecure: entry.isSecure,
                            isCurrent: entry.ssid == current)
            }
            .sorted { lhs, rhs in
                if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
                if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
                return lhs.ssid.localizedCaseInsensitiveCompare(rhs.ssid) == .orderedAscending
            }
    }

    /// Map a dBm reading to 0–4 bars. The bands are the conventional consumer
    /// thresholds; 0 is a weak-but-visible network, not "no signal".
    public static func signalLevel(rssi: Int) -> Int {
        switch rssi {
        case (-50)...: return 4
        case (-60)...: return 3
        case (-70)...: return 2
        case (-80)...: return 1
        default: return 0
        }
    }
}

// MARK: - Model

/// Runs one scan at a time through a `WifiNetworkScanning` seam and holds the
/// latest state. The popover owns one of these and calls `scan()` on open.
@MainActor
public final class WifiScanModel {
    public private(set) var state: WifiScanState = .idle

    private let scanner: any WifiNetworkScanning

    public init(scanner: any WifiNetworkScanning) {
        self.scanner = scanner
    }

    /// Scan once and return the settled state. Sets `.scanning` first so the UI
    /// can show progress, then maps the response through the pure list logic.
    @discardableResult
    public func scan() async -> WifiScanState {
        state = .scanning
        let response = await scanner.scan()
        state = WifiNetworks.state(from: response)
        return state
    }
}
