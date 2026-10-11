import Foundation
import CoreGraphics

// MARK: - Display identity and readings

/// Stable identity for a display across geometry readings.
///
/// The platform adapter derives this from system display identity (the
/// `NSScreenNumber` device description), never a transient array index, so a
/// display keeps its placement when other displays are attached or removed.
public struct DisplayBarID: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static func < (lhs: DisplayBarID, rhs: DisplayBarID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { "display-\(rawValue)" }
}

/// One display exactly as the platform reports it, before any signal is attached.
public struct ScreenGeometryReading: Equatable, Sendable {
    public let id: DisplayBarID
    public let geometry: ScreenGeometry

    public init(id: DisplayBarID, geometry: ScreenGeometry) {
        self.id = id
        self.geometry = geometry
    }
}

/// A display reading plus the optional native-bar signals available for it.
public struct DisplayReading: Equatable, Sendable {
    public let id: DisplayBarID
    public let geometry: ScreenGeometry
    public let signal: NativeMenuBarSignal

    public init(id: DisplayBarID, geometry: ScreenGeometry, signal: NativeMenuBarSignal = .init()) {
        self.id = id
        self.geometry = geometry
        self.signal = signal
    }
}

// MARK: - Content policy

/// Which resting position a display's bar currently uses.
public enum BarPlacementMode: Equatable, Sendable {
    /// Native bar hidden: Divot hugs the top edge and splits around the notch.
    case topEdge
    /// Native bar revealed: Divot sits below it, `inset` points down.
    case belowNativeBar(inset: CGFloat)
}

/// Resolved geometry for one display, plus the mode that produced it.
public struct BarPlacement: Equatable, Sendable {
    public let mode: BarPlacementMode
    public let geometry: BarGeometry

    public init(mode: BarPlacementMode, geometry: BarGeometry) {
        self.mode = mode
        self.geometry = geometry
    }
}

/// The explicit gap policy for the bar row.
///
/// This is the reviewable answer to "does moving below the bar carry the notch
/// gap along?" — it does not, and the two knobs that *do* apply in that row
/// (`clearance` as the center seam, `edgeMargin` as the window-manager gap) are
/// stated here rather than implied by whichever code path runs last.
public struct BarContentPolicy: Equatable, Sendable {
    /// Row height in points.
    public var height: CGFloat
    /// Centre-seam clearance for the non-notched rows; the below-bar row's seam
    /// is twice this value. The notched top-edge split ignores it entirely, so
    /// the bar always hugs the camera housing with a fixed zero gap (#0028).
    public var clearance: CGFloat
    /// Distance from the physical screen's left/right edges in below-bar mode.
    /// The default of zero keeps the row edge-to-edge (it overlays app content;
    /// reserving window-manager space is an adapter policy, not AppKit).
    public var edgeMargin: CGFloat

    public init(height: CGFloat = BarMetrics.default.height, clearance: CGFloat = 0,
                edgeMargin: CGFloat = 0) {
        self.height = height
        self.clearance = clearance
        self.edgeMargin = edgeMargin
    }

    /// Build the two segment frames for one display at the given inset.
    public func geometry(screen: ScreenGeometry, nativeMenuBarInset: CGFloat) -> BarGeometry {
        BarGeometry(screen: screen.frame,
                    topLeft: screen.auxiliaryTopLeft,
                    topRight: screen.auxiliaryTopRight,
                    height: height,
                    gap: clearance,
                    nativeMenuBarInset: nativeMenuBarInset,
                    edgeMargin: nativeMenuBarInset > 0 ? edgeMargin : 0)
    }
}

/// Turns a decided visibility into concrete segment frames. Indeterminate
/// states resolve to `nil`: the caller holds its current placement rather than
/// guessing.
public enum BarPlacementResolver {
    public static func placement(screen: ScreenGeometry,
                                 visibility: NativeMenuBarVisibility,
                                 policy: BarContentPolicy = .init()) -> BarPlacement? {
        switch visibility {
        case .indeterminate:
            return nil
        case .hidden:
            return BarPlacement(mode: .topEdge,
                                geometry: policy.geometry(screen: screen, nativeMenuBarInset: 0))
        case .visible(let inset):
            return BarPlacement(mode: .belowNativeBar(inset: inset),
                                geometry: policy.geometry(screen: screen, nativeMenuBarInset: inset))
        }
    }
}

// MARK: - Coordinator updates

