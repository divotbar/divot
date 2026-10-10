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

    /// Nominal height of the **platform's** native menu bar, used only when a
    /// notch-free display reports a top band smaller than a standard bar. This
    /// is deliberately independent of `BarMetrics.default.height` (Divot's own
    /// 32 pt row height): on a notch-free display the native bar is ~24 pt, and
    /// insetting by the row height there would leave a visible gap under the bar.
    public var nominalMenuBarHeight: CGFloat

    /// Whether a complete Accessibility sample may decide placement.
    ///
    /// Off by default: the on-screen position heuristic is hardware-sensitive,
    /// so a shipping build must not assert it globally. The configuration
    /// document opts in with `menuBar.trustAccessibilityProbe`. While off, the
    /// sample is withheld and a masked (notched) display stays indeterminate and
    /// holds the top edge rather than moving below an unconfirmed bar (#0021).
    public var trustsAccessibilityProbe: Bool

    /// Displays whose top strip the pointer is currently in, or `nil` when the
    /// "move below on cursor reveal" setting is off. Only a masked display
    /// consults it; a notch-free display's `visibleFrame` cross-checks and
    /// overrides it (#0023).
    public var cursorEngagedDisplays: Set<DisplayBarID>?

    /// Fallback placement from `menuBar.alwaysBelow`: sit below the native bar
    /// regardless of any observation.
    public var alwaysBelowMenuBar: Bool

    public init(provider: ScreenGeometryProviding,
                probe: SystemMenuBarProbing,
                nominalMenuBarHeight: CGFloat = 24,
                trustsAccessibilityProbe: Bool = false,
                cursorEngagedDisplays: Set<DisplayBarID>? = nil,
                alwaysBelowMenuBar: Bool = false) {
        self.provider = provider
        self.probe = probe
        self.nominalMenuBarHeight = nominalMenuBarHeight
        self.trustsAccessibilityProbe = trustsAccessibilityProbe
        self.cursorEngagedDisplays = cursorEngagedDisplays
        self.alwaysBelowMenuBar = alwaysBelowMenuBar
    }

    public func observe() -> MenuBarObservation {
        let screens = provider.screens()
        let accessibility = probe.sample()
        // A sample the probe itself marked `validated` is decisive on its own;
        // the raw derived visibility additionally needs the explicit opt-in,
        // because the on-screen heuristic is hardware-sensitive.
        let sample: Bool? = trustsAccessibilityProbe
            ? accessibility.rawDerivedVisible
            : accessibility.accessibilityVisible

        // The AX menu bar is one system-wide object; public APIs do not
        // attribute it to a display, and it reflects whichever display is
        // active. Only hand it to a display whose own geometry cannot decide,
        // and only when there is exactly one display, so it can neither
        // override a display's `visibleFrame` nor be misattributed across
        // displays. Multiple masked displays stay indeterminate.
        let maskedIDs = screens.filter { DisplayBarCoordinator.isMasked($0.geometry) }.map(\.id)
        let attributedID: DisplayBarID? = (screens.count == 1 && sample != nil) ? maskedIDs.first : nil

        let readings = screens.map { screen in
            let cursor = cursorEngagedDisplays.map { $0.contains(screen.id) }
            let signal = NativeMenuBarSignal(accessibilityVisible: screen.id == attributedID ? sample : nil,
                                             configuredAlwaysVisible: nil,
                                             cursorRevealsMenuBar: cursor,
                                             alwaysBelowMenuBar: alwaysBelowMenuBar,
                                             nominalMenuBarHeight: nominalMenuBarHeight)
            return DisplayReading(id: screen.id, geometry: screen.geometry, signal: signal)
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
