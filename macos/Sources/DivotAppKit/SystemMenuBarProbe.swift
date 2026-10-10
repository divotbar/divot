import AppKit
import ApplicationServices

/// What the Accessibility system-wide menu-bar probe could report.
///
/// A complete AX sample is always *provisional* until the position/size/`hidden`
/// heuristic is confirmed on physical hardware (see
/// `docs/evidence/0009-native-menu-bar-coexistence.md`). A provisional sample
/// carries no decisive visibility, so it can never move a panel on an
/// unvalidated claim; only a sample explicitly marked `validated` is decisive.
public enum SystemMenuBarState: Equatable, Sendable {
    /// Accessibility is not granted for this process. The probe has no signal.
    case notTrusted
    /// Trusted, but the sample is missing, malformed, or has no measurable
    /// geometry. Undecidable — never coerced into a visible/hidden claim.
    case unavailable(String)
    /// Trusted and fully sampled, but the derived visibility is explicitly
    /// provisional: diagnostics only, never used to decide placement.
    case provisional(visible: Bool, description: String)
    /// Trusted, fully sampled, and validated on physical hardware. Only this
    /// state provides a visibility the detector may act on.
    case sampled(visible: Bool, description: String)

    /// The visibility the detector may use, or `nil` when undecidable or only
    /// provisional. Acting on a provisional sample first requires recorded
    /// physical validation.
    public var accessibilityVisible: Bool? {
        if case .sampled(let visible, _) = self { return visible }
        return nil
    }

    /// The raw derived heuristic even when provisional, for honest reporting.
    public var rawDerivedVisible: Bool? {
        switch self {
        case .sampled(let visible, _), .provisional(let visible, _): return visible
        case .notTrusted, .unavailable: return nil
        }
    }

    /// True when a complete sample exists but its heuristic is unvalidated.
    public var isProvisional: Bool {
        if case .provisional = self { return true }
        return false
    }

    /// The raw sample text, for diagnostics. Never a placement decision by itself.
    public var sampleDescription: String {
        switch self {
        case .notTrusted: return "not trusted"
        case .unavailable(let reason): return reason
        case .provisional(_, let description), .sampled(_, let description): return description
        }
    }

    public var permissionGranted: Bool {
        if case .notTrusted = self { return false }
        return true
    }
}

/// Public-API probe of the system menu bar. Injectable so the adapter is
/// testable and so the app can degrade honestly when permission is missing.
public protocol SystemMenuBarProbing: Sendable {
    func sample() -> SystemMenuBarState
}

/// Pure decision for the Accessibility menu-bar heuristic.
///
/// Every input is optional and represents an attribute that may be missing or
/// malformed. If any required attribute is absent, or the element has no
/// measurable area, the result is `.unavailable` (indeterminate) rather than a
/// zero-sized point or an assumed `hidden == false`. A complete sample is
/// returned as `.provisional` unless `validated` is set, so the off-screen
/// heuristic cannot silently drive placement before physical validation.
///
/// The signal that used to report "visible" while the bar is auto-hidden is
/// `kAXHiddenAttribute`: it stays `false` because an auto-hidden bar is not
/// AX-hidden — it is slid above the top of the screen. `!hidden` therefore
/// claimed visible for a hidden bar. The distinguishing signal is the menu
/// bar's own frame: in the AX global (top-left origin) space a revealed bar
/// sits at `y == 0`, while an auto-hidden bar sits entirely above the screen
/// at a negative `y`. Visibility is `!hidden` *and* on-screen.
public enum SystemMenuBarProbe {
    public static func state(position: CGPoint?,
                             size: CGSize?,
                             hidden: Bool?,
                             validated: Bool = false) -> SystemMenuBarState {
        guard let position, let size, let hidden else {
            return .unavailable("incomplete AX menu-bar attributes (position/size/hidden)")
        }
        guard size.width > 0, size.height > 0 else {
            return .unavailable("AX menu-bar element has no measurable area")
        }
        guard position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite else {
            return .unavailable("non-finite AX menu-bar geometry")
        }
        // Top-left-origin AX space: the bar's top edge is at y == 0 when it is
        // revealed and negative when it has slid off the top. A half-point of
        // slack keeps the boundary from flickering on rounding. The adapter
        // only hands this sample to a single display, so the global origin is
        // that display's top-left.
        let onScreen = position.y >= -0.5
        let visible = !hidden && onScreen
        let description = "position=\(position) size=\(size) hidden=\(hidden) onScreen=\(onScreen)"
        return validated
            ? .sampled(visible: visible, description: description)
            : .provisional(visible: visible, description: description)
    }
}

/// Accessibility (`AXUIElementCreateSystemWide`) implementation.
///
/// This is the public-API probe behind product decision (a) in the feasibility
/// report. It is gated on Accessibility permission and never fabricates a
/// signal when untrusted or when an attribute is missing. The off-screen test
/// (`position.y >= 0`) is what turns the raw `hidden` attribute into an actual
/// visibility: `hidden` reads `false` for an auto-hidden bar, so `!hidden`
/// alone claims visible; the bar's frame is above the screen in that case.
public struct AXSystemMenuBarProbe: SystemMenuBarProbing {
    /// Set when the on-screen position/size/`hidden` heuristic is the trusted
    /// signal for this build. `DivotApp` and the report/probe tools pass `true`
    /// for the maintainer's auto-hidden notched display (#0021); the default
    /// stays provisional so an unvalidated sample can never move a panel.
    public let validated: Bool

    public init(validated: Bool = false) {
        self.validated = validated
    }

    public func sample() -> SystemMenuBarState {
        guard AXIsProcessTrusted() else { return .notTrusted }

        let system = AXUIElementCreateSystemWide()
        var barRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(system, kAXMenuBarAttribute as CFString, &barRef)
        guard error == .success, let barRef else {
            return .unavailable("no menu-bar element (AXError \(error.rawValue))")
        }
        let bar = barRef as! AXUIElement

        func value(_ attribute: CFString) -> CFTypeRef? {
            var result: CFTypeRef?
            return AXUIElementCopyAttributeValue(bar, attribute, &result) == .success ? result : nil
        }

        // Extract each attribute defensively. A missing attribute, a wrong
        // type, or a failed value decode becomes `nil` (undecidable), never a
        // default zero/`false`.
        var position: CGPoint?
        if let raw = value(kAXPositionAttribute as CFString), CFGetTypeID(raw) == AXValueGetTypeID() {
            var decoded = CGPoint.zero
            if AXValueGetValue(raw as! AXValue, .cgPoint, &decoded) { position = decoded }
        }

        var size: CGSize?
        if let raw = value(kAXSizeAttribute as CFString), CFGetTypeID(raw) == AXValueGetTypeID() {
            var decoded = CGSize.zero
            if AXValueGetValue(raw as! AXValue, .cgSize, &decoded) { size = decoded }
        }

        var hidden: Bool?
        if let raw = value(kAXHiddenAttribute as CFString), CFGetTypeID(raw) == CFBooleanGetTypeID() {
            hidden = CFBooleanGetValue((raw as! CFBoolean))
        }

        return SystemMenuBarProbe.state(position: position, size: size, hidden: hidden,
                                        validated: validated)
    }
}
