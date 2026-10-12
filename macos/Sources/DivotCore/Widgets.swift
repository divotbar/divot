import Foundation

// MARK: - Item identity

/// Identity of a built-in bar item.
///
/// The raw values are the identifiers used by the versioned configuration
/// contract (`workspaces`, `front-app`, `battery`, `network`, `volume`,
/// `clock`), so the shared model, the renderer, and the provider registry all
/// agree on one spelling. `workspaces` is delivered by the workspace adapter
/// milestone; its content is deliberately not modelled here so this file does
/// not pre-empt that task.
public enum BarItemID: String, CaseIterable, Codable, Sendable {
    case workspaces
    case frontApp = "front-app"
    case battery
    case network
    case volume
    case clock
    case date
    case time
    case appearance

    /// Human label for settings and placeholder/accessible text.
    public var displayName: String {
        switch self {
        case .workspaces: return "Workspaces"
        case .frontApp: return "Front app"
        case .battery: return "Battery"
        case .network: return "Network"
        case .volume: return "Volume"
        case .clock: return "Clock"
        case .date: return "Date"
        case .time: return "Time"
        case .appearance: return "Appearance"
        }
    }

    /// The items the Settings bar list offers.
    ///
    /// The legacy combined `clock` stays in `allCases` only so older documents
    /// can migrate to `time`/`date`; it is never placed or shown after the
    /// split (#0033).
    public static var placeableItems: [BarItemID] {
        allCases.filter { $0 != .clock }
    }

    /// True for the battery, network and volume items, whose SF Symbol is drawn
    /// at the native menu-bar symbol size (#0057). Every other item keeps the
    /// compact square status-icon box.
    public var drawsNativeStatusSymbol: Bool {
        switch self {
        case .battery, .network, .volume: return true
        case .workspaces, .frontApp, .clock, .date, .time, .appearance: return false
        }
    }
}

// MARK: - Unavailable states

/// Why a widget has no usable data right now.
///
/// Every case is a *contextual* state the bar renders honestly instead of the
/// whole bar failing: a missing permission, hardware without that feature, a
/// manager that is not running, or a provider error. `noData` is the transient
/// state before the first snapshot arrives.
public struct WidgetUnavailable: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// Nothing has been produced yet (before the first snapshot).
        case noData
        /// The hardware/platform has no such feature (not an error).
        case notSupported
        /// A permission the feature genuinely needs was denied.
        case permissionDenied
        /// An external manager (e.g. a window manager) is not available.
        case managerUnavailable
        /// The provider itself failed.
        case failed
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }

    /// Short, non-alarming text for the bar/overflow. Accessible text and the
    /// full message are exposed where there is room.
    public var shortText: String {
        switch kind {
        case .noData: return "…"
        case .notSupported: return "—"
        case .permissionDenied: return "!"
        case .managerUnavailable: return "—"
        case .failed: return "!"
        }
    }
}

// MARK: - Snapshots

/// The frontmost application. Emitted on activation changes.
public struct FrontAppSnapshot: Equatable, Sendable {
    public let name: String
    public let bundleIdentifier: String?
    public let processIdentifier: Int32?

