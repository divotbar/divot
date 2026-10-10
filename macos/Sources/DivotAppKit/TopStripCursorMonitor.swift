import AppKit
import DivotCore

/// Event-driven monitor of the pointer's top-strip position.
///
/// When the native menu bar is auto-hidden, macOS reveals it as the pointer
/// reaches the top edge of a display. Public APIs do not report that reveal, so
/// Divot observes the pointer directly: a global (and local) mouse-moved
/// monitor maps `NSEvent.mouseLocation` onto the top strip of each display and
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
    private var displays: [ScreenGeometryReading] = []
    private var engaged: Set<DisplayBarID> = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var tokens: [NSObjectProtocol] = []

    public init(provider: ScreenGeometryProviding = NSScreenGeometryProvider(),
                stripHeight: CGFloat = CursorMenuBarReveal.defaultStripHeight) {
        self.provider = provider
        self.stripHeight = stripHeight
    }

    public var isRunning: Bool { globalMonitor != nil || localMonitor != nil }

    public func start() {
        guard !isRunning else { return }
        displays = provider.screens()
        engaged = currentEngaged()

        // A global monitor sees movement over other applications; a local
        // monitor sees movement over Divot's own windows (which a global
        // monitor deliberately excludes). NSEvent monitors normally call back on
        // the main thread; `deliverSample` handles an off-main callback without
        // allocating a task on the common path.
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
    }

    private func refreshDisplays() {
        displays = provider.screens()
        samplePointer()
    }

    private func samplePointer() {
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
        CursorMenuBarReveal.engagedDisplayIDs(mouseLocation: NSEvent.mouseLocation,
                                              displays: displays,
                                              stripHeight: stripHeight)
    }
}
