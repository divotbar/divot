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
    /// Called after a restyle so the app can drop appearance-dependent caches.
    public var onThemeChanged: (() -> Void)?

    public init(id: DisplayBarID,
                on screen: CGRect,
                configuration: DivotConfiguration = .default,
                workspaceFeed: WorkspaceFeed? = nil,
                workspaceIcons: WorkspaceIconProviding? = nil,
                displayScreensID: Int? = nil,
                onWidgetAction: ((WidgetAction) -> Void)? = nil) {
        self.id = id
        self.configuration = configuration
        let layout = configuration.barLayout
        let theme = Self.currentTheme(for: configuration)
        self.leftContent = BarContentView(side: .left,
                                          items: layout.left,
                                          workspaceFeed: workspaceFeed,
                                          workspaceIcons: workspaceIcons,
                                          displayScreensID: displayScreensID,
                                          metrics: configuration.barMetrics,
                                          presentationOptions: configuration.presentationOptions,
                                          theme: theme,
                                          onActivate: onWidgetAction)
        self.rightContent = BarContentView(side: .right,
                                           items: layout.right,
                                           metrics: configuration.barMetrics,
                                           presentationOptions: configuration.presentationOptions,
                                           theme: theme,
                                           onActivate: onWidgetAction)
        self.left = Self.makePanel(on: screen, content: leftContent)
        self.right = Self.makePanel(on: screen, content: rightContent)
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
        move(left, to: placement.geometry.left, animated: animate)
        move(right, to: placement.geometry.right, animated: animate)
    }

    public func apply(widgetChanges: [WidgetChange]) {
        leftContent.apply(widgetChanges)
        rightContent.apply(widgetChanges)
    }

    public func close() {
        (left.contentView as? BarContentLifecycle)?.barContentDidDetach()
        (right.contentView as? BarContentLifecycle)?.barContentDidDetach()
        left.orderOut(nil)
        right.orderOut(nil)
        left.close()
        right.close()
    }

    private static func makePanel(on screen: CGRect, content: NSView) -> NonActivatingPanel {
        let panel = NonActivatingPanel(contentRect: CGRect(x: screen.minX, y: screen.maxY, width: 1, height: 1),
                                       styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered,
                                       defer: false)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Just under the system menu bar, so native menus still open above
        // Divot. Spatial placement already avoids overlap on notch-free
        // displays; this keeps the native bar on top in the unresolved notched
        // case. Final level/collection choices are physical-validation items.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = content
        return panel
    }

    private func move(_ panel: NSPanel, to frame: CGRect, animated: Bool) {
        targets[ObjectIdentifier(panel)] = frame
        guard animated else {
            panel.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
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
