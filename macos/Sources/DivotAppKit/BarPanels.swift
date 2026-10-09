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
    }

    public let id: DisplayBarID
    private let left: NonActivatingPanel
    private let right: NonActivatingPanel
    private let leftContent: BarContentView
    private let rightContent: BarContentView
    private var targets: [ObjectIdentifier: CGRect] = [:]

    public init(id: DisplayBarID,
                on screen: CGRect,
                layout: BarLayout = .default,
                workspaceFeed: WorkspaceFeed? = nil,
                workspaceIcons: WorkspaceIconProviding? = nil,
                displayScreensID: Int? = nil,
                onWidgetAction: ((WidgetAction) -> Void)? = nil) {
        self.id = id
        self.leftContent = BarContentView(side: .left,
                                          items: layout.left,
                                          workspaceFeed: workspaceFeed,
                                          workspaceIcons: workspaceIcons,
                                          displayScreensID: displayScreensID,
                                          onActivate: onWidgetAction)
        self.rightContent = BarContentView(side: .right,
                                           items: layout.right,
                                           onActivate: onWidgetAction)
        self.left = Self.makePanel(on: screen, content: leftContent)
        self.right = Self.makePanel(on: screen, content: rightContent)
        leftContent.applyInitialState()
        rightContent.applyInitialState()
        left.orderFrontRegardless()
        right.orderFrontRegardless()
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
