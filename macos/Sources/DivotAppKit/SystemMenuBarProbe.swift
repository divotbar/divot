import AppKit
import ApplicationServices

/// What the Accessibility system-wide menu-bar probe could report.
///
/// The `description` carries the raw sample for diagnostics; the associated
/// Bool is a *derived* on-screen heuristic that must be validated on physical
/// hardware before it can be trusted (see
/// `docs/evidence/0009-native-menu-bar-coexistence.md`).
public enum SystemMenuBarState: Equatable, Sendable {
    /// Accessibility is not granted for this process. The probe has no signal.
    case notTrusted
    /// Trusted, but the sample is missing, malformed, or has no measurable
    /// geometry. Undecidable — never coerced into a visible/hidden claim.
    case unavailable(String)
    /// Trusted and fully sampled. `visible` is derived from position/size/hidden.
    case sampled(visible: Bool, description: String)

    /// The visibility the detector may use, or `nil` when undecidable.
    public var accessibilityVisible: Bool? {
        if case .sampled(let visible, _) = self { return visible }
        return nil
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
/// zero-sized point or an assumed `hidden == false`.
public enum SystemMenuBarProbe {
    public static func state(position: CGPoint?,
                             size: CGSize?,
                             hidden: Bool?) -> SystemMenuBarState {
        guard let position, let size, let hidden else {
            return .unavailable("incomplete AX menu-bar attributes (position/size/hidden)")
        }
        guard size.width > 0, size.height > 0 else {
            return .unavailable("AX menu-bar element has no measurable area")
        }
        return .sampled(visible: !hidden,
                        description: "position=\(position) size=\(size) hidden=\(hidden)")
    }
}

/// Accessibility (`AXUIElementCreateSystemWide`) implementation.
///
/// This is the public-API probe behind product decision (a) in the feasibility
/// report. It is gated on Accessibility permission and never fabricates a
/// signal when untrusted or when an attribute is missing. Turning its
/// off-screen/`hidden` heuristic into "the bar is actually visible" is a claim
/// that still needs physical validation.
public struct AXSystemMenuBarProbe: SystemMenuBarProbing {
    public init() {}

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

        return SystemMenuBarProbe.state(position: position, size: size, hidden: hidden)
    }
}
