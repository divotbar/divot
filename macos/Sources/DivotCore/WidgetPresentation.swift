import Foundation

/// Whether the battery item shows its percentage.
public struct BatteryFormatOptions: Equatable, Sendable {
    public var showPercentage: Bool

    public init(showPercentage: Bool = true) {
        self.showPercentage = showPercentage
    }

    public static let `default` = BatteryFormatOptions()
}

/// Whether the frontmost-application item shows its icon and/or its name.
public struct FrontAppFormatOptions: Equatable, Sendable {
    public var showIcon: Bool
    public var showName: Bool

    public init(showIcon: Bool = true, showName: Bool = true) {
        self.showIcon = showIcon
        self.showName = showName
    }

    public static let `default` = FrontAppFormatOptions()
}

/// Whether the network item shows the Wi-Fi network name.
public struct NetworkFormatOptions: Equatable, Sendable {
    public var showWifiName: Bool

    public init(showWifiName: Bool = false) {
        self.showWifiName = showWifiName
    }

    public static let `default` = NetworkFormatOptions()
}

/// Whether the volume item shows its percentage and/or muted state.
public struct VolumeFormatOptions: Equatable, Sendable {
    public var showPercent: Bool
    public var showMuted: Bool

    public init(showPercent: Bool = true, showMuted: Bool = true) {
        self.showPercent = showPercent
        self.showMuted = showMuted
    }

    public static let `default` = VolumeFormatOptions()
}

/// Options the presenter needs beyond the snapshot itself.
public struct WidgetPresentationOptions: Equatable, Sendable {
    public var clock: ClockFormatOptions
    public var date: ClockFormatOptions
    public var dateFormatPattern: String?
    public var time: ClockFormatOptions
    public var timeFormat: TimeConfiguration.Format
    public var customTimePattern: String?
    public var frontApp: FrontAppFormatOptions
    public var battery: BatteryFormatOptions
    public var network: NetworkFormatOptions
    public var volume: VolumeFormatOptions
    public var locale: Locale
    public var timeZone: TimeZone

    public init(clock: ClockFormatOptions = .default,
                date: ClockFormatOptions = ClockFormatOptions(weekday: true, date: true, seconds: false),
                dateFormatPattern: String? = nil,
                time: ClockFormatOptions = ClockFormatOptions(weekday: false, date: false, seconds: false),
                timeFormat: TimeConfiguration.Format = .twentyFourHour,
                customTimePattern: String? = nil,
                frontApp: FrontAppFormatOptions = .default,
                battery: BatteryFormatOptions = .default,
                network: NetworkFormatOptions = .default,
                volume: VolumeFormatOptions = .default,
                locale: Locale = .current,
                timeZone: TimeZone = .current) {
        self.clock = clock
        self.date = date
        self.dateFormatPattern = dateFormatPattern
        self.time = time
        self.timeFormat = timeFormat
        self.customTimePattern = customTimePattern
        self.frontApp = frontApp
        self.battery = battery
        self.network = network
        self.volume = volume
        self.locale = locale
        self.timeZone = timeZone
    }

    public static let `default` = WidgetPresentationOptions()
}

/// A small state indicator drawn beside an item's main content.
///
/// The keep-awake cup is the first user: it appears next to the battery when
/// keep-awake is on. The color is a semantic role, not a literal, so the
/// contrast audit and the upcoming theme milestone share one source.
public struct WidgetIndicator: Equatable, Sendable {
    /// The semantic color role the view resolves for the current appearance.
    public enum Role: String, Equatable, Sendable, CaseIterable {
        /// Keep-awake is on: the "active" role. Contrast-audited per variant.
        case keepAwakeActive = "keep-awake-active"

        /// The indicator hex for the given appearance variant.
        public func hex(dark: Bool) -> String {
            switch self {
            case .keepAwakeActive: return KeepAwakeIndicatorPalette.activeHex(dark: dark)
            }
        }
    }

    public let symbolName: String
    public let role: Role
    public let accessibilityLabel: String

    public init(symbolName: String, role: Role, accessibilityLabel: String) {
        self.symbolName = symbolName
        self.role = role
        self.accessibilityLabel = accessibilityLabel
    }
}

/// A small symbol drawn over an item's leading symbol.
///
/// The charging bolt is the first user: it is a separate element on top of the
/// battery outline, and the whole battery symbol plus the bolt draw in the fixed
/// charging green (#0074) — one constant in `ChargingIndicatorPalette`, never
/// the theme accent. It is deliberately distinct from `WidgetIndicator`, which
/// sits after the text rather than over the icon.
public struct WidgetBadge: Equatable, Sendable {
    /// The semantic color role the view resolves for the current appearance.
    public enum Role: String, Equatable, Sendable {
        /// Charging: the whole battery symbol and the bolt draw in the fixed
        /// charging green, independent of the theme family (#0074).
        case charging
    }

    public let symbolName: String
    public let role: Role

    public init(symbolName: String, role: Role) {
        self.symbolName = symbolName
        self.role = role
    }
}

