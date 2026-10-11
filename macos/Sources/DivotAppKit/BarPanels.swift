import AppKit
import DivotCore

/// A per-display pair of panels that the coordinator positions and fills.
@MainActor
public protocol BarDisplaySurface: AnyObject {
    func apply(_ update: DisplayBarUpdate, reduceMotion: Bool)
    /// Apply a batch of widget changes to whichever items this surface renders.
    /// Items not on this display are ignored.
    func apply(widgetChanges: [WidgetChange])
    func close()
}

/// Panel content that must release observers when its panel is torn down.
@MainActor
public protocol BarContentLifecycle: AnyObject {
    func barContentDidDetach()
}

/// Two borderless, nonactivating `NSPanel`s per display.
///
/// The split around the camera housing is the whole reason there are two panels:
/// no hit region ever crosses the notch. `canBecomeKey`/`canBecomeMain` are
/// `false` so the bar cannot take focus from the user's frontmost app. Each
/// panel renders half of the configured left/right item groups.
@MainActor
public final class NSPanelBarSurface: BarDisplaySurface {
    /// A panel that refuses key/main status: the bar decorates the desktop and
    /// must never steal focus.
    private final class NonActivatingPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }

        /// Let the panel occupy the camera-housing band beside the notch.
        ///
        /// AppKit's default constraint clamps a window so its frame stays below
        /// the menu-bar band — `visibleFrame.maxY` — even while the native bar
        /// is auto-hidden. On the built-in notched display that parked the
        /// top-edge bar at the *bottom* of the housing band (observed as y=33
        /// from the top) instead of the top edge, which is the reported bug.
        /// The panel level stays just under the system menu bar, so native menus
        /// still draw above Divot; only the frame clamp is bypassed (#0021).
        /// `BarGeometry` already clamps every segment onto the display, so the
        /// bypass never places a panel off-screen.
        override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
            frameRect
        }
    }

    public let id: DisplayBarID
    private let left: NonActivatingPanel
    private let right: NonActivatingPanel
    private let leftContent: BarContentView
    private let rightContent: BarContentView
    private var targets: [ObjectIdentifier: CGRect] = [:]
    /// The configuration the panels were built from, so a restyle can recompute
    /// the theme without a rebuild.
    private let configuration: DivotConfiguration
    /// Extra panel height below the bar reserved for the optional bottom-shadow
    /// strip; zero when the shadow is off. The panel is enlarged by this much so
    /// the gradient can draw *outside* the flat bar instead of over it (#0025).
    private let shadowHeight: CGFloat
    /// Called after a restyle so the app can drop appearance-dependent caches.
    public var onThemeChanged: (() -> Void)?

    /// How far the optional bottom shadow reaches below the bar.
    private static let bottomShadowHeight: CGFloat = 6

    public init(id: DisplayBarID,
                on screen: CGRect,
                configuration: DivotConfiguration = .default,
                workspaceFeed: WorkspaceFeed? = nil,
                workspaceIcons: WorkspaceIconProviding? = nil,
                displayScreensID: Int? = nil,
                onWidgetAction: ((WidgetAction) -> Void)? = nil) {
        self.id = id
        self.configuration = configuration
        let shadowStrip = configuration.bottomShadow ? Self.bottomShadowHeight : 0
        self.shadowHeight = shadowStrip
        let layout = configuration.barLayout
        let theme = Self.currentTheme(for: configuration)
        self.leftContent = BarContentView(side: .left,
                                          items: layout.left,
                                          showsAppIcon: configuration.showAppIcon,
                                          showOccupiedDot: configuration.showOccupiedDot,
                                          showEmptyDot: configuration.showEmptyDot,
                                          enablesChipStyle: configuration.chipStyle,
                                          workspaceFeed: workspaceFeed,
                                          workspaceIcons: workspaceIcons,
                                          displayScreensID: displayScreensID,
                                          metrics: configuration.barMetrics,
                                          presentationOptions: configuration.presentationOptions,
                                          theme: theme,
                                          onActivate: onWidgetAction)
        self.rightContent = BarContentView(side: .right,
                                           items: layout.right,
                                           enablesChipStyle: configuration.chipStyle,
                                           metrics: configuration.barMetrics,
                                           presentationOptions: configuration.presentationOptions,
                                           theme: theme,
                                           onActivate: onWidgetAction)
        self.left = Self.makePanel(on: screen, content: leftContent, shadowHeight: shadowStrip)
        self.right = Self.makePanel(on: screen, content: rightContent, shadowHeight: shadowStrip)
        leftContent.onEffectiveAppearanceChange = { [weak self] in self?.restyle() }
        rightContent.onEffectiveAppearanceChange = { [weak self] in self?.restyle() }
        leftContent.applyInitialState()
        rightContent.applyInitialState()
        left.orderFrontRegardless()
        right.orderFrontRegardless()
    }

    /// The theme for the current configuration and the live effective
    /// appearance. `mode` is applied app-wide, so the effective appearance is
    /// the single source of truth for the light/dark variant.
    static func currentTheme(for configuration: DivotConfiguration) -> BarTheme {
        let dark = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return BarTheme.resolve(configuration.appearance, dark: dark)
    }

    private func restyle() {
        let theme = Self.currentTheme(for: configuration)
        leftContent.apply(theme: theme)
        rightContent.apply(theme: theme)
        onThemeChanged?()
    }

    public func apply(_ update: DisplayBarUpdate, reduceMotion: Bool) {
        if update.cancelAnimations {
            cancelAnimations()
        }
        guard let placement = update.placement else { return }
        let animate = update.animated && !reduceMotion
        // Extend the notch-side edge only where the geometry was genuinely split
        // around a camera housing. `BarGeometry` decides that from the display's
        // auxiliary top areas, so a notch-free top-edge seam is never mistaken
        // for a notch (#0028). Below the native bar there is no housing to
        // extend into, and the geometry reports `hasNotch == false` there too.
        let extendsIntoNotch = placement.geometry.hasNotch
        move(left, to: placement.geometry.left, side: .left,
             hasNotch: extendsIntoNotch, animated: animate)
        move(right, to: placement.geometry.right, side: .right,
             hasNotch: extendsIntoNotch, animated: animate)
    }

    /// The frames the two panels were last told to occupy, in screen
    /// coordinates, or `nil` before the first placement. Exposed so tests can
    /// assert the production placement path end to end (#0028).
    var appliedPanelFrames: (left: CGRect, right: CGRect)? {
        guard let leftFrame = targets[ObjectIdentifier(left)],
              let rightFrame = targets[ObjectIdentifier(right)] else { return nil }
        return (leftFrame, rightFrame)
    }

    public func apply(widgetChanges: [WidgetChange]) {
        leftContent.apply(widgetChanges)
        rightContent.apply(widgetChanges)
    }

    public func close() {
        leftContent.barContentDidDetach()
        rightContent.barContentDidDetach()
        left.orderOut(nil)
        right.orderOut(nil)
        left.close()
        right.close()
    }

    private static func makePanel(on screen: CGRect, content: NSView, shadowHeight: CGFloat) -> NonActivatingPanel {
        let panel = NonActivatingPanel(contentRect: CGRect(x: screen.minX, y: screen.maxY, width: 1, height: 1),
                                       styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered,
                                       defer: false)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The optional bottom shadow (#0025) is drawn by `BarPanelContainer`
        // inside an enlarged panel, not by the window server: a window shadow
        // would rim every edge, including the camera-housing gap on a notched
        // display. The panel itself stays shadowless.
        panel.hasShadow = false
        // Just under the system menu bar, so native menus still open above
        // Divot. Spatial placement already avoids overlap on notch-free
        // displays; this keeps the native bar on top in the unresolved notched
        // case. Final level/collection choices are physical-validation items.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = BarPanelContainer(content: content, shadowHeight: shadowHeight)
        return panel
    }

    private func move(_ panel: NSPanel, to frame: CGRect, side: BarSide, hasNotch: Bool, animated: Bool) {
        // Reserve the shadow strip below the bar when the shadow is on, so the
        // gradient draws over the desktop rather than over the bar content.
        // On a notched display, extend the notch-side edge by 6 points to cover
        // the rounded corners of the housing (#0028).
        let extendedFrame = hasNotch ? Self.extendFrameIntoNotch(frame, side: side) : frame
        let target = Self.panelFrame(for: extendedFrame, shadowHeight: shadowHeight)
        targets[ObjectIdentifier(panel)] = target
        guard animated else {
            panel.setFrame(target, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }

    /// Extend the bar frame by 6 points on the notch-side edge to cover the
    /// rounded corners of the housing (#0028).
    static func extendFrameIntoNotch(_ barFrame: CGRect, side: BarSide) -> CGRect {
        let ext: CGFloat = 6
        switch side {
        case .left:
            return CGRect(x: barFrame.minX,
                          y: barFrame.minY,
                          width: barFrame.width + ext,
                          height: barFrame.height)
        case .right:
            return CGRect(x: barFrame.minX - ext,
                          y: barFrame.minY,
                          width: barFrame.width + ext,
                          height: barFrame.height)
        }
    }

    /// The panel frame for a bar rect: the bar rect itself, or that rect
    /// enlarged downward by `shadowHeight` so the shadow strip fits. The top,
    /// left, and right edges stay flush with the bar, so the bar still reaches
    /// the screen edges.
    static func panelFrame(for barFrame: CGRect, shadowHeight: CGFloat) -> CGRect {
        guard shadowHeight > 0 else { return barFrame }
        return CGRect(x: barFrame.minX,
                      y: barFrame.minY - shadowHeight,
                      width: barFrame.width,
                      height: barFrame.height + shadowHeight)
    }

    /// Stop any in-flight implicit animation by snapping each panel to its last
    /// target. AppKit has no public "current presentation frame" accessor, so a
    /// superseded transition is cut to its committed endpoint and the following
    /// settled reposition animates from there. The exact mid-flight visual
    /// behavior is a physical-validation item.
    private func cancelAnimations() {
        for panel in [left, right] {
            guard let target = targets[ObjectIdentifier(panel)] else { continue }
            panel.setFrame(target, display: true)
        }
    }
}

/// The panel's content view: the bar half pinned to the top with an optional
/// bottom-shadow strip below it.
///
/// A bar panel hugs the top screen edge, so a window-level shadow would rim
/// every edge — including the camera-housing gap on a notched display. Instead
/// the panel is enlarged a few points below the bar and a soft, unclipped
/// gradient fades downward, so the shadow runs strictly along the bottom edge
/// and never over the flat bar itself (#0025).
@MainActor
final class BarPanelContainer: NSView {
    /// The bar half. Its frame is the top strip; it is never resized.
    let content: NSView
    private let shadowHeight: CGFloat
    private let shadowGradient = CAGradientLayer()

    init(content: NSView, shadowHeight: CGFloat) {
        self.content = content
        self.shadowHeight = max(0, shadowHeight)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(content)
        if self.shadowHeight > 0 {
            configureShadowGradient()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BarPanelContainer does not support NSCoding")
    }

    override func layout() {
        super.layout()
        attachShadowGradientIfNeeded()
        // y-up: the bar half occupies the top and the shadow strip the bottom.
        content.frame = CGRect(x: 0, y: shadowHeight,
                               width: bounds.width,
                               height: max(0, bounds.height - shadowHeight))
        if shadowHeight > 0 {
            shadowGradient.frame = CGRect(x: 0, y: 0, width: bounds.width, height: shadowHeight)
        }
    }

    /// A drop shadow is conventionally dark regardless of the bar's theme, so
    /// this is a fixed neutral tint rather than a theme token; theme it only
    /// if the design ever calls for a coloured shadow.
    private func configureShadowGradient() {
        // Darkest right under the bar, fading to clear downward. Unit space:
        // (0, 0) is bottom-left and (1, 1) is top-right, so the strip's top
        // is the start point.
        shadowGradient.colors = [
            NSColor.black.withAlphaComponent(0.20).cgColor,
            NSColor.black.withAlphaComponent(0).cgColor
        ]
        shadowGradient.startPoint = CGPoint(x: 0.5, y: 1)
        shadowGradient.endPoint = CGPoint(x: 0.5, y: 0)
    }

    /// The backing layer can be nil in `init`; attach on layout when needed.
    private func attachShadowGradientIfNeeded() {
        guard shadowHeight > 0 else { return }
        guard let layer else { return }
        if shadowGradient.superlayer !== layer {
            configureShadowGradient()
            layer.addSublayer(shadowGradient)
        }
    }
}