/// What the platform adapter should do to one display's panels after an update.
public struct DisplayBarUpdate: Equatable, Sendable {
    public let id: DisplayBarID
    /// Segment frames to apply, or `nil` to leave the panels where they are
    /// (a hold: settling, or an undecidable state).
    public let placement: BarPlacement?
    /// Whether a real reposition should animate. Always `false` for display-set
    /// or geometry changes so panels never draw an intermediate position.
    public let animated: Bool
    /// Cancel any in-flight transition before applying anything else.
    public let cancelAnimations: Bool
    /// The visibility this update reflects. `.indeterminate` carries the reason.
    public let visibility: NativeMenuBarVisibility

    public init(id: DisplayBarID, placement: BarPlacement?, animated: Bool,
                cancelAnimations: Bool, visibility: NativeMenuBarVisibility) {
        self.id = id
        self.placement = placement
        self.animated = animated
        self.cancelAnimations = cancelAnimations
        self.visibility = visibility
    }

    public var ambiguity: NativeMenuBarAmbiguity? {
        if case .indeterminate(let reason) = visibility { return reason }
        return nil
    }
}

// MARK: - Coordinator

/// Pure, per-display placement state machine.
///
/// It owns one `MenuBarInsetController` per display, so rapid reveal/hide cycles
/// on one screen never drag another screen with them, and it coordinates display
/// add/remove as a single batch. It never polls and never emits a hide: an
/// undecidable state holds and is surfaced.
public struct DisplayBarCoordinator: Sendable {
    public var menuBarPolicy: MenuBarInsetPolicy
    public var contentPolicy: BarContentPolicy
    private var controllers: [DisplayBarID: MenuBarInsetController] = [:]
    private var readings: [DisplayBarID: DisplayReading] = [:]

    public init(menuBarPolicy: MenuBarInsetPolicy = .init(),
                contentPolicy: BarContentPolicy = .init()) {
        self.menuBarPolicy = menuBarPolicy
        self.contentPolicy = contentPolicy
    }

    /// Displays currently tracked, in stable identity order.
    public var displayIDs: [DisplayBarID] {
        controllers.keys.sorted()
    }

    /// The most recent reading kept for a display, used to recreate its panels.
    public func reading(for id: DisplayBarID) -> DisplayReading? {
        readings[id]
    }

    /// True when pure geometry cannot decide the bar state (notched hardware).
    public static func isMasked(_ geometry: ScreenGeometry) -> Bool {
        NativeMenuBarDetector.detect(geometry: geometry).isIndeterminate
    }

    /// Propagate the Reduced Motion setting to every tracked display.
    ///
    /// Each display owns its own controller, so changing only `menuBarPolicy`
    /// would leave existing controllers settling after the delay. This updates
    /// them in place so the next observation commits immediately.
    public mutating func setReducedMotion(_ reducedMotion: Bool) {
        menuBarPolicy.reducedMotion = reducedMotion
        for id in Array(controllers.keys) {
            controllers[id]?.policy.reducedMotion = reducedMotion
        }
    }

    /// Drop all per-display state. Panels torn down on `stop()` are rebuilt on a
    /// later start; without this the retained readings would suppress the
    /// placement updates and leave recreated panels at their initial size.
    public mutating func reset() {
        controllers.removeAll()
        readings.removeAll()
    }

    public func isSettling(_ id: DisplayBarID) -> Bool {
        controllers[id]?.isSettling ?? false
    }

    /// True while any display has an observation waiting for its settle delay.
    public var isSettling: Bool {
        controllers.values.contains { $0.isSettling }
    }

    public var settleDelay: TimeInterval { menuBarPolicy.settleDelay }

