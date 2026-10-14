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

/// One row of the Wi-Fi popover: a network after dedupe and marking.
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

// MARK: - Connect seam

/// What one connect attempt reported.
public enum WifiConnectOutcome: Equatable, Sendable {
    /// Associated with `ssid`. The popover marks it current and re-renders.
    case connected(ssid: String)
    /// The network needs a password and none was supplied. The popover asks
    /// for one through its Divot-styled dialog, then retries with it.
    case requiresPassword
    /// Association failed; the message is the macOS reason, shown verbatim.
    /// It never contains a password.
    case failed(String)
}

/// The seam the Wi-Fi popover connects through.
///
/// The live implementation associates with CoreWLAN; tests supply a fake.
/// Passwords pass only through this call's argument and are never persisted
/// or logged.
public protocol WifiNetworkConnecting: Sendable {
    func connect(ssid: String, isSecure: Bool, password: String?) async -> WifiConnectOutcome
}

// MARK: - Join history (Divot-joined networks only)

/// One network Divot itself connected to, with the time it succeeded.
///
/// Only the SSID and the time are stored. Passwords are never stored here:
/// macOS keeps credentials in the keychain, and this record holds no secret.
public struct WifiJoinedNetwork: Equatable, Sendable, Codable {
    public let ssid: String
    public let lastJoinedAt: Date

    public init(ssid: String, lastJoinedAt: Date) {
        self.ssid = ssid
        self.lastJoinedAt = lastJoinedAt
    }
}

/// Pure shaping for the short recent list of Divot-joined networks.
///
/// The system holds hundreds of saved profiles, which are too many for the
/// list, so the popover shows only networks Divot connected to itself.
public enum WifiJoinHistory {
    /// How many recent joins the popover shows at most.
    public static let maximumRecentJoins = 5

    /// Record a successful connect: move `ssid` to the front with time `at`,
    /// drop duplicates, and cap the list.
    public static func recorded(_ joins: [WifiJoinedNetwork],
                               ssid: String,
                               at date: Date = Date()) -> [WifiJoinedNetwork] {
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return joins }
        var updated = joins.filter { $0.ssid != trimmed }
        updated.insert(WifiJoinedNetwork(ssid: trimmed, lastJoinedAt: date), at: 0)
        return Array(updated.prefix(maximumRecentJoins))
    }

    /// The joins worth showing: most recent first, skipping SSIDs that are in
    /// range right now (they already have rows in the live list), capped.
    public static func recent(_ joins: [WifiJoinedNetwork],
                             excludingInRange inRangeSSIDs: Set<String>) -> [WifiJoinedNetwork] {
        joins.filter { !inRangeSSIDs.contains($0.ssid) }.prefix(maximumRecentJoins).map { $0 }
    }
}

/// The seam that persists Divot-joined networks.
///
/// The only writers are successful connects the popover makes itself; the
/// only fields are SSIDs and times. No password ever reaches this store.
public protocol WifiJoinHistoryStoring: Sendable {
    func load() -> [WifiJoinedNetwork]
    func save(_ joins: [WifiJoinedNetwork])
}

/// Windowless tests and previews use this; production uses
/// `FileWifiJoinHistoryStore`.
public final class InMemoryWifiJoinHistoryStore: WifiJoinHistoryStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var joins: [WifiJoinedNetwork]

    public init(joins: [WifiJoinedNetwork] = []) {
        self.joins = joins
    }

    public func load() -> [WifiJoinedNetwork] {
        lock.lock(); defer { lock.unlock() }
        return joins
    }

    public func save(_ joins: [WifiJoinedNetwork]) {
        lock.lock(); defer { lock.unlock() }
        self.joins = joins
    }
}

/// The production store: a small JSON document under Application Support,
/// separate from Divot's versioned configuration (which never holds SSIDs,
/// times, or passwords from this flow).
public final class FileWifiJoinHistoryStore: WifiJoinHistoryStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = base.appendingPathComponent("Divot/wifi-recent-joins.json")
        }
        self.fileManager = fileManager
    }

    public func load() -> [WifiJoinedNetwork] {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([WifiJoinedNetwork].self, from: data)) ?? []
    }

    public func save(_ joins: [WifiJoinedNetwork]) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(joins) else { return }
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Scan cache (fast first paint)

