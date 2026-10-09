import Foundation
import CoreGraphics

/// A pure snapshot of one display's platform geometry.
///
/// The AppKit adapter fills this from `NSScreen`; keeping it a value type makes
/// the detection and placement rules testable without a window server.
public struct ScreenGeometry: Equatable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let safeAreaTop: CGFloat
    public let auxiliaryTopLeft: CGRect?
    public let auxiliaryTopRight: CGRect?
    public let backingScaleFactor: CGFloat

    public init(frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat,
                auxiliaryTopLeft: CGRect? = nil, auxiliaryTopRight: CGRect? = nil,
                backingScaleFactor: CGFloat = 2) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeft = auxiliaryTopLeft
        self.auxiliaryTopRight = auxiliaryTopRight
        self.backingScaleFactor = backingScaleFactor
    }

    /// Camera-housing band at the top of the display. On notched Macs this is
    /// the notch height and is a physical property, not a menu-bar signal.
    public var housingTop: CGFloat {
        let value = safeAreaTop.isFinite ? safeAreaTop : 0
        return max(0, min(value, max(0, frame.height)))
    }

    /// The whole top band excluded from `visibleFrame`: camera housing plus a
    /// visible native menu bar, whichever is larger.
    public var topBand: CGFloat {
        let value = frame.maxY - visibleFrame.maxY
        return max(0, min(value.isFinite ? value : 0, max(0, frame.height)))
    }

    /// The menu-bar-only part of the top band.
    ///
    /// On a notched display the housing already excludes the entire top band,
    /// even while the native bar is hidden, so this reads zero and cannot
    /// distinguish a hidden bar from a revealed one. That is the central
    /// finding of task 0009, not a bug in the arithmetic.
    public var menuBarInset: CGFloat {
        max(0, topBand - housingTop)
    }

    /// True when `safeAreaInsets.top` reports a camera housing.
    public var isNotched: Bool {
        housingTop > 0.5
    }
}

/// What public APIs can currently say about the native menu bar.
public enum NativeMenuBarVisibility: Equatable, Sendable, CustomStringConvertible {
    /// The native bar occupies `inset` points at the top of this display. Divot
    /// must sit below that band.
    case visible(inset: CGFloat)
    /// The native bar is not occupying the top band; Divot may use the top edge.
    case hidden
    /// Public signals cannot decide. The caller must keep its current placement
    /// and surface the reason instead of guessing or hiding.
    case indeterminate(NativeMenuBarAmbiguity)

    /// Top inset Divot should clear, or `nil` when undecided.
    public var inset: CGFloat? {
        switch self {
        case .visible(let inset): return inset
        case .hidden: return 0
        case .indeterminate: return nil
        }
    }

    public var isIndeterminate: Bool {
        if case .indeterminate = self { return true }
        return false
    }

    public var description: String {
        switch self {
        case .visible(let inset): return "visible(inset: \(inset))"
        case .hidden: return "hidden"
        case .indeterminate(let reason): return "indeterminate(\(reason.rawValue))"
        }
    }
}

/// Why visibility could not be decided with public APIs alone.
public enum NativeMenuBarAmbiguity: String, Equatable, Sendable {
    /// Notched hardware: `safeAreaInsets.top` masks the menu-bar band.
    case notchedHousingMasksMenuBar
    /// Resolving this case needs Accessibility permission for the AX probe.
    case accessibilityPermissionRequired
}

/// Extra public-API readings the detector may use. All optional so the pure
/// geometry path works with no platform calls at all.
public struct NativeMenuBarSignal: Equatable, Sendable {
    /// Result of the Accessibility system-wide menu-bar probe, when trusted.
    public var accessibilityVisible: Bool?
    /// Whether the user configured the bar to always show. Undocumented
    /// defaults are deliberately not wired in here.
    public var configuredAlwaysVisible: Bool?
    /// Nominal macOS menu-bar height used when geometry is clamped away.
    public var nominalMenuBarHeight: CGFloat

    public init(accessibilityVisible: Bool? = nil, configuredAlwaysVisible: Bool? = nil,
                nominalMenuBarHeight: CGFloat = 24) {
        self.accessibilityVisible = accessibilityVisible
        self.configuredAlwaysVisible = configuredAlwaysVisible
        self.nominalMenuBarHeight = nominalMenuBarHeight
    }
}

