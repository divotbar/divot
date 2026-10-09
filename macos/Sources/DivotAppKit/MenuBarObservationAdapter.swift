import AppKit
import DivotCore

/// One observation pass over the live platform.
public struct MenuBarObservation: Equatable, Sendable {
    /// Per-display readings, already carrying the signals available for them.
    public let readings: [DisplayReading]
    /// The raw Accessibility result, surfaced rather than swallowed so callers
    /// can report a missing permission and remaining physical validation.
    public let accessibility: SystemMenuBarState

    public init(readings: [DisplayReading], accessibility: SystemMenuBarState) {
        self.readings = readings
        self.accessibility = accessibility
    }

    public var accessibilityPermissionGranted: Bool { accessibility.permissionGranted }
}

/// Reusable, public-API observation adapter shared by the app and the probe.
///
/// It joins two separately owned pieces — screen geometry and the optional
/// Accessibility menu-bar probe — into `DisplayReading`s for the pure
/// coordinator. It never polls: callers drive it from OS notifications.
@MainActor
public final class MenuBarObservationAdapter {
    private let provider: ScreenGeometryProviding
    private let probe: SystemMenuBarProbing

    /// Minimum inset assumed for a visible notch-free native bar, used only
    /// when the reported top band is smaller than a standard bar.
    public var nominalMenuBarHeight: CGFloat

    public init(provider: ScreenGeometryProviding,
                probe: SystemMenuBarProbing,
                nominalMenuBarHeight: CGFloat = 24) {
        self.provider = provider
        self.probe = probe
        self.nominalMenuBarHeight = nominalMenuBarHeight
    }

    public func observe() -> MenuBarObservation {
        let screens = provider.screens()
        let accessibility = probe.sample()
        let sample = accessibility.accessibilityVisible

        // The AX menu bar is one system-wide object; public APIs do not
        // attribute it to a display, and it reflects whichever display is
        // active. Only hand it to a display whose own geometry cannot decide,
        // and only when there is exactly one display, so it can neither
        // override a display's `visibleFrame` nor be misattributed across
        // displays. Multiple masked displays stay indeterminate.
        let maskedIDs = screens.filter { Self.isMasked($0.geometry) }.map(\.id)
        let attributedID: DisplayBarID? = (screens.count == 1 && sample != nil) ? maskedIDs.first : nil

        let readings = screens.map { screen in
            let signal = NativeMenuBarSignal(accessibilityVisible: screen.id == attributedID ? sample : nil,
                                             configuredAlwaysVisible: nil,
                                             nominalMenuBarHeight: nominalMenuBarHeight)
            return DisplayReading(id: screen.id, geometry: screen.geometry, signal: signal)
        }
        return MenuBarObservation(readings: readings, accessibility: accessibility)
    }

    /// True when pure geometry cannot decide the bar state (notched hardware).
    private static func isMasked(_ geometry: ScreenGeometry) -> Bool {
        NativeMenuBarDetector.detect(geometry: geometry).isIndeterminate
    }
}

/// The event-driven triggers the coordinator re-evaluates on. None of these is
/// a first-class "the native bar is visible" signal (see the evidence report);
/// they decide *when* to re-read, not *what* the answer is.
public enum MenuBarEventNotifications {
    public static let all: [NSNotification.Name] = [
        NSApplication.didChangeScreenParametersNotification,
        NSApplication.didChangeOcclusionStateNotification,
        NSApplication.didBecomeActiveNotification,
        NSApplication.didResignActiveNotification,
        NSWorkspace.activeSpaceDidChangeNotification,
        NSWorkspace.didActivateApplicationNotification,
        NSMenu.didBeginTrackingNotification,
        NSMenu.didEndTrackingNotification,
        NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
    ]
}
