import AppKit
import DivotCore

/// Shared scaffolding for the popovers anchored to Divot's bar items.
///
/// The Wi-Fi popover (task 0070, clickable since task 0099), the output-volume popover (task
/// 0071), and the appearance popover (task 0072) present the same way: an
/// `NSPopover` anchored below the item, holding a vertical stack of a header, a
/// body, a separator, and a final settings row. This base owns that AppKit look
/// and the show/dismiss lifecycle so a second popover does not copy it. Its
/// label, secondary, and link rows are painted from the bar's `BarTheme`, so a
/// popover matches the bar it belongs to and its text clears the same contrast
/// audit the rest of the theme is checked against.
@MainActor
class BarPopoverContentController: NSViewController {
    let stack = PopoverRowStack()

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
    static let contentCornerRadius: CGFloat = 7

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
        stack.alignment = .leading
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
        view.layer?.backgroundColor = theme.popoverPalette.background.withAlphaComponent(1).cgColor
        // The border is drawn by `PopoverChromeView`; the content only clips its
        // own fill to the bubble's inner corner radius.
        view.layer?.borderWidth = 0
        view.layer?.cornerRadius = Self.contentCornerRadius
        view.layer?.masksToBounds = true
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

    /// The one footer-link style: link-role text, left-aligned at the leading
    /// inset, full row width.
    func linkButton(_ title: String, action: Selector) -> NSView {
        let button = PopoverLinkButton(title: title, target: self, action: action)
        button.contentTintColor = theme.popoverPalette.link
        button.identifier = Self.linkIdentifier
        return button
    }
}

/// The vertical row stack every popover uses. Every row is pinned flush to the
/// leading edge and stretched toward the trailing edge, so a row can never be
/// centred or right-aligned inside a wider popover (AppKit's `.width` alignment
/// leaves a low-hugging row centred at its intrinsic width).
@MainActor
final class PopoverRowStack: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        pin(view)
    }

    override func insertArrangedSubview(_ view: NSView, at index: Int) {
        super.insertArrangedSubview(view, at: index)
        pin(view)
    }

    private func pin(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        let trailing = view.trailingAnchor.constraint(equalTo: trailingAnchor)
        trailing.priority = .defaultHigh
        trailing.isActive = true
    }
}

/// A borderless text button that always draws its title flush left in the
/// theme's link colour (AppKit centres a borderless button's title inside a
/// wide frame, which put footer links on the right).
@MainActor
final class PopoverLinkButton: NSButton {
    static let rowHeight: CGFloat = 22

    init(title: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        setButtonType(.momentaryPushIn)
        alignment = .left
        font = .systemFont(ofSize: 12)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { fatalError("created in code") }

    override var contentTintColor: NSColor? { didSet { needsDisplay = true } }

    private var attributedLabel: NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: font ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: contentTintColor ?? NSColor.linkColor
        ])
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: ceil(attributedLabel.size().width), height: Self.rowHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let label = attributedLabel
        let size = label.size()
        label.draw(at: NSPoint(x: 0, y: floor((bounds.height - size.height) / 2)))
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

/// The chrome Divot draws for every popover: one solid bubble (rounded body plus
/// an arrow toward the anchor) filled with the opaque theme background and
/// stroked with the theme separator. No `NSVisualEffectView`, material, or
/// gradient is involved.
@MainActor
final class PopoverChromeView: NSView {
    static let arrowHeight: CGFloat = 8
    static let arrowWidth: CGFloat = 16
    static let cornerRadius: CGFloat = 8

    var palette: BarTheme.PopoverPalette { didSet { needsDisplay = true } }
    /// Arrow tip x, in this view's coordinates.
    var arrowX: CGFloat { didSet { needsDisplay = true } }

    init(palette: BarTheme.PopoverPalette, arrowX: CGFloat) {
        self.palette = palette
        self.arrowX = arrowX
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("created in code") }

    override var isFlipped: Bool { false }

