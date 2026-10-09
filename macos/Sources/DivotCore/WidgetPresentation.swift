import Foundation

/// Options the presenter needs beyond the snapshot itself.
public struct WidgetPresentationOptions: Equatable, Sendable {
    public var clock: ClockFormatOptions
    public var locale: Locale
    public var timeZone: TimeZone

    public init(clock: ClockFormatOptions = .default,
                locale: Locale = .current,
                timeZone: TimeZone = .current) {
        self.clock = clock
        self.locale = locale
        self.timeZone = timeZone
    }

    public static let `default` = WidgetPresentationOptions()
}

/// How one item should look: an optional SF Symbol, compact text, and the
/// accessible description. Kept pure so it is testable without a window server
/// and so every widget shares one presentation path.
public struct WidgetPresentation: Equatable, Sendable {
    /// SF Symbol name, when the item shows an icon. A view that cannot resolve
    /// the symbol falls back to text rather than drawing nothing.
    public let symbolName: String?
    public let text: String
    public let accessibilityLabel: String
    /// Render with the error role (color plus a distinct glyph, never color only).
    public let isError: Bool

    public init(symbolName: String?, text: String, accessibilityLabel: String, isError: Bool = false) {
        self.symbolName = symbolName
        self.text = text
        self.accessibilityLabel = accessibilityLabel
        self.isError = isError
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
            return WidgetPresentation(symbolName: nil,
                                      text: snapshot.name,
                                      accessibilityLabel: "Frontmost application: \(snapshot.name)")
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
        case .unavailable(let unavailable):
            return unavailablePresentation(unavailable)
        }
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
        switch snapshot.presence {
        case .none:
            return WidgetPresentation(symbolName: "powerplug.fill",
                                      text: "",
                                      accessibilityLabel: "No battery (desktop Mac)")
        case .internalBattery:
            let symbol = batterySymbol(percentage: snapshot.percentage, charging: snapshot.isCharging)
            let text = snapshot.percentage.map { "\($0)%" } ?? ""
            var description = "Battery \(text.isEmpty ? "state unknown" : text)"
            if snapshot.isCharging { description += ", charging" }
            else if snapshot.isPluggedIn { description += ", plugged in" }
            else if snapshot.isFullyCharged { description += ", charged" }
            return WidgetPresentation(symbolName: symbol, text: text, accessibilityLabel: description)
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
