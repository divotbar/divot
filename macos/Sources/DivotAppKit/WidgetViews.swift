import AppKit
import DivotCore

/// Renders one bar item: an optional SF Symbol plus compact text.
///
/// The view is thin. All decision-making (state → text/icon) lives in
/// `DivotCore.WidgetPresenter`, so this only draws and reports an activation.
@MainActor
final class BarItemView: NSView {
    private let iconView = NSImageView()
    private let textField = NSTextField(labelWithString: "")
    private var action: WidgetAction = .none
    var onActivate: ((WidgetAction) -> Void)?
    private let metrics: BarMetrics
    private var lastIconBundleIdentifier: String?

    init(metrics: BarMetrics = .default) {
        self.metrics = metrics
        super.init(frame: .zero)
        wantsLayer = true
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(iconView)
        textField.font = .monospacedDigitSystemFont(ofSize: metrics.textFontSize, weight: .medium)
        // Truncation is a safety net for genuinely constrained layouts, never the
        // normal case: the item is sized to the measured text so nothing clips at
        // the default width.
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.translatesAutoresizingMaskIntoConstraints = true
        addSubview(textField)
    }

    required init?(coder: NSCoder) {
        fatalError("BarItemView does not support NSCoding")
    }

    /// `presentation` is already computed by the pure presenter.
    func update(_ presentation: WidgetPresentation, action: WidgetAction) {
        self.action = action

        let image = resolveIcon(presentation)
        if let image {
            iconView.image = image
            iconView.contentTintColor = presentation.isError ? .systemRed : .labelColor
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }

        textField.stringValue = presentation.text
        textField.textColor = presentation.isError ? .systemRed : .labelColor
        textField.isHidden = presentation.text.isEmpty

        setAccessibilityRole(action == .none ? .staticText : .button)
        setAccessibilityLabel(presentation.accessibilityLabel)
        setAccessibilityHelp(action == .none ? nil : "Activates \(presentation.accessibilityLabel)")

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        let iconWidth = iconView.isHidden ? 0 : metrics.iconSize + metrics.iconSpacing
        let textWidth = measuredTextWidth
        return NSSize(width: iconWidth + textWidth,
                      height: max(metrics.iconSize, textField.fittingSize.height))
    }

    /// The width the label cell actually draws. `NSTextField.intrinsicContentSize`
    /// omits the cell's own padding, so sizing a field to it ellipsizes the tail
    /// ("Muted" → "Mut…"); `fittingSize` includes that padding, so a field sized
    /// to it is never truncated.
    private var measuredTextWidth: CGFloat {
        guard !textField.isHidden else { return 0 }
        return ceil(max(textField.fittingSize.width, textField.intrinsicContentSize.width))
    }

    /// A front-app item names its bundle; the view resolves the real
    /// application icon. Other items use their SF Symbol. The cached image is
    /// reused while the bundle identifier is unchanged.
    private func resolveIcon(_ presentation: WidgetPresentation) -> NSImage? {
        if let bundle = presentation.iconBundleIdentifier {
            if bundle == lastIconBundleIdentifier, let cached = iconView.image { return cached }
            lastIconBundleIdentifier = bundle
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        lastIconBundleIdentifier = nil
        guard let symbol = presentation.symbolName else { return nil }
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    }

    override func layout() {
        super.layout()
        var x: CGFloat = 0
        if !iconView.isHidden {
            iconView.frame = CGRect(x: 0, y: (bounds.height - metrics.iconSize) / 2,
                                    width: metrics.iconSize, height: metrics.iconSize)
            x = metrics.iconSize + metrics.iconSpacing
        }
        if !textField.isHidden {
            let size = textField.fittingSize
            textField.frame = CGRect(x: x, y: (bounds.height - size.height) / 2,
                                     width: size.width, height: size.height)
        }
    }

    // MARK: Interaction

    /// A click on an inactive panel should still activate the item, not just
    /// focus the panel first.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard action != .none else {
            super.mouseDown(with: event)
            return
        }
        onActivate?(action)
    }

    override func accessibilityPerformPress() -> Bool {
        guard action != .none else { return false }
        onActivate?(action)
        return true
    }
}

