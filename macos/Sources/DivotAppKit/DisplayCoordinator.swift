import AppKit
import DivotCore

/// The AppKit half of the display coordinator.
///
/// It reads observations through the reusable adapter, feeds the pure
/// `DisplayBarCoordinator`, and applies the resulting placement to one
/// `BarDisplaySurface` per display. It is event-driven (the shared notification
/// set plus one settle timer) and never polls.
@MainActor
public final class DisplayCoordinator {
    public typealias SurfaceFactory = (DisplayBarID, CGRect) -> BarDisplaySurface

    private let adapter: MenuBarObservationAdapter
    private var core: DisplayBarCoordinator
    private let makeSurface: SurfaceFactory

    private var surfaces: [DisplayBarID: BarDisplaySurface] = [:]
    private var tokens: [NSObjectProtocol] = []
    private var settleTimer: Timer?
    /// Latest widget state per item, replayed to a panel created after the batch
    /// that produced it (hot-plug, or a restart that rebuilds panels).
    private var widgetStates: [BarItemID: WidgetState] = [:]

    /// The most recent observation, for diagnostics and permission reporting.
    public private(set) var lastObservation: MenuBarObservation?
    /// True when the last observation had Accessibility permission.
    public var accessibilityPermissionGranted: Bool {
        lastObservation?.accessibilityPermissionGranted ?? false
    }
    public var isRunning: Bool { !tokens.isEmpty }

    public init(adapter: MenuBarObservationAdapter,
                menuBarPolicy: MenuBarInsetPolicy = .init(),
                contentPolicy: BarContentPolicy = .init(),
                surfaceFactory: @escaping SurfaceFactory) {
        self.adapter = adapter
        self.core = DisplayBarCoordinator(menuBarPolicy: menuBarPolicy, contentPolicy: contentPolicy)
        self.makeSurface = surfaceFactory
    }

    /// Begin observing. Idempotent.
    public func start() {
        guard tokens.isEmpty else { return }
        // A previous `stop()` closed the panels but retained the core's
        // readings. Clear them so this start re-emits a placement for every
        // display instead of leaving recreated panels at their initial size.
        core.reset()
        for name in MenuBarEventNotifications.all {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            tokens.append(token)
        }
        refresh()
    }

    public func stop() {
        settleTimer?.invalidate()
        settleTimer = nil
        for token in tokens { NotificationCenter.default.removeObserver(token) }
        tokens.removeAll()
        for surface in surfaces.values { surface.close() }
        surfaces.removeAll()
    }

    /// Re-read the platform and apply any resulting placement as one batch.
    public func refresh() {
        let observation = adapter.observe()
        lastObservation = observation
        // Propagate Reduced Motion to every existing per-display controller, not
        // just the coordinator default, so the next change repositions now.
        core.setReducedMotion(reduceMotion)
        let updates = core.update(readings: observation.readings, at: ProcessInfo.processInfo.systemUptime)
        reconcileSurfaces()
        apply(updates)
        scheduleSettle()
    }

    /// Apply a batch of widget changes to every display. This comes from the
    /// provider pipeline's main-actor sink. A removal clears the item so a
    /// still-visible widget cannot show a value that is no longer kept current.
    public func applyWidgetChanges(_ changes: [WidgetChange]) {
        guard !changes.isEmpty else { return }
        for change in changes {
            switch change {
            case .update(let state): widgetStates[state.id] = state
            case .removed(let id): widgetStates.removeValue(forKey: id)
            }
        }
        for surface in surfaces.values { surface.apply(widgetChanges: changes) }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Add surfaces for new displays and close surfaces for departed ones, so a
    /// hot-plug never leaves an orphan panel or draws an intermediate layout.
    private func reconcileSurfaces() {
        let live = Set(core.displayIDs)
        for id in surfaces.keys where !live.contains(id) {
            surfaces.removeValue(forKey: id)?.close()
        }
        for id in live where surfaces[id] == nil {
            guard let reading = core.reading(for: id) else { continue }
            let surface = makeSurface(id, reading.geometry.frame)
            // Replay the latest widget state so a panel created after the batch
            // that produced it is not stuck on its loading presentation.
            surface.apply(widgetChanges: widgetStates.values.map(WidgetChange.update))
            surfaces[id] = surface
        }
    }

    private func apply(_ updates: [DisplayBarUpdate]) {
        for update in updates {
            surfaces[update.id]?.apply(update, reduceMotion: reduceMotion)
        }
    }

    private func scheduleSettle() {
        settleTimer?.invalidate()
        settleTimer = nil
        guard core.isSettling else { return }
        let timer = Timer(timeInterval: core.settleDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.apply(self.core.advance(at: ProcessInfo.processInfo.systemUptime))
                self.scheduleSettle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        settleTimer = timer
    }
}
