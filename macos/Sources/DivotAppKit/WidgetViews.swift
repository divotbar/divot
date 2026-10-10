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

    private let iconSize: CGFloat = 14
    private let spacing: CGFloat = 5
    private var lastIconBundleIdentifier: String?
    private var presentation: WidgetPresentation?
    private var theme: BarTheme = .systemDefault

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(iconView)
        textField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.translatesAutoresizingMaskIntoConstraints = true
        addSubview(textField)
    }

    required init?(coder: NSCoder) {
        fatalError("BarItemView does not support NSCoding")
    }

    /// `presentation` is already computed by the pure presenter.
    func update(_ presentation: WidgetPresentation, action: WidgetAction) {
        self.action = action
        self.presentation = presentation

        let image = resolveIcon(presentation)
        if let image {
            iconView.image = image
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }

        textField.stringValue = presentation.text
        textField.isHidden = presentation.text.isEmpty
        applyColors()

        setAccessibilityRole(action == .none ? .staticText : .button)
        setAccessibilityLabel(presentation.accessibilityLabel)
        setAccessibilityHelp(action == .none ? nil : "Activates \(presentation.accessibilityLabel)")

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Re-color the text and symbol for a new theme without re-resolving content.
    func apply(theme: BarTheme) {
        self.theme = theme
        applyColors()
    }

    private func applyColors() {
        let isError = presentation?.isError ?? false
        let color = isError ? theme.error : theme.foreground
        iconView.contentTintColor = color
        textField.textColor = color
    }

    override var intrinsicContentSize: NSSize {
        let iconWidth = iconView.isHidden ? 0 : iconSize + spacing
        let textWidth = textField.isHidden ? 0 : textField.intrinsicContentSize.width
        return NSSize(width: iconWidth + textWidth, height: max(iconSize, textField.intrinsicContentSize.height))
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
            iconView.frame = CGRect(x: 0, y: (bounds.height - iconSize) / 2,
                                    width: iconSize, height: iconSize)
            x = iconSize + spacing
        }
        if !textField.isHidden {
            let size = textField.intrinsicContentSize
            textField.frame = CGRect(x: x, y: (bounds.height - size.height) / 2,
                                     width: max(0, bounds.width - x), height: size.height)
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
    private let padding: CGFloat
    private var theme: BarTheme
    /// The segment chrome. Native material blurs behind the bar; opaque and the
    /// reduced-transparency/increased-contrast paths hide it and fill instead.
    private let vibrancy = NSVisualEffectView()
    private var itemViews: [BarItemID: BarItemView] = [:]
    /// The `workspaces` item is a live, clickable row rather than a single
    /// value, so it renders through `WorkspaceBarView` and is not driven by the
    /// widget pipeline.
    private var workspaceViews: [BarItemID: WorkspaceBarView] = [:]
    var onActivate: ((WidgetAction) -> Void)?

    private let spacing: CGFloat = 12
    private let cornerRadius: CGFloat = 8

    init(side: BarSide,
         items: [BarItemID],
         workspaceFeed: WorkspaceFeed? = nil,
         workspaceIcons: WorkspaceIconProviding? = nil,
         displayScreensID: Int? = nil,
         presentationOptions: WidgetPresentationOptions = .default,
         padding: CGFloat = 12,
         theme: BarTheme = .systemDefault,
         onActivate: ((WidgetAction) -> Void)? = nil) {
        self.side = side
        self.items = items
        self.presentationOptions = presentationOptions
        self.padding = max(0, padding)
        self.theme = theme
        self.onActivate = onActivate
        super.init(frame: .zero)
        wantsLayer = true
        configureVibrancy()
        for id in items {
            if id == .workspaces, let workspaceFeed, let workspaceIcons {
                let view = WorkspaceBarView(feed: workspaceFeed,
                                            icons: workspaceIcons,
                                            displayScreensID: displayScreensID,
                                            showsFrontApp: !items.contains(.frontApp),
                                            theme: theme)
                workspaceViews[id] = view
                addSubview(view)
                continue
            }
            let view = BarItemView()
            view.onActivate = { [weak self] action in self?.onActivate?(action) }
            view.apply(theme: theme)
            itemViews[id] = view
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("BarContentView does not support NSCoding")
    }

    private func configureVibrancy() {
        vibrancy.material = .menu
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = cornerRadius
        vibrancy.layer?.masksToBounds = true
        addSubview(vibrancy)
    }

    /// Adopt a new theme without rebuilding the view tree.
    func apply(theme: BarTheme) {
        self.theme = theme
        for view in itemViews.values { view.apply(theme: theme) }
        for view in workspaceViews.values { view.apply(theme: theme) }
        needsDisplay = true
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
        vibrancy.frame = bounds

        let inset = padding
        let usableWidth = max(0, bounds.width - inset * 2)
        var fixedTotal: CGFloat = 0
        var fixedCount = 0
        for id in items where itemViews[id] != nil {
            fixedTotal += itemViews[id]?.intrinsicContentSize.width ?? 0
            fixedCount += 1
        }
        let workspaceCount = items.filter { workspaceViews[$0] != nil }.count
        let totalCount = fixedCount + workspaceCount
        let spacingTotal = totalCount > 1 ? spacing * CGFloat(totalCount - 1) : 0
        // The workspace row is elastic: it takes the width the fixed items leave.
        let elasticWidth = workspaceCount > 0 ? max(0, usableWidth - fixedTotal - spacingTotal) : 0
        let perWorkspace = workspaceCount > 0 ? elasticWidth / CGFloat(workspaceCount) : 0

        var x = side == .left
            ? inset
            : max(inset, bounds.width - inset - (fixedTotal + elasticWidth + spacingTotal))
        for id in items {
            if let workspace = workspaceViews[id] {
                workspace.frame = CGRect(x: x, y: 0, width: perWorkspace, height: bounds.height)
                x += perWorkspace + spacing
                continue
            }
            guard let view = itemViews[id] else { continue }
            let width = view.intrinsicContentSize.width
            let height = min(bounds.height, view.intrinsicContentSize.height)
            view.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
            x += width + spacing
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = theme.layerBackground.cgColor
        layer?.borderWidth = theme.borderWidth
        layer?.borderColor = theme.borderColor.cgColor
        vibrancy.isHidden = theme.isOpaque
    }

    /// Called when the effective appearance changes so the owning surface can
    /// recompute its theme for the new light/dark variant.
    var onEffectiveAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        onEffectiveAppearanceChange?()
    }
}