    /// Reconcile the tracked display set and record a fresh observation for each
    /// display at `time`. Returns one update per display whose panels should
    /// change; callers apply them as a batch so a display change never draws an
    /// intermediate layout.
    @discardableResult
    public mutating func update(readings incoming: [DisplayReading],
                                at time: TimeInterval) -> [DisplayBarUpdate] {
        var byID: [DisplayBarID: DisplayReading] = [:]
        var order: [DisplayBarID] = []
        for reading in incoming where byID[reading.id] == nil {
            byID[reading.id] = reading
            order.append(reading.id)
        }

        // Displays that went away (hot-unplug) stop being tracked. Their
        // surfaces are closed by the adapter when it re-reads `displayIDs`.
        for id in controllers.keys where byID[id] == nil {
            controllers.removeValue(forKey: id)
            readings.removeValue(forKey: id)
        }

        var updates: [DisplayBarUpdate] = []
        for id in order {
            guard let reading = byID[id] else { continue }
            let previous = readings[id]
            readings[id] = reading
            let visibility = NativeMenuBarDetector.detect(geometry: reading.geometry, signal: reading.signal)

            guard var controller = controllers[id] else {
                // A brand-new display has no prior position. Rest at the top
                // edge while an indeterminate state is unresolved; never hide.
                let fresh = MenuBarInsetController(initial: visibility, policy: menuBarPolicy)
                controllers[id] = fresh
                updates.append(restingUpdate(for: reading, visibility: visibility))
                continue
            }

            let screenChanged = previous.map { $0.geometry != reading.geometry } ?? true
            let actions = controller.observe(visibility, at: time)
            controllers[id] = controller

            if screenChanged {
                // A geometry change can itself be the visibility signal: on a
                // notch-free display `visibleFrame` shrinks the moment the
                // native bar appears, so the new reading carries both. Apply
                // the freshly detected placement now — never the stale
                // committed one — so a reveal cannot leave the panels
                // overlapping the bar while the settle timer runs, and a hide
                // returns to the top edge immediately. The observation queued
                // above still commits via `advance`; when it matches what we
                // applied it is a no-op reposition.
                updates.append(restingUpdate(for: reading, visibility: visibility))
                continue
            }

            for action in actions {
                switch action {
                case .cancelAnimations:
                    updates.append(DisplayBarUpdate(id: id, placement: nil, animated: false,
                                                    cancelAnimations: true,
                                                    visibility: controller.committed))
                case .reposition(_, let animated):
                    let policy = effectivePolicy(for: reading.geometry, signal: reading.signal)
                    let placement = BarPlacementResolver.placement(screen: reading.geometry,
                                                                   visibility: controller.committed,
                                                                   policy: policy)
                    updates.append(DisplayBarUpdate(id: id, placement: placement, animated: animated,
                                                    cancelAnimations: false,
                                                    visibility: controller.committed))
                case .indeterminate(let reason):
                    updates.append(DisplayBarUpdate(id: id, placement: nil, animated: false,
                                                    cancelAnimations: false,
                                                    visibility: .indeterminate(reason)))
                }
            }
        }
        return updates
    }

    /// Commit any observation whose settle deadline has passed by `time`.
    @discardableResult
    public mutating func advance(at time: TimeInterval) -> [DisplayBarUpdate] {
        var updates: [DisplayBarUpdate] = []
        for id in displayIDs {
            guard var controller = controllers[id], controller.isSettling,
                  let reading = readings[id] else { continue }
            let actions = controller.advance(to: time)
            controllers[id] = controller
            for action in actions {
                switch action {
                case .cancelAnimations:
                    break
                case .reposition(_, let animated):
                    let policy = effectivePolicy(for: reading.geometry, signal: reading.signal)
                    let placement = BarPlacementResolver.placement(screen: reading.geometry,
                                                                   visibility: controller.committed,
                                                                   policy: policy)
                    updates.append(DisplayBarUpdate(id: id, placement: placement, animated: animated,
                                                    cancelAnimations: false,
                                                    visibility: controller.committed))
                case .indeterminate(let reason):
                    updates.append(DisplayBarUpdate(id: id, placement: nil, animated: false,
                                                    cancelAnimations: false,
                                                    visibility: .indeterminate(reason)))
                }
            }
        }
        return updates
    }

    /// Compute the effective policy for a display, applying the computed default
    /// height from the screen geometry when the configured height is the default.
    private func effectivePolicy(for geometry: ScreenGeometry, signal: NativeMenuBarSignal) -> BarContentPolicy {
        let configuredHeight = contentPolicy.height
        let defaultHeight = CGFloat(BarMetrics.default.height)
        if abs(configuredHeight - defaultHeight) < 0.1 {
            let computedHeight = geometry.defaultBarHeight(nominalMenuBarHeight: signal.nominalMenuBarHeight)
            return BarContentPolicy(height: computedHeight,
                                    clearance: contentPolicy.clearance,
                                    edgeMargin: contentPolicy.edgeMargin)
        }
        return contentPolicy
    }

    /// An immediate, non-animated placement. `visibility` is what the caller
    /// should surface; the resting frames use the top edge for an undecidable
    /// state so the panels are still visible and never hidden.
    private func restingUpdate(for reading: DisplayReading,
                               visibility: NativeMenuBarVisibility) -> DisplayBarUpdate {
        let resting: NativeMenuBarVisibility = visibility.isIndeterminate ? .hidden : visibility
        let policy = effectivePolicy(for: reading.geometry, signal: reading.signal)
        let placement = BarPlacementResolver.placement(screen: reading.geometry,
                                                       visibility: resting,
                                                       policy: policy)
        return DisplayBarUpdate(id: reading.id, placement: placement, animated: false,
                                cancelAnimations: true, visibility: visibility)
    }
}
