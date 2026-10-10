import AppKit
import DivotCore

/// Event-driven monitor of the pointer's top-strip position.
///
/// When the native menu bar is auto-hidden, macOS reveals it as the pointer
/// reaches the top edge of a display. Public APIs do not report that reveal, so
/// Divot observes the pointer directly: a global (and local) mouse-moved
/// monitor maps the pointer position onto the top strip of each display and
/// reports the engaged display IDs. It never polls — work happens only when the
/// pointer crosses into or out of a strip — and it holds no window or view, so
/// the bar's widget views stay free of input handling (#0023).
///
/// The monitor only reports geometry. Whether an engaged display actually
/// slides is `NativeMenuBarDetector`'s decision, gated by
/// `menuBar.moveBelowOnCursorReveal`; a notch-free display cross-checks the
/// reading against its own `visibleFrame`.
@MainActor
public final class TopStripCursorMonitor {
    /// Called on the main actor whenever the engaged display set changes (and
    /// once at `start`). An empty set means the pointer is not in any top strip.
    public var onChange: ((Set<DisplayBarID>) -> Void)?

    /// Reveal-strip height in points; see `CursorMenuBarReveal`.
    public var stripHeight: CGFloat

    private let provider: ScreenGeometryProviding
    /// The pointer position, injectable so the tracking loop is testable without
    /// a window server. In production this is `NSEvent.mouseLocation`.
    private let pointerLocation: () -> CGPoint
    /// False in tests: the tracking loop still runs, but no real `NSEvent`
    /// monitors are installed.
    private let installsEventMonitors: Bool

    private var displays: [ScreenGeometryReading] = []
    private var engaged: Set<DisplayBarID> = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var tokens: [NSObjectProtocol] = []
    private var started = false

    public convenience init(provider: ScreenGeometryProviding = NSScreenGeometryProvider(),
                            stripHeight: CGFloat = CursorMenuBarReveal.defaultStripHeight) {
        self.init(provider: provider,
                  stripHeight: stripHeight,
                  pointerLocation: { NSEvent.mouseLocation },
                  installsEventMonitors: true)
    }

    /// Designated initializer. The pointer source and the event-monitor flag are
    /// seams for tests.
    init(provider: ScreenGeometryProviding,
         stripHeight: CGFloat,
         pointerLocation: @escaping () -> CGPoint,
         installsEventMonitors: Bool) {
        self.provider = provider
        self.stripHeight = stripHeight
        self.pointerLocation = pointerLocation
        self.installsEventMonitors = installsEventMonitors
    }

    public var isRunning: Bool { started }

    /// Start or stop the event monitors from the current setting. Disabling
    /// removes the global/local monitor and the screen-change observer, so an
    /// install with the cursor reveal (and the always-below fallback) off keeps
    /// no global mouse tap installed; re-enabling re-reads the pointer and
    /// reports the current engagement at once (#0023 review).
    public func setEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    /// True when the global mouse monitor installed. A global monitor is what
    /// tracks the pointer over other applications; if it is unavailable only the
    /// local monitor (Divot's own windows) runs, so the app surfaces this so
    /// support can tell "setting off" from "no global events" (#0023 review).
    public var globalMonitorInstalled: Bool { globalMonitor != nil }

    public func start() {
        guard !started else { return }
        started = true
        displays = provider.screens()
        engaged = currentEngaged()

        if installsEventMonitors {
            // A global monitor sees movement over other applications; a local
            // monitor sees movement over Divot's own windows (which a global
            // monitor deliberately excludes). NSEvent monitors normally call
            // back on the main thread; `deliverSample` handles an off-main
            // callback without allocating a task on the common path.
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                self?.deliverSample()
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                self?.deliverSample()
                return event
            }
            // A newly attached or reconfigured display changes which frames the
            // pointer can enter; re-read them rather than polling.
            let token = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshDisplays() }
                }
            tokens.append(token)
        }

        // Deliver the state at start so the coordinator is not waiting for the
        // first move to agree with the pointer's actual position.
        onChange?(engaged)
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        for token in tokens { NotificationCenter.default.removeObserver(token) }
        tokens.removeAll()
        started = false
    }

    private func refreshDisplays() {
        displays = provider.screens()
        samplePointer()
    }

    /// Re-read the pointer position and report an engagement change. Internal so
    /// tests can drive the tracking loop without a real event monitor.
    func samplePointer() {
        let next = currentEngaged()
        guard next != engaged else { return }
        engaged = next
        onChange?(next)
    }

    /// Run a pointer sample on the main actor without allocating a task when the
    /// callback already arrives there. `NSEvent` monitors normally do; the
    /// off-main branch keeps a different delivery thread from racing the
    /// main-actor reads.
    private nonisolated func deliverSample() {
        if Thread.isMainThread {
            MainActor.assumeIsolated { samplePointer() }
        } else {
            Task { @MainActor in self.samplePointer() }
        }
    }

    private func currentEngaged() -> Set<DisplayBarID> {
        CursorMenuBarReveal.engagedDisplayIDs(mouseLocation: pointerLocation(),
                                              displays: displays,
                                              stripHeight: stripHeight)
    }
}
