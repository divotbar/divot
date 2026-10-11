import Foundation

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

/// Options the presenter needs beyond the snapshot itself.
public struct WidgetPresentationOptions: Equatable, Sendable {
    public var clock: ClockFormatOptions
    public var date: ClockFormatOptions
    public var time: ClockFormatOptions
    public var frontApp: FrontAppFormatOptions
    public var locale: Locale
    public var timeZone: TimeZone

    public init(clock: ClockFormatOptions = .default,
                date: ClockFormatOptions = ClockFormatOptions(weekday: true, date: true, seconds: false),
                time: ClockFormatOptions = ClockFormatOptions(weekday: false, date: false, seconds: false),
                frontApp: FrontAppFormatOptions = .default,
                locale: Locale = .current,
                timeZone: TimeZone = .current) {
        self.clock = clock
        self.date = date
        self.time = time
        self.frontApp = frontApp
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

    public init(symbolName: String?,
                iconBundleIdentifier: String? = nil,
                text: String,
                accessibilityLabel: String,
                isError: Bool = false,
                indicator: WidgetIndicator? = nil) {
        self.symbolName = symbolName
        self.iconBundleIdentifier = iconBundleIdentifier
        self.text = text
        self.accessibilityLabel = accessibilityLabel
        self.isError = isError
        self.indicator = indicator
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
            return batteryPresentation(snapshot)
        case .network(let snapshot):
            return networkPresentation(snapshot)
        case .volume(let snapshot):
            return volumePresentation(snapshot)
        case .clock(let snapshot):
            let text = ClockText.string(for: snapshot, options: options.clock,
                                        locale: options.locale, timeZone: options.timeZone)
            return WidgetPresentation(symbolName: nil, text: text, accessibilityLabel: text)
        case .date(let snapshot):
            let text = ClockText.string(for: snapshot, options: options.date,
                                        locale: options.locale, timeZone: options.timeZone)
            return WidgetPresentation(symbolName: nil, text: text, accessibilityLabel: text)
        case .time(let snapshot):
            let text = ClockText.string(for: snapshot, options: options.time,
                                        locale: options.locale, timeZone: options.timeZone)
            return WidgetPresentation(symbolName: nil, text: text, accessibilityLabel: text)
        case .unavailable(let unavailable):
            return unavailablePresentation(unavailable)
        }
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

    private static func batteryPresentation(_ snapshot: BatterySnapshot) -> WidgetPresentation {
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
            let symbol = batterySymbol(percentage: snapshot.percentage, charging: snapshot.isCharging)
            let text = snapshot.percentage.map { "\($0)%" } ?? ""
            var description = "Battery \(text.isEmpty ? "state unknown" : text)"
            if snapshot.isCharging { description += ", charging" }
            else if snapshot.isPluggedIn { description += ", plugged in" }
            else if snapshot.isFullyCharged { description += ", charged" }
            if snapshot.isKeepingAwake { description += ", keep awake on" }
            return WidgetPresentation(symbolName: symbol,
                                      text: text,
                                      accessibilityLabel: description,
                                      indicator: indicator)
        }
    }

    private static func batterySymbol(percentage: Int?, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch percentage ?? 0 {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private static func networkPresentation(_ snapshot: NetworkSnapshot) -> WidgetPresentation {
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
        return WidgetPresentation(symbolName: symbol, text: "", accessibilityLabel: description)
    }

    private static func volumePresentation(_ snapshot: VolumeSnapshot) -> WidgetPresentation {
        guard snapshot.hasOutputDevice else {
            return WidgetPresentation(symbolName: "speaker.slash.fill",
                                      text: "",
                                      accessibilityLabel: "No audio output device",
                                      isError: true)
        }
        if snapshot.isMuted {
            return WidgetPresentation(symbolName: "speaker.slash.fill",
                                      text: "Muted",
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
        return WidgetPresentation(symbolName: symbol,
                                  text: "\(percent)%",
                                  accessibilityLabel: "Volume \(percent) percent")
    }
}
