import AppKit
import DivotCore

/// Hosts the keep-awake toast panel: a transient message below the battery item.
///
/// The toast appears when caffeine is toggled, shows for ~2 seconds, and dismisses
/// itself without requiring a click. It uses the same borderless panel chrome as
/// popovers but ignores mouse events and never becomes key.
@MainActor
public final class KeepAwakeToastHost: NSObject {
    private(set) var panel: NSPanel?
    private var content: KeepAwakeToastContentView?
    /// The bar item the toast is anchored to (the battery), so we can position it.
    private weak var anchor: NSView?
    /// The seam that shows the panel. Tests inject a no-op presenter.
    private let presenter: any WindowPresenting

    public init(presenter: any WindowPresenting = SystemWindowPresenter()) {
        self.presenter = presenter
        super.init()
    }

    public var isShown: Bool { panel != nil }

    /// Show or update the toast with the given state, anchored below the battery item.
    public func present(_ state: KeepAwakeToastState, relativeTo view: NSView, theme: BarTheme) {
        dismiss(animated: false)

        let panel = NSPanel(contentRect: .zero,
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
        panel.ignoresMouseEvents = true
        panel.alphaValue = 1
        panel.appearance = theme.popoverAppearance
        panel.setAccessibilityElement(false)

        let content = KeepAwakeToastContentView(state: state, theme: theme)
        panel.contentView = content

        self.panel = panel
        self.content = content
        self.anchor = view

        layoutPanel()
        presenter.orderFrontRegardless(panel)
    }

    /// Hide the toast. Fades out unless Reduce Motion is on.
    public func dismiss(animated: Bool = false) {
        guard let panel else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animated && !reduceMotion {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.finishDismiss(panel)
            })
        } else {
            finishDismiss(panel)
        }
    }

    private func finishDismiss(_ panel: NSPanel) {
        guard self.panel === panel else { return }
        self.panel = nil
        content = nil
        anchor = nil
        panel.orderOut(nil)
    }

    /// Position and size the panel below the anchor item, clamped to the screen.
    private func layoutPanel() {
        guard let panel, let content, let anchor, let anchorWindow = anchor.window else { return }

        let size = content.intrinsicContentSize
        let totalHeight = size.height + 2
        let totalWidth = size.width + 2

        let anchorScreen = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let visible = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000)

        var x = anchorScreen.midX - totalWidth / 2
        x = min(max(x, visible.minX + 8), visible.maxX - totalWidth - 8)

        let y = anchorScreen.minY - totalHeight - 2

        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: NSSize(width: totalWidth, height: totalHeight)),
                       display: false)
        content.frame = NSRect(origin: .zero, size: NSSize(width: totalWidth, height: totalHeight))
    }

    /// Clean up on quit without displaying anything.
    public func releaseAll() {
        dismiss(animated: false)
    }
}

/// The content view of the toast: main text, optional subtext, and a colored accent.
@MainActor
final class KeepAwakeToastContentView: NSView {
    let state: KeepAwakeToastState
    let theme: BarTheme

    init(state: KeepAwakeToastState, theme: BarTheme) {
        self.state = state
        self.theme = theme
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = theme.popoverPalette.background.withAlphaComponent(1).cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(state.mainText)
    }

    required init?(coder: NSCoder) { fatalError("created in code") }

    override var acceptsFirstResponder: Bool { false }

    override var intrinsicContentSize: NSSize {
        let mainFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let subtextFont = NSFont.systemFont(ofSize: 11)

        let mainAttr = NSAttributedString(string: state.mainText, attributes: [.font: mainFont])
        let mainSize = mainAttr.size()

        let subtextAttr = NSAttributedString(string: state.subtext, attributes: [.font: subtextFont])
        let subtextSize = subtextAttr.size()

        let width = max(mainSize.width, subtextSize.width) + 24
        let height = mainSize.height + 2 + subtextSize.height + 16

        return NSSize(width: width, height: height)
    }

    func accentColor() -> NSColor {
        let hex = state.colorRole == .active
            ? KeepAwakeToastPalette.activeHex(dark: theme.isDark)
            : KeepAwakeToastPalette.inactiveHex(dark: theme.isDark)
        guard let themeColor = ThemeColor(hex: hex) else { return .labelColor }
        return NSColor(themeColor)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let palette = theme.popoverPalette
        let mainFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let subtextFont = NSFont.systemFont(ofSize: 11)

        let mainColor = accentColor()
        let subtextColor = palette.secondary

        let mainText = NSAttributedString(
            string: state.mainText,
            attributes: [.font: mainFont, .foregroundColor: mainColor])
        let subtextText = NSAttributedString(
            string: state.subtext,
            attributes: [.font: subtextFont, .foregroundColor: subtextColor])

        let mainSize = mainText.size()
        let subtextSize = subtextText.size()

        let dotSize: CGFloat = 6
        let dotX: CGFloat = 12
        let dotY = bounds.height / 2 - mainSize.height / 2 + mainSize.height / 2 - dotSize / 2
        let textX: CGFloat = 12 + dotSize + 6

        let dotPath = NSBezierPath(ovalIn: NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize))
        mainColor.setFill()
        dotPath.fill()

        mainText.draw(at: NSPoint(x: textX, y: bounds.height - 8 - mainSize.height))
        subtextText.draw(at: NSPoint(x: textX, y: bounds.height - 8 - mainSize.height - 2 - subtextSize.height))
    }
}