    /// The bubble outline for `bounds` (arrow on top).
    func bubblePath() -> NSBezierPath {
        let body = NSRect(x: 0.5, y: 0.5, width: bounds.width - 1,
                          height: bounds.height - Self.arrowHeight - 0.5)
        let path = NSBezierPath(roundedRect: body, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        let half = Self.arrowWidth / 2
        let x = min(max(arrowX, Self.cornerRadius + half), bounds.width - Self.cornerRadius - half)
        path.move(to: NSPoint(x: x - half, y: body.maxY - 0.5))
        path.line(to: NSPoint(x: x, y: body.maxY + Self.arrowHeight - 0.5))
        path.line(to: NSPoint(x: x + half, y: body.maxY - 0.5))
        path.close()
        return path
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = bubblePath()
        palette.background.withAlphaComponent(1).setFill()
        path.fill()
        palette.separator.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

/// The borderless panel that replaces `NSPopover`.
final class BarPopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns one anchored popover panel and its content controller.
///
/// Root cause of the remaining translucency (#0083): `NSPopover` draws its own
/// frame view with a vibrant system material, which a layer fill painted on the
/// content view cannot remove (the content only covers the inside of the frame).
/// So Divot no longer uses `NSPopover`: the host shows a borderless panel whose
/// only chrome is `PopoverChromeView`, drawn solid by Divot, shared by every
/// popover. The panel window itself is non-opaque only so the rounded corners
/// and arrow can be cut out; every pixel inside the bubble is opaque.
///
/// Dismissal is `PopoverEventMonitor`: a press outside the app or on the
/// desktop, Escape, and a second click on the same bar item (consumed so the
/// item cannot re-present it). The monitors are installed while shown and
/// removed the instant it closes. `onClose` reports that close.
@MainActor
final class BarPopoverHost: NSObject {
    private(set) var panel: BarPopoverPanel?
    private var chrome: PopoverChromeView?
    private var content: BarPopoverContentController?
    /// The bar item the popover is anchored to, so a press on it is the item's
    /// own toggle rather than an outside click.
    private weak var anchor: NSView?
    private let monitors: any PopoverEventMonitoring
    /// The seam that actually shows the panel. Tests inject a no-op presenter so
    /// presenting never puts the popover on screen (#0091).
    private let presenter: any WindowPresenting

    init(monitors: any PopoverEventMonitoring = PopoverEventMonitor(),
         presenter: any WindowPresenting = SystemWindowPresenter()) {
        self.monitors = monitors
        self.presenter = presenter
        super.init()
    }

    /// Called after the popover closes for any reason.
    var onClose: (() -> Void)?

    var isShown: Bool { panel != nil }

    /// The shown popover window, for runtime assertions.
    var window: NSWindow? { panel }

    /// True while the outside-click/Escape monitors are installed.
    var isMonitoringDismiss: Bool { monitors.isMonitoring }

    func isShown(relativeTo view: NSView) -> Bool { panel != nil && anchor === view }

    func itemClickCloses(relativeTo view: NSView) -> Bool {
        PopoverDismissPolicy.itemClickCloses(alreadyOwnsAnchor: isShown(relativeTo: view))
    }

    func present(_ content: BarPopoverContentController, relativeTo view: NSView) {
        dismiss()
        let panel = BarPopoverPanel(contentRect: .zero,
                                    styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered,
                                    defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.appearance = content.theme.popoverAppearance
        panel.setAccessibilityLabel("Popover")

        let chrome = PopoverChromeView(palette: content.theme.popoverPalette, arrowX: 0)
        panel.contentView = chrome
        chrome.addSubview(content.view)
        content.applyTheme()

        self.panel = panel
        self.chrome = chrome
        self.content = content
        self.anchor = view
        layoutPanel(size: content.preferredSize)
        presenter.makeKeyAndOrderFront(panel)
        startDismissMonitors()
    }

    /// Size and place the panel under the anchor, clamped to its screen.
    private func layoutPanel(size: NSSize) {
        guard let panel, let chrome, let content, let anchor, let anchorWindow = anchor.window else { return }
        let arrow = PopoverChromeView.arrowHeight
        let total = NSSize(width: size.width + 2, height: size.height + arrow + 2)
        let anchorScreen = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let visible = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000)
        var x = anchorScreen.midX - total.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - total.width - 8)
        let y = anchorScreen.minY - total.height - 2
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: total), display: false)
        chrome.frame = NSRect(origin: .zero, size: total)
        chrome.arrowX = anchorScreen.midX - x
        content.view.frame = NSRect(x: 1, y: 1, width: size.width, height: size.height)
        content.view.layoutSubtreeIfNeeded()
    }

    /// Match the popover to a content controller whose preferred size changed.
    func resize(to size: NSSize) {
        layoutPanel(size: size)
    }

    /// Update the shown popover's theme without closing it.
    func restyle(theme: BarTheme) {
        guard let panel, let chrome, let content else { return }
        content.apply(theme: theme)
        chrome.palette = theme.popoverPalette
        panel.appearance = theme.popoverAppearance
    }

    func dismiss() {
        stopDismissMonitors()
        guard let panel else { return }
        self.panel = nil
        chrome = nil
        content = nil
        anchor = nil
        panel.orderOut(nil)
        onClose?()
    }

    // MARK: - Dismiss monitors

    /// What a press delivered inside Divot's own app should do. Internal so the
    /// decision is unit-tested directly.
    func pressAction(localEvent event: NSEvent) -> PopoverPressAction {
        // A press inside the popover itself keeps it open.
        if let popoverWindow = panel, event.window === popoverWindow {
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