/// The last completed scan, kept so the next open can paint at once.
///
/// The popover always runs a live scan on open; when this cache finished
/// within `freshnessTTL` it is shown immediately with its age ("Updated Xs
/// ago") and the live result replaces it in place.
public struct WifiScanCache: Equatable, Sendable {
    /// A scan counts as fresh for this long after it finishes.
    public static let freshnessTTL: TimeInterval = 10 * 60

    /// The shaped rows the last scan settled on.
    public let networks: [WifiNetwork]
    /// When that scan finished.
    public let finishedAt: Date
    /// The associated SSID at the time, if any.
    public let currentSSID: String?

    public init(networks: [WifiNetwork], finishedAt: Date, currentSSID: String? = nil) {
        self.networks = networks
        self.finishedAt = finishedAt
        self.currentSSID = currentSSID
    }

    /// True when `finishedAt` is within the TTL at `now`.
    public func isFresh(now: Date = Date()) -> Bool {
        now.timeIntervalSince(finishedAt) <= Self.freshnessTTL
    }

    /// "Updated 5s ago" / "Updated 3m ago": seconds under a minute, whole
    /// minutes beyond that.
    public func ageSummary(now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(finishedAt)))
        if elapsed < 60 { return "Updated \(elapsed)s ago" }
        return "Updated \(elapsed / 60)m ago"
    }
}

// MARK: - Model

/// Runs one scan at a time through a `WifiNetworkScanning` seam and holds the
/// latest state. The popover owns one of these and calls `scan()` on open.
/// The last completed list scan is cached with its finish time so the next
/// open can paint it at once while the live scan runs in the background.
@MainActor
public final class WifiScanModel {
    public private(set) var state: WifiScanState = .idle
    /// The last completed list scan, if any. Only successful `.networks`
    /// states are cached; permission, unavailable, and failure states leave
    /// the previous cache (or its absence) alone.
    public private(set) var lastCompleted: WifiScanCache?

    private let scanner: any WifiNetworkScanning

    public init(scanner: any WifiNetworkScanning) {
        self.scanner = scanner
    }

    /// The cached list when the last completed scan is still fresh, else nil.
    /// The popover shows this at once, then runs the live scan regardless.
    public func cachedStateIfFresh(now: Date = Date()) -> WifiScanState? {
        guard let cache = lastCompleted, cache.isFresh(now: now) else { return nil }
        return .networks(cache.networks)
    }

    /// The cached rows with their age line, for the immediate first paint.
    public func cachedNetworksIfFresh(now: Date = Date()) -> (networks: [WifiNetwork], summary: String)? {
        guard let cache = lastCompleted, cache.isFresh(now: now) else { return nil }
        return (cache.networks, cache.ageSummary(now: now))
    }

    /// Re-mark the current network after the popover joins one itself, so the
    /// cache keeps pointing at the associated network until the next scan.
    public func markCurrent(ssid: String) {
        guard let cache = lastCompleted else { return }
        let remarked = cache.networks.map {
            WifiNetwork(ssid: $0.ssid, rssi: $0.rssi,
                        isSecure: $0.isSecure, isCurrent: $0.ssid == ssid)
        }
        lastCompleted = WifiScanCache(networks: remarked,
                                      finishedAt: cache.finishedAt,
                                      currentSSID: ssid)
    }

    /// Scan once and return the settled state. Sets `.scanning` first so the UI
    /// can show progress, then maps the response through the pure list logic.
    /// A settled list refreshes the cache with its finish time.
    @discardableResult
    public func scan(now: Date = Date()) async -> WifiScanState {
        state = .scanning
        let response = await scanner.scan()
        state = WifiNetworks.state(from: response)
        if case .networks(let networks) = state {
            let currentSSID: String?
            if case .scanned(_, let ssid) = response {
                currentSSID = ssid
            } else {
                currentSSID = nil
            }
            lastCompleted = WifiScanCache(networks: networks, finishedAt: now, currentSSID: currentSSID)
        }
        return state
    }
}