/// Resolves the menu-bar state from a pure geometry snapshot plus optional
/// signals. Never polls, never hides: undecidable inputs return
/// `.indeterminate` so the caller can keep its position and report.
public enum NativeMenuBarDetector {
    public static func detect(geometry: ScreenGeometry,
                              signal: NativeMenuBarSignal = .init()) -> NativeMenuBarVisibility {
        if let visible = signal.accessibilityVisible {
            return visible ? .visible(inset: visibleInset(geometry, signal)) : .hidden
        }
        if signal.configuredAlwaysVisible == true {
            return .visible(inset: visibleInset(geometry, signal))
        }
        if geometry.isNotched {
            return .indeterminate(.notchedHousingMasksMenuBar)
        }
        return geometry.menuBarInset > 0.5
            ? .visible(inset: geometry.menuBarInset)
            : .hidden
    }

    /// The inset Divot must clear to avoid the bar and the housing.
    private static func visibleInset(_ geometry: ScreenGeometry,
                                     _ signal: NativeMenuBarSignal) -> CGFloat {
        if geometry.isNotched {
            // On notched hardware the bar renders inside the housing band.
            return max(geometry.housingTop, geometry.topBand)
        }
        let nominal = signal.nominalMenuBarHeight.isFinite ? signal.nominalMenuBarHeight : 24
        return max(geometry.topBand, max(0, nominal))
    }
}

/// Coalescing policy for repositioning.
public struct MenuBarInsetPolicy: Equatable, Sendable {
    /// Time a new state must hold before it is committed. Bounds how long rapid
    /// reveal/hide cycles can oscillate without a settle timer of their own.
    public var settleDelay: TimeInterval
    /// Reduced Motion commits immediately with no animation.
    public var reducedMotion: Bool

    public init(settleDelay: TimeInterval = 0.15, reducedMotion: Bool = false) {
        self.settleDelay = max(0, settleDelay)
        self.reducedMotion = reducedMotion
    }
}

/// What the geometry/panel owner should do after an observation.
public enum MenuBarInsetAction: Equatable, Sendable {
    /// Move the panels so their top edge is `inset` points below the screen top.
    case reposition(inset: CGFloat, animated: Bool)
    /// Cancel any in-flight transition before the next reposition.
    case cancelAnimations
    /// No decision possible; keep the current placement and report the reason.
    case indeterminate(NativeMenuBarAmbiguity)
}

/// Event-driven controller. Feed it observations from OS notifications; it
/// never polls and never emits a hide. Rapid toggles converge on the last
/// observation once the settle delay passes, and undecidable states are
/// surfaced rather than swallowed.
public struct MenuBarInsetController: Equatable, Sendable {
    public private(set) var committed: NativeMenuBarVisibility
    public var policy: MenuBarInsetPolicy
    private var pending: NativeMenuBarVisibility?
    private var deadline: TimeInterval?

    public init(initial: NativeMenuBarVisibility = .hidden,
                policy: MenuBarInsetPolicy = .init()) {
        self.committed = initial
        self.policy = policy
    }

    /// True while an observation is waiting for the settle delay.
    public var isSettling: Bool { pending != nil }

    /// Record a new observation at `time`. Cancels any animation immediately so
    /// a superseded transition never draws. Returns actions to apply now.
    @discardableResult
    public mutating func observe(_ visibility: NativeMenuBarVisibility,
                                 at time: TimeInterval) -> [MenuBarInsetAction] {
        if visibility == committed, pending == nil {
            return []
        }
        if policy.reducedMotion {
            pending = nil
            deadline = nil
            committed = visibility
            return actions(for: visibility, animated: false)
        }
        pending = visibility
        deadline = time + policy.settleDelay
        // Cancel whatever is mid-flight; the settled reposition will follow.
        return [.cancelAnimations]
    }

    /// Commit a settled observation once its deadline has passed. Call this from
    /// the scheduled settle timer; it is a no-op before the deadline.
    @discardableResult
    public mutating func advance(to time: TimeInterval) -> [MenuBarInsetAction] {
        guard let deadline, let pending, time >= deadline else { return [] }
        self.pending = nil
        self.deadline = nil
        self.committed = pending
        return actions(for: pending, animated: true)
    }

    private func actions(for visibility: NativeMenuBarVisibility,
                         animated: Bool) -> [MenuBarInsetAction] {
        switch visibility {
        case .visible(let inset):
            return [.reposition(inset: inset, animated: animated)]
        case .hidden:
            return [.reposition(inset: 0, animated: animated)]
        case .indeterminate(let reason):
            // Deliberately not a hide and not a reposition: hold position.
            return [.indeterminate(reason)]
        }
    }
}
