import AppKit
import DivotCore

/// Shared scaffolding for the popovers anchored to Divot's bar items.
///
/// The read-only Wi-Fi popover (task 0070), the output-volume popover (task
/// 0071), and the appearance popover (task 0072) present the same way: an
/// `NSPopover` anchored below the item, holding a vertical stack of a header, a
/// body, a separator, and a final settings row. This base owns that AppKit look
/// and the show/dismiss lifecycle so a second popover does not copy it. Its
/// label, secondary, and link rows are painted from the bar's `BarTheme`, so a
/// popover matches the bar it belongs to and its text clears the same contrast
/// audit the rest of the theme is checked against.
@MainActor
class BarPopoverContentController: NSViewController {
    let stack = NSStackView()

    /// The theme the popover draws: its label, secondary, and link text come from
    /// the bar theme (a family theme also paints the background). Set before the
    /// view loads (or via `apply(theme:)`) so a reopened popover matches the
    /// bar's current variant.
    var theme: BarTheme = .systemDefault {
        didSet { if isViewLoaded { applyTheme() } }
    }

    /// Identifiers the theme restyle uses to find the roles it recolours.
    static let headerIdentifier = NSUserInterfaceItemIdentifier("divot.popover.header")
    static let secondaryIdentifier = NSUserInterfaceItemIdentifier("divot.popover.secondary")
    static let linkIdentifier = NSUserInterfaceItemIdentifier("divot.popover.link")

    /// The rounded corner a family theme paints on its popover content.
    static let contentCornerRadius: CGFloat = 6

    /// The smallest width the popover will take. The shared floor suits the
    /// Wi-Fi and volume content (a wrapping message and a slider row); the
    /// Appearance popover lowers it so the popover hugs its segmented control
    /// and swatch grid instead of leaving an empty block beside them.
    var minimumContentWidth: CGFloat { 272 }

    /// The size the popover should occupy for the currently rendered state.
    var preferredSize: NSSize {
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        return NSSize(width: max(minimumContentWidth, fitting.width), height: max(1, fitting.height))
    }

    override func loadView() {
        let root = NSView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12)
        ])
        self.view = root
    }

    /// Adopt a theme: repaint the background and every text role it owns.
    func apply(theme: BarTheme) {
        self.theme = theme
    }

    /// Paint the theme's background and redraw its text roles. Safe to call
    /// before the view loads (a no-op until then).
    func applyTheme() {
        guard isViewLoaded else { return }
        // All themes paint a solid, opaque background so the popover renders
        // predictably regardless of what is behind it. Family themes use their
        // palette background; native uses the system window background (resolved
        // to light/dark from the popover's appearance setting).
        view.wantsLayer = true
        view.layer?.backgroundColor = theme.popoverPalette.background.cgColor
        if theme.usesSystemColors {
            view.layer?.borderWidth = 0
        } else {
            view.layer?.borderColor = theme.popoverPalette.separator.cgColor
            view.layer?.borderWidth = 1
            view.layer?.cornerRadius = Self.contentCornerRadius
            view.layer?.masksToBounds = true
        }
        restyle(theme)
        view.needsDisplay = true
    }

    /// Recolour the shared label/secondary/link rows from a theme. Subclasses
    /// extend this for their own controls.
    func restyle(_ theme: BarTheme) {
        let palette = theme.popoverPalette
        func walk(_ view: NSView) {
            if let field = view as? NSTextField {
                if field.identifier == Self.headerIdentifier {
                    field.textColor = palette.label
                } else if field.identifier == Self.secondaryIdentifier {
                    field.textColor = palette.secondary
                }
            } else if let button = view as? NSButton, button.identifier == Self.linkIdentifier {
                button.contentTintColor = palette.link
            }
            view.subviews.forEach(walk)
        }
        walk(view)
    }

    /// Remove every arranged row so a state change can rebuild the stack.
    func clearRows() {
        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    func header(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = theme.popoverPalette.label
        label.identifier = Self.headerIdentifier
        label.alignment = .left
        return label
    }

    /// A small all-caps section title above a group of choices, shared so the
    /// popovers read as one family.
    func sectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = theme.popoverPalette.secondary
        label.identifier = Self.secondaryIdentifier
        label.alignment = .left
        return label
    }

    func message(_ text: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = theme.popoverPalette.secondary
        label.identifier = Self.secondaryIdentifier
        label.maximumNumberOfLines = 0
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 248).isActive = true
        return label
    }

    func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    func linkButton(_ title: String, action: Selector) -> NSView {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.alignment = .left
        button.font = .systemFont(ofSize: 12)
        button.contentTintColor = theme.popoverPalette.link
        button.identifier = Self.linkIdentifier
        return button
    }
}