/// How one item should look: an optional SF Symbol, compact text, and the
/// accessible description. Kept pure so it is testable without a window server
/// and so every widget shares one presentation path.
public struct WidgetPresentation: Equatable, Sendable {
    /// SF Symbol name, when the item shows a symbol. A view that cannot resolve
    /// the symbol falls back to text rather than drawing nothing.
    public let symbolName: String?
    /// Bundle identifier of an application whose real icon the view should
    /// resolve (front-app with `showIcon`). The presenter stays pure: it names
    /// the bundle, the AppKit view loads the image.
    public let iconBundleIdentifier: String?
    public let text: String
    public let accessibilityLabel: String
    /// Render with the error role (color plus a distinct glyph, never color only).
    public let isError: Bool
    /// An optional state indicator drawn after the text (e.g. the keep-awake cup).
    public let indicator: WidgetIndicator?
    /// An optional symbol drawn over the leading icon (e.g. the charging bolt).
    public let badge: WidgetBadge?

    public init(symbolName: String?,
                iconBundleIdentifier: String? = nil,
                text: String,
                accessibilityLabel: String,
                isError: Bool = false,
                indicator: WidgetIndicator? = nil,
                badge: WidgetBadge? = nil) {
        self.symbolName = symbolName
        self.iconBundleIdentifier = iconBundleIdentifier
        self.text = text
        self.accessibilityLabel = accessibilityLabel
        self.isError = isError
        self.indicator = indicator
        self.badge = badge
    }
}

/// Turns a widget state into text and an icon.
public enum WidgetPresenter {
    public static func present(id: BarItemID,
                               state: WidgetState?,
                               options: WidgetPresentationOptions = .default) -> WidgetPresentation {
        guard let state, state.id == id else {
            return missingPresentation(for: id)
        }
        switch state.content {
        case .frontApp(let snapshot):
            return frontAppPresentation(snapshot, options: options.frontApp)
        case .battery(let snapshot):
            return batteryPresentation(snapshot, options: options.battery)
        case .network(let snapshot):
            return networkPresentation(snapshot, options: options.network)
        case .volume(let snapshot):
            return volumePresentation(snapshot, options: options.volume)
        case .clock(let snapshot):
            let text = ClockText.string(for: snapshot, options: options.clock,
                                        locale: options.locale, timeZone: options.timeZone)
            return clockPresentation(role: "Clock", text: text)
        case .date(let snapshot):
            let text = ClockText.string(for: snapshot, options: options.date,
                                        customPattern: options.dateFormatPattern,
                                        locale: options.locale, timeZone: options.timeZone)
            return clockPresentation(role: "Date", text: text)
        case .time(let snapshot):
            let text = ClockText.string(for: snapshot, options: options.time,
                                        locale: options.locale, timeZone: options.timeZone,
                                        timeFormat: options.timeFormat, customTimePattern: options.customTimePattern)
            return clockPresentation(role: "Time", text: text)
        case .appearance(let snapshot):
            return appearancePresentation(snapshot)
        case .unavailable(let unavailable):
            return unavailablePresentation(unavailable)
        }
    }

    /// A clock-family item (clock, date, or time) always announces its role and
    /// value. The configured format can legitimately render an empty string, so
    /// the label falls back to the role alone rather than going silent. Exposed
    /// to the label contract test.
    static func clockPresentation(role: String, text: String) -> WidgetPresentation {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return WidgetPresentation(symbolName: nil,
                                  text: text,
                                  accessibilityLabel: value.isEmpty ? role : "\(role): \(text)")
    }

    private static func frontAppPresentation(_ snapshot: FrontAppSnapshot,
                                             options: FrontAppFormatOptions) -> WidgetPresentation {
        WidgetPresentation(symbolName: nil,
                           iconBundleIdentifier: options.showIcon ? snapshot.bundleIdentifier : nil,
                           text: options.showName ? snapshot.name : "",
                           accessibilityLabel: "Frontmost application: \(snapshot.name)")
    }

    private static func missingPresentation(for id: BarItemID) -> WidgetPresentation {
        switch id {
        case .workspaces:
            return unavailablePresentation(.init(kind: .managerUnavailable,
                                                 message: "No workspace manager detected"))
        default:
            return unavailablePresentation(.init(kind: .noData, message: "\(id.displayName) is loading"))
        }
    }

    private static func unavailablePresentation(_ unavailable: WidgetUnavailable) -> WidgetPresentation {
        let isError = unavailable.kind == .failed
        let symbol: String?
        switch unavailable.kind {
        case .failed: symbol = "exclamationmark.triangle.fill"
        case .permissionDenied: symbol = "lock.fill"
        default: symbol = nil
        }
        return WidgetPresentation(symbolName: symbol,
                                  text: unavailable.shortText,
                                  accessibilityLabel: unavailable.message,
                                  isError: isError)
    }