/// Arranges the item views for one side of the bar.
///
/// The left group grows from the left edge; the right group is anchored to the
/// right edge and reads left-to-right, matching the configured order. Only
/// changed items are re-rendered.
@MainActor
final class BarContentView: NSView, BarContentLifecycle {
    let side: BarSide
    private let items: [BarItemID]
    private let presentationOptions: WidgetPresentationOptions
    private var itemViews: [BarItemID: BarItemView] = [:]
    /// The `workspaces` item is a live, clickable row rather than a single
    /// value, so it renders through `WorkspaceBarView` and is not driven by the
    /// widget pipeline.
    private var workspaceViews: [BarItemID: WorkspaceBarView] = [:]
    var onActivate: ((WidgetAction) -> Void)?

    private let metrics: BarMetrics

    init(side: BarSide,
         items: [BarItemID],
         workspaceFeed: WorkspaceFeed? = nil,
         workspaceIcons: WorkspaceIconProviding? = nil,
         displayScreensID: Int? = nil,
         metrics: BarMetrics = .default,
         presentationOptions: WidgetPresentationOptions = .default,
         onActivate: ((WidgetAction) -> Void)? = nil) {
        self.side = side
        self.items = items
        self.metrics = metrics
        self.presentationOptions = presentationOptions
        self.onActivate = onActivate
        super.init(frame: .zero)
        wantsLayer = true
        for id in items {
            if id == .workspaces, let workspaceFeed, let workspaceIcons {
                let view = WorkspaceBarView(feed: workspaceFeed,
                                            icons: workspaceIcons,
                                            displayScreensID: displayScreensID,
                                            showsFrontApp: !items.contains(.frontApp),
                                            metrics: metrics)
                workspaceViews[id] = view
                addSubview(view)
                continue
            }
            let view = BarItemView(metrics: metrics)
            view.onActivate = { [weak self] action in self?.onActivate?(action) }
            itemViews[id] = view
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("BarContentView does not support NSCoding")
    }

    /// Release the workspace row's feed observer when the panel is torn down.
    func barContentDidDetach() {
        for view in workspaceViews.values { view.barContentDidDetach() }
    }

    /// Apply a batch of changes. Items not on this side are ignored, so both
    /// panels can be handed the same batch. A removal clears the item.
    func apply(_ changes: [WidgetChange]) {
        for change in changes {
            guard let view = itemViews[change.id] else { continue }
            switch change {
            case .update(let state):
                view.update(WidgetPresenter.present(id: state.id, state: state, options: presentationOptions),
                            action: WidgetActions.defaultAction(for: state.id, content: state.content))
            case .removed(let id):
                view.update(WidgetPresenter.present(id: id, state: nil, options: presentationOptions),
                            action: WidgetActions.defaultAction(for: id))
            }
        }
        needsLayout = true
    }

    /// Fill in every item before the first provider snapshot arrives, so the
    /// bar is complete (and honest about loading) from the first frame.
    func applyInitialState() {
        for id in items {
            itemViews[id]?.update(WidgetPresenter.present(id: id, state: nil, options: presentationOptions),
                                  action: WidgetActions.defaultAction(for: id))
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()

        // Keep the group inside the panel's padding so it never runs edge-to-edge
        // and the left/right groups share one rhythm.
        let inset = metrics.rowInset
        let usableWidth = max(0, bounds.width - inset * 2)

        var fixedTotal: CGFloat = 0
        var fixedCount = 0
        for id in items where itemViews[id] != nil {
            fixedTotal += itemViews[id]?.intrinsicContentSize.width ?? 0
            fixedCount += 1
        }
        let workspaceCount = items.filter { workspaceViews[$0] != nil }.count
        let totalCount = fixedCount + workspaceCount
        let spacingTotal = totalCount > 1 ? metrics.itemSpacing * CGFloat(totalCount - 1) : 0
        // The workspace row is elastic: it takes the width the fixed items leave.
        let elasticWidth = workspaceCount > 0 ? max(0, usableWidth - fixedTotal - spacingTotal) : 0
        let perWorkspace = workspaceCount > 0 ? elasticWidth / CGFloat(workspaceCount) : 0

        var x = side == .left
            ? inset
            : max(inset, bounds.width - inset - (fixedTotal + elasticWidth + spacingTotal))
        for id in items {
            if let workspace = workspaceViews[id] {
                workspace.frame = CGRect(x: x, y: 0, width: perWorkspace, height: bounds.height)
                x += perWorkspace + metrics.itemSpacing
                continue
            }
            guard let view = itemViews[id] else { continue }
            let width = view.intrinsicContentSize.width
            let height = min(bounds.height, view.intrinsicContentSize.height)
            view.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
            x += width + metrics.itemSpacing
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