/// What a press does to an open popover.
///
/// A `.transient` `NSPopover` closes on a click inside Divot's own windows, but
/// not on a click in another app or on the desktop — the gap this fills. The
/// decision is made in a local event monitor, which runs before the popover's
/// own transient handling, so a press on the anchor item can be consumed before
/// it is used to re-present the popover.
enum PopoverPressAction: Equatable {
    /// Leave the popover open and let the control under the press act.
    case keepOpen
    /// Close the popover and let the control under the press act (so a click on
    /// a different item opens its own popover, or a settings link opens).
    case dismissAndPass
    /// Close the popover and consume the press. A second click on the bar item
    /// that owns the popover is the toggle-close; consuming it stops the item's
    /// action from re-presenting the popover it just closed.
    case dismissAndConsume
}

/// The dismiss decision a press or key makes.
enum PopoverDismissPolicy {
    /// A press delivered to another app (or the desktop) closes the popover.
    static func actionForOutsideAppPress() -> PopoverPressAction { .dismissAndPass }
    /// A press delivered to Divot's own app: `onAnchor` when it lands on the bar
    /// item that owns the popover, `insidePopover` when it lands in the popover.
    static func actionForInAppPress(onAnchor: Bool, insidePopover: Bool) -> PopoverPressAction {
        if insidePopover { return .keepOpen }
        return onAnchor ? .dismissAndConsume : .dismissAndPass
    }
    /// Escape always closes an open popover.
    static func dismissesForEscape() -> Bool { true }
    /// Clicking the bar item that already owns the open popover closes it; any
    /// other click presents.
    static func itemClickCloses(alreadyOwnsAnchor: Bool) -> Bool { alreadyOwnsAnchor }
}

/// Installs the monitors that dismiss a popover on a press outside it and on
/// Escape, and removes them the moment it closes.
///
/// It is injectable so the host's dismiss lifecycle is testable without a real
/// event monitor or window server.
@MainActor
protocol PopoverEventMonitoring: AnyObject {
    /// `action` decides what a press delivered to Divot's own app does; a press
    /// in another app always closes it. `onDismiss` runs on the main actor for
    /// any closing press or Escape.
    func start(action: @escaping (NSEvent) -> PopoverPressAction, onDismiss: @escaping () -> Void)
    /// Remove the monitors. Idempotent.
    func stop()
    /// True while the monitors are installed; false after `stop()`.
    var isMonitoring: Bool { get }
}

/// The live monitors: a global mouse-down monitor for presses in other apps and
/// on the desktop (which a `.transient` `NSPopover` does not see), a local
/// mouse-down monitor for presses in Divot's own windows, and Escape.
///
/// Nothing polls: the monitors are installed while a popover is shown and
/// removed when it closes.
@MainActor
final class PopoverEventMonitor: PopoverEventMonitoring {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var action: ((NSEvent) -> PopoverPressAction)?
    private var onDismiss: (() -> Void)?

    var isMonitoring: Bool { globalMonitor != nil && localMonitor != nil }

    func start(action: @escaping (NSEvent) -> PopoverPressAction, onDismiss: @escaping () -> Void) {
        stop()
        self.action = action
        self.onDismiss = onDismiss
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // A global monitor sees only events delivered to other apps (and the
        // desktop), so any of them is an outside click.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated { self?.onDismiss?() }
        }
        // A local monitor sees events delivered to Divot's own windows, which a
        // global monitor deliberately excludes. Escape closes here too, since an
        // accessory app's bar click does not always make the popover key.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks.union(.keyDown)) { [weak self] event in
            guard let self else { return event }
            return self.handleLocal(event)
        }
    }

    /// Handle one press or key delivered to Divot's own app. Escape closes and
    /// is consumed; a dismiss-and-consume press closes and is swallowed; any
    /// other press is passed on so the control under it still acts.
    private func handleLocal(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown, event.keyCode == 53 { // Escape
            onDismiss?()
            return nil
        }
        switch action?(event) ?? .dismissAndPass {
        case .keepOpen:
            return event
        case .dismissAndPass:
            onDismiss?()
            return event
        case .dismissAndConsume:
            onDismiss?()
            return nil
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        action = nil
        onDismiss = nil
    }
}