    private static func batteryPresentation(_ snapshot: BatterySnapshot,
                                            options: BatteryFormatOptions) -> WidgetPresentation {
        // The keep-awake cup is Divot's only mark on the item. It must never be
        // sourced from system-wide sleep state: another app's assertion (for
        // example a call holding the microphone and speaker) never sets this
        // flag, so the cup is drawn only while Divot's own toggle is on (#0051).
        let indicator = snapshot.isKeepingAwake
            ? WidgetIndicator(symbolName: "cup.and.saucer.fill",
                              role: .keepAwakeActive,
                              accessibilityLabel: "Keep awake on")
            : nil
        switch snapshot.presence {
        case .none:
            var description = "No battery (desktop Mac)"
            if snapshot.isKeepingAwake { description += ", keep awake on" }
            return WidgetPresentation(symbolName: "powerplug.fill",
                                      text: "",
                                      accessibilityLabel: description,
                                      indicator: indicator)
        case .internalBattery:
            // The charging outline stays the full battery it drew before; the
            // bolt is split out so the whole symbol can be tinted charging green
            // on its own (#0058, #0074).
            let symbol = snapshot.isCharging ? "battery.100" : batterySymbol(percentage: snapshot.percentage)
            // The bolt rides over the battery outline; the view tints the whole
            // battery symbol with the fixed charging green, so charging reads as
            // a large green mark rather than a small badge (#0074).
            let badge = snapshot.isCharging
                ? WidgetBadge(symbolName: "bolt.fill", role: .charging)
                : nil
            let text = options.showPercentage ? (snapshot.percentage.map { "\($0)%" } ?? "") : ""
            let percentageText = snapshot.percentage.map { "\($0)%" } ?? "state unknown"
            var description = "Battery \(percentageText)"
            if snapshot.isCharging { description += ", charging" }
            else if snapshot.isPluggedIn { description += ", plugged in" }
            else if snapshot.isFullyCharged { description += ", charged" }
            if snapshot.isKeepingAwake { description += ", keep awake on" }
            return WidgetPresentation(symbolName: symbol,
                                      text: text,
                                      accessibilityLabel: description,
                                      indicator: indicator,
                                      badge: badge)
        }
    }

    private static func batterySymbol(percentage: Int?) -> String {
        switch percentage ?? 0 {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private static func networkPresentation(_ snapshot: NetworkSnapshot,
                                            options: NetworkFormatOptions) -> WidgetPresentation {
        guard snapshot.isConnected else {
            return WidgetPresentation(symbolName: "wifi.slash",
                                      text: "",
                                      accessibilityLabel: "No network connection",
                                      isError: true)
        }
        let symbol: String
        let kind: String
        switch snapshot.kind {
        case .wifi: symbol = "wifi"; kind = "Wi-Fi"
        case .ethernet: symbol = "cable.connector"; kind = "Ethernet"
        case .cellular: symbol = "antenna.radiowaves.left.and.right"; kind = "Cellular"
        case .other: symbol = "network"; kind = "Network"
        }
        var description = "\(kind) connected"
        if snapshot.isExpensive { description += ", metered" }
        if snapshot.isConstrained { description += ", low data mode" }

        let text: String
        if options.showWifiName, snapshot.kind == .wifi, let wifiName = snapshot.wifiName {
            text = wifiName
            description += ", Wi-Fi network: \(wifiName)"
        } else {
            text = ""
        }

        return WidgetPresentation(symbolName: symbol, text: text, accessibilityLabel: description)
    }

    private static func volumePresentation(_ snapshot: VolumeSnapshot,
                                           options: VolumeFormatOptions = .default) -> WidgetPresentation {
        guard snapshot.hasOutputDevice else {
            return WidgetPresentation(symbolName: "speaker.slash.fill",
                                      text: "",
                                      accessibilityLabel: "No audio output device",
                                      isError: true)
        }
        // When muted, the muted state takes priority over the percentage.
        // The accessibility label always includes the full state so screen readers announce it completely.
        if snapshot.isMuted {
            let text = options.showMuted ? "Muted" : ""
            return WidgetPresentation(symbolName: "speaker.slash.fill",
                                      text: text,
                                      accessibilityLabel: "Volume muted")
        }
        let symbol: String
        switch snapshot.level {
        case ..<0.001: symbol = "speaker.fill"
        case ..<0.34: symbol = "speaker.wave.1.fill"
        case ..<0.67: symbol = "speaker.wave.2.fill"
        default: symbol = "speaker.wave.3.fill"
        }
        let percent = Int((snapshot.level * 100).rounded())
        let text = options.showPercent ? "\(percent)%" : ""
        return WidgetPresentation(symbolName: symbol,
                                  text: text,
                                  accessibilityLabel: "Volume \(percent) percent")
    }

    private static func appearancePresentation(_ snapshot: AppearanceSnapshot) -> WidgetPresentation {
        let symbol: String
        let description: String
        switch snapshot.mode {
        case .light:
            symbol = "sun.max.fill"
            description = "Light mode"
        case .dark:
            symbol = "moon.fill"
            description = "Dark mode"
        }
        return WidgetPresentation(symbolName: symbol, text: "", accessibilityLabel: description)
    }
}
