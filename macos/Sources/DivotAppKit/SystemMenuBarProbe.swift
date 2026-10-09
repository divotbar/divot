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
    /// Trusted, but no usable menu-bar element/attributes were returned.
    case unavailable(String)
    /// Trusted and sampled. `visible` is derived from position/size/hidden.
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

/// Accessibility (`AXUIElementCreateSystemWide`) implementation.
///
/// This is the public-API probe behind product decision (a) in the feasibility
/// report. It is gated on Accessibility permission and never fabricates a
/// signal when untrusted. Turning an off-screen/`hidden` heuristic into "the
/// bar is actually visible" is a claim that still needs physical validation.
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

        var position = CGPoint.zero
        var size = CGSize.zero
        if let raw = value(kAXPositionAttribute as CFString) {
            AXValueGetValue(raw as! AXValue, .cgPoint, &position)
        }
        if let raw = value(kAXSizeAttribute as CFString) {
            AXValueGetValue(raw as! AXValue, .cgSize, &size)
        }
        var hidden = false
        if let raw = value(kAXHiddenAttribute as CFString), CFGetTypeID(raw) == CFBooleanGetTypeID() {
            hidden = CFBooleanGetValue((raw as! CFBoolean))
        }

        // Conservative heuristic: only a non-hidden element with a real size
        // counts as visible. It is deliberately not wired in as trusted input
        // until it is validated against a real reveal/hide on hardware.
        let visible = !hidden && size.width > 0 && size.height > 0
        return .sampled(visible: visible,
                        description: "position=\(position) size=\(size) hidden=\(hidden)")
    }
}