/// Owns one anchored `NSPopover` and its content controller.
///
/// The popover is `.transient` and additionally watched by `PopoverEventMonitor`
/// so a click outside the app or on the desktop dismisses it, which `.transient`
/// alone does not catch for an accessory app. Escape closes it, and a second
/// click on the same bar item toggles it closed: the local monitor runs before
/// the popover's own transient handling, closes it, and consumes the press so
/// the item's action cannot immediately re-present it. The monitors are installed
/// while it is shown and removed the instant it closes. `onClose` reports that
/// close so the owner can tear down observers.
@MainActor
final class BarPopoverHost: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?
    /// The bar item the popover is anchored to, so a press on it is the item's
    /// own toggle rather than an outside click.
    private weak var anchor: NSView?
    private let monitors: any PopoverEventMonitoring

    init(monitors: any PopoverEventMonitoring = PopoverEventMonitor()) {
        self.monitors = monitors
        super.init()
    }

    /// Called after the popover closes for any reason — an explicit `dismiss()`,
    /// a click outside, or Escape — so the owner can remove its observers.
    var onClose: (() -> Void)?

    var isShown: Bool { popover != nil }

    /// True while the outside-click/Escape monitors are installed.
    var isMonitoringDismiss: Bool { monitors.isMonitoring }

    /// True when this host already shows a popover anchored to `view`, so the
    /// item's click closes it rather than re-presenting it.
    func isShown(relativeTo view: NSView) -> Bool { popover != nil && anchor === view }

    /// The item-click decision: a second click on the bar item that already owns
    /// the open popover closes it; any other click opens it.
    func itemClickCloses(relativeTo view: NSView) -> Bool {
        PopoverDismissPolicy.itemClickCloses(alreadyOwnsAnchor: isShown(relativeTo: view))
    }

    func present(_ content: BarPopoverContentController, relativeTo view: NSView) {
        dismiss()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        // Adopt the bar theme's variant so the popover chrome and its system
        // controls match the bar even when the app-wide appearance differs.
        popover.appearance = content.theme.popoverAppearance
        popover.contentViewController = content
        content.applyTheme()
        popover.contentSize = content.preferredSize
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        // Make the popover window opaque and solid-backed from the theme palette
        // so the popover always renders predictably regardless of what is behind it.
        configurePopoverWindowOpacity(popover, theme: content.theme)
        self.popover = popover
        anchor = view
        startDismissMonitors()
    }

    /// Configure the popover window to be opaque and solid-backed from the theme
    /// palette, disabling any vibrancy/translucency material.
    private func configurePopoverWindowOpacity(_ popover: NSPopover, theme: BarTheme) {
        guard let window = popover.contentViewController?.view.window else { return }
        let palette = theme.popoverPalette
        window.isOpaque = true
        window.backgroundColor = palette.background
    }

    /// Match the popover to a content controller whose preferred size changed.
    func resize(to size: NSSize) {
        popover?.contentSize = size
    }

    func dismiss() {
        stopDismissMonitors()
        guard let popover else { return }
        self.popover = nil
        anchor = nil
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        // A close that arrives after a newer popover was presented must not
        // tear down the current one's state.
        guard let closed = notification.object as? NSPopover, closed === popover else { return }
        stopDismissMonitors()
        popover = nil
        anchor = nil
        onClose?()
    }

    // MARK: - Dismiss monitors

    /// What a press delivered inside Divot's own app should do. Internal so the
    /// decision is unit-tested directly.
    func pressAction(localEvent event: NSEvent) -> PopoverPressAction {
        // A press inside the popover itself keeps it open.
        if let popoverWindow = popover?.contentViewController?.view.window,
           event.window === popoverWindow {
            return PopoverDismissPolicy.actionForInAppPress(onAnchor: false, insidePopover: true)
        }
        // A press on the anchor item is the toggle-close; it is consumed so the
        // item's action cannot re-present the popover it just closed.
        if let anchor, let anchorWindow = anchor.window, event.window === anchorWindow {
            let point = anchor.convert(event.locationInWindow, from: nil)
            if anchor.bounds.contains(point) {
                return PopoverDismissPolicy.actionForInAppPress(onAnchor: true, insidePopover: false)
            }
        }
        return PopoverDismissPolicy.actionForInAppPress(onAnchor: false, insidePopover: false)
    }

    /// Install the dismiss monitors for the shown popover. Internal so the
    /// lifecycle is testable without a window server.
    func startDismissMonitors() {
        monitors.start(action: { [weak self] event in
            MainActor.assumeIsolated { self?.pressAction(localEvent: event) ?? .dismissAndPass }
        }, onDismiss: { [weak self] in
            MainActor.assumeIsolated { self?.dismiss() }
        })
    }

    /// Remove the dismiss monitors. Idempotent.
    func stopDismissMonitors() {
        monitors.stop()
    }
}