    public init(name: String, bundleIdentifier: String? = nil, processIdentifier: Int32? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

/// Whether the machine has an internal battery at all.
public enum BatteryPresence: Equatable, Sendable {
    /// A battery is present (laptops).
    case internalBattery
    /// No battery (desktop Macs). A sensible resting state, not an error.
    case none
}

/// Power state. `percentage` is `nil` when no battery exists or the value is
/// momentarily unknown.
///
/// Keep-awake (the Caffeine-style toggle) rides on the battery item rather than
/// being a second bar item, so its live state travels with this snapshot and the
/// indicator and the power reading always agree about what the bar is showing.
public struct BatterySnapshot: Equatable, Sendable {
    public let presence: BatteryPresence
    public let percentage: Int?
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let isFullyCharged: Bool
    /// True while Divot holds its power assertion and the machine is kept awake.
    public let isKeepingAwake: Bool

    public init(presence: BatteryPresence,
                percentage: Int?,
                isCharging: Bool = false,
                isPluggedIn: Bool = false,
                isFullyCharged: Bool = false,
                isKeepingAwake: Bool = false) {
        self.presence = presence
        self.percentage = percentage.map { max(0, min(100, $0)) }
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isFullyCharged = isFullyCharged
        self.isKeepingAwake = isKeepingAwake
    }

    /// The same power reading with the keep-awake flag replaced. The provider
    /// merges the shared keep-awake state into whatever the IOKit read returned.
    public func withKeepingAwake(_ active: Bool) -> BatterySnapshot {
        BatterySnapshot(presence: presence,
                        percentage: percentage,
                        isCharging: isCharging,
                        isPluggedIn: isPluggedIn,
                        isFullyCharged: isFullyCharged,
                        isKeepingAwake: active)
    }

    /// Desktop Mac: no battery, so the bar shows a settled no-battery state.
    public static let noBattery = BatterySnapshot(presence: .none, percentage: nil)
}

/// Best-effort transport kind for the active network path.
public enum NetworkKind: String, Equatable, Sendable {
    case wifi
    case ethernet
    case cellular
    case other
}

/// Connectivity and transport state.
///
/// The SSID/Wi-Fi network name is optional and location-gated. Include it only
/// when the user has explicitly enabled it and the permission is available.
public struct NetworkSnapshot: Equatable, Sendable {
    public let isConnected: Bool
    public let kind: NetworkKind
    public let interfaceName: String?
    /// The path is metered (e.g. a personal hotspot).
    public let isExpensive: Bool
    /// The path is in a low-data mode.
    public let isConstrained: Bool
    /// The current Wi-Fi network name (SSID), when connected to Wi-Fi and available.
    public let wifiName: String?
    /// Location authorization status (for Wi-Fi name reading).
    public let locationAuthorizationStatus: String?

    public init(isConnected: Bool,
                kind: NetworkKind = .other,
                interfaceName: String? = nil,
                isExpensive: Bool = false,
                isConstrained: Bool = false,
                wifiName: String? = nil,
                locationAuthorizationStatus: String? = nil) {
        self.isConnected = isConnected
        self.kind = kind
        self.interfaceName = interfaceName
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.wifiName = wifiName
        self.locationAuthorizationStatus = locationAuthorizationStatus
    }
}

/// Output audio state.
public struct VolumeSnapshot: Equatable, Sendable {
    public let hasOutputDevice: Bool
    public let outputDeviceName: String?
    /// Normalized 0...1 output level.
    public let level: Double
    public let isMuted: Bool

    public init(hasOutputDevice: Bool, outputDeviceName: String? = nil,
                level: Double, isMuted: Bool = false) {
        self.hasOutputDevice = hasOutputDevice
        self.outputDeviceName = outputDeviceName
        self.level = max(0, min(1, level))
        self.isMuted = isMuted
    }

    /// No output device (e.g. everything unplugged).
    public static let noOutput = VolumeSnapshot(hasOutputDevice: false, level: 0)
}

/// A local instant for the clock.
public struct ClockSnapshot: Equatable, Sendable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// The system appearance mode (light or dark).
public enum AppearanceMode: String, Equatable, Sendable {
    case light
    case dark
}

/// The current system appearance.
public struct AppearanceSnapshot: Equatable, Sendable {
    public let mode: AppearanceMode

    public init(mode: AppearanceMode) {
        self.mode = mode
    }
}

// MARK: - Content

/// The payload kind a content case carries.
public enum WidgetContentKind: String, Equatable, Sendable {
    case frontApp
    case battery
    case network
    case volume
    case clock
    case date
    case time
    case appearance
    case unavailable
}

/// One widget's current content. Small and immutable, emitted by a provider.
public enum WidgetContent: Equatable, Sendable {
    case frontApp(FrontAppSnapshot)
    case battery(BatterySnapshot)
    case network(NetworkSnapshot)
    case volume(VolumeSnapshot)
    case clock(ClockSnapshot)
    case date(ClockSnapshot)
    case time(ClockSnapshot)
    case appearance(AppearanceSnapshot)
    case unavailable(WidgetUnavailable)

    public var kind: WidgetContentKind {
        switch self {
        case .frontApp: return .frontApp
        case .battery: return .battery
        case .network: return .network
        case .volume: return .volume
        case .clock: return .clock
        case .date: return .date
        case .time: return .time
        case .appearance: return .appearance
        case .unavailable: return .unavailable
        }
    }

    public var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }

    /// Whether this content is a valid payload for `id`. A battery provider may
    /// emit battery data or an unavailable state, never clock data; the pipeline
    /// rejects a mismatched emission instead of rendering nonsense.
    public func isCompatible(with id: BarItemID) -> Bool {
        if isUnavailable { return true }
        switch (id, self) {
        case (.frontApp, .frontApp), (.battery, .battery), (.network, .network),
             (.volume, .volume), (.clock, .clock), (.date, .date), (.time, .time),
             (.appearance, .appearance):
            return true
        default:
            return false
        }
    }
}

/// A rendered value: the content plus the identity and monotonic revision the
/// bar uses to tell "changed" from "same".
public struct WidgetState: Equatable, Sendable {
    public let id: BarItemID
    public let revision: UInt64
    public let content: WidgetContent

    public init(id: BarItemID, revision: UInt64, content: WidgetContent) {
        self.id = id
        self.revision = revision
        self.content = content
    }
}

// MARK: - Layout

/// Which half of the bar an item lives on.
public enum BarSide: String, Equatable, Sendable, CaseIterable {
    case left
    case right
}

/// The ordered left/right item groups for one display.
///
/// This is the shared default the first-launch bar uses; the versioned
/// configuration model (its own milestone) loads into the same shape.
public struct BarLayout: Equatable, Sendable {
    public var left: [BarItemID]
    public var right: [BarItemID]

    public init(left: [BarItemID], right: [BarItemID]) {
        self.left = left
        self.right = right
    }

    /// Default left/right groups from the first-launch story.
    public static let `default` = BarLayout(left: [.workspaces, .frontApp],
                                            right: [.battery, .time, .network, .volume])

    public func items(on side: BarSide) -> [BarItemID] {
        switch side {
        case .left: return left
        case .right: return right
        }
    }

    /// The side an item is placed on, or `nil` when it is not placed at all.
    public func side(of id: BarItemID) -> BarSide? {
        if left.contains(id) { return .left }
        if right.contains(id) { return .right }
        return nil
    }

    /// Every placed item, with its side, in left-then-right order.
    public var placement: [(id: BarItemID, side: BarSide)] {
        left.map { ($0, .left) } + right.map { ($0, .right) }
    }
}
