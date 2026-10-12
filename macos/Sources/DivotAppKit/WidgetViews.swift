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
    private let indicatorView = NSImageView()
    private var action: WidgetAction = .none
    var onActivate: ((WidgetAction) -> Void)?
    private let metrics: BarMetrics
    private var lastIconBundleIdentifier: String?
    private var presentation: WidgetPresentation?
    /// The SF Symbol the view last resolved for its icon. Exposed so a test can
    /// assert the symbol the bar item actually draws (e.g. the charging bolt)
    /// without reaching into AppKit's private image state.
    private(set) var displayedSymbolName: String?
    private var theme: BarTheme = .systemDefault
    private var indicatorRole: WidgetIndicator.Role?
    private var enablesChipStyle: Bool = false
    /// The chip background opacity, 0–100, matching the workspace chips so the
    /// whole bar fades together (#0052).
    private let chipOpacity: Int

    init(metrics: BarMetrics = .default, enablesChipStyle: Bool = false, chipOpacity: Int = 0) {
        self.metrics = metrics
        self.enablesChipStyle = enablesChipStyle
        self.chipOpacity = max(0, min(chipOpacity, 100))
        super.init(frame: .zero)
        wantsLayer = true
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(iconView)
        indicatorView.imageScaling = .scaleProportionallyDown
        indicatorView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(indicatorView)
        textField.font = BarFont.text(metrics)
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
        self.presentation = presentation

        let image = resolveIcon(presentation)
        displayedSymbolName = presentation.symbolName
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

        applyIndicator(presentation.indicator)

        setAccessibilityRole(action == .none ? .staticText : .button)
        setAccessibilityLabel(presentation.accessibilityLabel)
        switch action {
        case .none: setAccessibilityHelp(nil)
        case .toggleKeepAwake: setAccessibilityHelp("Toggles keep-awake")
        case .toggleAppearance: setAccessibilityHelp("Toggles appearance")
        default: setAccessibilityHelp("Activates \(presentation.accessibilityLabel)")
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    /// Re-color the text and symbol for a new theme without re-resolving content.
    func apply(theme: BarTheme) {
        self.theme = theme
        applyColors()
        if let indicatorRole {
            indicatorView.contentTintColor = indicatorColor(for: indicatorRole)
        }
        // The chip fill lives in `updateLayer`, so a theme change must ask for a
        // redraw to pick up the new `selected` color.
        needsDisplay = true
    }

    private func applyColors() {
        let isError = presentation?.isError ?? false
        let color = isError ? theme.error : theme.foreground
        iconView.contentTintColor = color
        textField.textColor = color
    }

    /// Draw (or hide) the small state indicator after the text. The color comes
    /// from the semantic role, so the same contrast-audited value the tests
    /// check is the one the bar draws.
    private func applyIndicator(_ indicator: WidgetIndicator?) {
        guard let indicator,
              let image = NSImage(systemSymbolName: indicator.symbolName, accessibilityDescription: nil) else {
            indicatorView.image = nil
            indicatorView.isHidden = true
            indicatorView.toolTip = nil
            indicatorRole = nil
            return
        }
        indicatorView.image = image
        indicatorRole = indicator.role
        indicatorView.contentTintColor = indicatorColor(for: indicator.role)
        indicatorView.isHidden = false
        // A native tooltip is the one thing AGENTS.md forbids; the state is
        // announced through the item's accessible label instead.
        indicatorView.toolTip = nil
    }

    /// The indicator tint: the audited native hex for the native family, or the
    /// theme's positive `occupied` role for a family, so the cup matches the bar.
    private func indicatorColor(for role: WidgetIndicator.Role) -> NSColor {
        theme.usesSystemColors
            ? Self.color(for: role, appearance: effectiveAppearance)
            : theme.occupied
    }

    /// Resolve a semantic indicator role against the current appearance.
    static func color(for role: WidgetIndicator.Role, appearance: NSAppearance) -> NSColor {
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(divotHex: role.hex(dark: dark)) ?? .labelColor
    }

    override var intrinsicContentSize: NSSize {
        let iconWidth = iconView.isHidden ? 0 : metrics.iconSize
        let textWidth = measuredTextWidth
        let indicatorWidth = indicatorView.isHidden ? 0 : metrics.iconSize
        var contentWidth = iconWidth + textWidth + indicatorWidth

        // Add spacing between icon and text only if both exist
        if !iconView.isHidden && textWidth > 0 {
            contentWidth += metrics.iconSpacing
        }
        // Add spacing between text and indicator only if text exists or both icon and indicator exist
        if !indicatorView.isHidden && (textWidth > 0 || !iconView.isHidden) {
            contentWidth += metrics.iconSpacing
        }

        let contentHeight = max(metrics.iconSize, textField.fittingSize.height)
        let chipPadding = enablesChipStyle ? BarMetrics.chipPadding : 0.0
        return NSSize(width: contentWidth + chipPadding * 2,
                      height: contentHeight + chipPadding * 2)
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
        let chipPadding = enablesChipStyle ? BarMetrics.chipPadding : 0.0
        var x: CGFloat = chipPadding
        if !iconView.isHidden {
            iconView.frame = CGRect(x: x, y: (bounds.height - metrics.iconSize) / 2,
                                    width: metrics.iconSize, height: metrics.iconSize)
            x += metrics.iconSize + metrics.iconSpacing
        }
        if !textField.isHidden {
            let size = textField.fittingSize
            textField.frame = CGRect(x: x, y: (bounds.height - size.height) / 2,
                                     width: size.width, height: size.height)
            x += size.width
        }
        if !indicatorView.isHidden {
            if x > chipPadding { x += metrics.iconSpacing }
            indicatorView.frame = CGRect(x: x, y: (bounds.height - metrics.iconSize) / 2,
                                         width: metrics.iconSize, height: metrics.iconSize)
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

    /// Re-resolve the indicator tint when the effective appearance changes, so
    /// the light/dark contrast-audited value follows the system.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if let role = indicatorRole {
            indicatorView.contentTintColor = indicatorColor(for: role)
        }
    }

    override var wantsUpdateLayer: Bool { enablesChipStyle }

    override func updateLayer() {
        guard enablesChipStyle else { return }
        let transparency = CGFloat(chipOpacity) / 100.0
        layer?.backgroundColor = theme.selected.withAlphaComponent(1.0 - transparency).cgColor
        layer?.cornerRadius = 4
        layer?.borderWidth = 0
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
    private var theme: BarTheme
    private var itemViews: [BarItemID: BarItemView] = [:]
    /// The `workspaces` item is a live, clickable row rather than a single
    /// value, so it renders through `WorkspaceBarView` and is not driven by the
    /// widget pipeline.
    private var workspaceViews: [BarItemID: WorkspaceBarView] = [:]
    /// The optional Divot mark at the very start of the left group. It is not a
    /// configured item; it decorates the left group and opens Divot settings.
    private var appIconButton: DivotAppIconButton?
    var onActivate: ((WidgetAction) -> Void)?

    private let metrics: BarMetrics

    init(side: BarSide,
         items: [BarItemID],
         showsAppIcon: Bool = false,
         showOccupiedDot: Bool = true,
         showEmptyDot: Bool = true,
         enablesChipStyle: Bool = false,
         chipOpacity: Int = 0,
         workspaceFeed: WorkspaceFeed? = nil,
         workspaceIcons: WorkspaceIconProviding? = nil,
         displayScreensID: Int? = nil,
         metrics: BarMetrics = .default,
         presentationOptions: WidgetPresentationOptions = .default,
         theme: BarTheme = .systemDefault,
         onActivate: ((WidgetAction) -> Void)? = nil) {
        self.side = side
        self.items = items
        self.metrics = metrics
        self.presentationOptions = presentationOptions
        self.theme = theme
        self.onActivate = onActivate
        super.init(frame: .zero)
        wantsLayer = true
        // The mark leads the left group only; the right group starts at the
        // status items.
        if side == .left, showsAppIcon {
            let button = DivotAppIconButton(metrics: metrics, theme: theme)
            button.onActivate = { [weak self] in self?.onActivate?(.openDivotSettings) }
            appIconButton = button
            addSubview(button)
        }
        for id in items {
            if id == .workspaces, let workspaceFeed, let workspaceIcons {
                let view = WorkspaceBarView(feed: workspaceFeed,
                                            icons: workspaceIcons,
                                            displayScreensID: displayScreensID,
                                            showsFrontApp: !items.contains(.frontApp),
                                            theme: theme,
                                            metrics: metrics,
                                            showOccupiedDot: showOccupiedDot,
                                            showEmptyDot: showEmptyDot,
                                            enablesChipStyle: enablesChipStyle,
                                            chipOpacity: chipOpacity)
                workspaceViews[id] = view
                addSubview(view)
                continue
            }
            let view = BarItemView(metrics: metrics, enablesChipStyle: enablesChipStyle, chipOpacity: chipOpacity)
            view.onActivate = { [weak self] action in self?.onActivate?(action) }
            view.apply(theme: theme)
            itemViews[id] = view
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("BarContentView does not support NSCoding")
    }

    /// Adopt a new theme without rebuilding the view tree.
    func apply(theme: BarTheme) {
        self.theme = theme
        appIconButton?.apply(theme: theme)
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

        // Keep the group inside the panel's padding so it never runs edge-to-edge
        // and the left/right groups share one rhythm.
        let inset = metrics.rowInset
        let usableWidth = max(0, bounds.width - inset * 2)

        // The optional app mark leads the left group, so it is part of the fixed
        // width and the gap count before the workspace row takes the remainder.
        let appIconWidth = appIconButton?.intrinsicContentSize.width ?? 0
        var fixedTotal: CGFloat = appIconWidth
        for id in items where itemViews[id] != nil {
            fixedTotal += itemViews[id]?.intrinsicContentSize.width ?? 0
        }
        let workspaceCount = items.filter { workspaceViews[$0] != nil }.count

        // Item spacing (#0054): the right group is evenly spaced at
        // `rightItemSpacing`; the left group uses `leftItemSpacing` (half the
        // right by default). On the left, the gap immediately before the
        // front-app item is a fixed `frontAppSpacing`, so the front app keeps
        // 12 pt beside the Divot mark no matter what the side sliders are set
        // to. The same rule gives the Divot-mark-to-first-item gap the left
        // value when that item is the workspaces (or any other item), which is
        // the maintainer's default.
        let sideSpacing = side == .left ? metrics.leftItemSpacing : metrics.rightItemSpacing
        func gap(before next: BarItemID?) -> CGFloat {
            side == .left && next == .frontApp ? BarMetrics.frontAppSpacing : sideSpacing
        }
        // Every slot the row lays out, in draw order, with the app mark (if any)
        // represented by `nil` because it precedes the configured items.
        var slots: [BarItemID?] = appIconButton == nil ? [] : [nil]
        slots.append(contentsOf: items.map { Optional($0) })
        var spacingTotal: CGFloat = 0
        if slots.count > 1 {
            for index in 1..<slots.count { spacingTotal += gap(before: slots[index]) }
        }
        // The workspace row is elastic: it takes the width the fixed items leave.
        let elasticWidth = workspaceCount > 0 ? max(0, usableWidth - fixedTotal - spacingTotal) : 0
        let perWorkspace = workspaceCount > 0 ? elasticWidth / CGFloat(workspaceCount) : 0

        var x = side == .left
            ? inset
            : max(inset, bounds.width - inset - (fixedTotal + elasticWidth + spacingTotal))
        if let appIconButton {
            let width = appIconButton.intrinsicContentSize.width
            let height = min(bounds.height, appIconButton.intrinsicContentSize.height)
            appIconButton.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
            x += width
            if let first = items.first { x += gap(before: first) }
        }
        for (index, id) in items.enumerated() {
            if let workspace = workspaceViews[id] {
                workspace.frame = CGRect(x: x, y: 0, width: perWorkspace, height: bounds.height)
                x += perWorkspace
            } else {
                guard let view = itemViews[id] else { continue }
                let width = view.intrinsicContentSize.width
                let height = min(bounds.height, view.intrinsicContentSize.height)
                view.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
                x += width
            }
            if index + 1 < items.count { x += gap(before: items[index + 1]) }
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        // Flat chrome (#0025): one solid fill, square corners, no bevel or
        // material blur. The only stroke left is the increased-contrast
        // accessibility border, whose width is zero by default.
        layer?.cornerRadius = 0
        layer?.backgroundColor = theme.layerBackground.cgColor
        layer?.borderWidth = theme.borderWidth
        layer?.borderColor = theme.borderColor.cgColor
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

extension NSColor {
    /// Build an sRGB color from a six-digit `#RRGGBB` string. Returns `nil` when
    /// the string is not a hex color, so a caller can fall back to a system role.
    convenience init?(divotHex: String) {
        guard let rgb = SRGBColor(hex: divotHex) else { return nil }
        self.init(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
