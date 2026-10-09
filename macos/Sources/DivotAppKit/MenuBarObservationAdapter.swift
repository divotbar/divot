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

    /// Nominal macOS menu-bar height used when geometry is clamped away. Only
    /// consulted for notch-free displays whose top band reads zero.
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
        let signal = NativeMenuBarSignal(accessibilityVisible: accessibility.accessibilityVisible,
                                         configuredAlwaysVisible: nil,
                                         nominalMenuBarHeight: nominalMenuBarHeight)
        let readings = screens.map {
            DisplayReading(id: $0.id, geometry: $0.geometry, signal: signal)
        }
        return MenuBarObservation(readings: readings, accessibility: accessibility)
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
