import AppKit
import DivotCore

/// Resolves the SF Symbol the battery, network and volume items draw (#0057).
///
/// The three symbols use the bar's native-matching symbol size, so the bar and
/// the packaged-app report resolve the same image instead of duplicating the
/// `NSImage.SymbolConfiguration` call.
public enum NativeStatusSymbol {
    public static func image(symbolName: String, metrics: BarMetrics) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: metrics.statusSymbolPointSize,
                                                        weight: .regular)
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
}

/// Renders one bar item: an optional SF Symbol plus compact text.
///
/// The view is thin. All decision-making (state → text/icon) lives in
/// `DivotCore.WidgetPresenter`, so this only draws and reports an activation.
@MainActor
final class BarItemView: NSView {
    private let iconView = NSImageView()
    private let textField = NSTextField(labelWithString: "")
    private let indicatorView = NSImageView()
    /// The symbol drawn over the leading icon (the charging bolt, #0058).
    private let badgeView = NSImageView()
    private var action: WidgetAction = .none
    var onActivate: ((WidgetAction) -> Void)?
    private let metrics: BarMetrics
    /// True for the battery, network and volume items: their SF Symbol is drawn
    /// at the native menu-bar point size and occupies the symbol's own box, not
    /// the square status-icon box (#0057).
    private let usesNativeSymbolBox: Bool
    private var lastIconBundleIdentifier: String?
    private var presentation: WidgetPresentation?
    /// The SF Symbol the view last resolved for its icon. Exposed so a test can
    /// assert the symbol the bar item actually draws (e.g. the charging bolt)
    /// without reaching into AppKit's private image state.
    private(set) var displayedSymbolName: String?
    private var theme: BarTheme = .systemDefault
    private var indicatorRole: WidgetIndicator.Role?
    private var enablesChipStyle: Bool = false
    /// The SF Symbol the indicator view currently draws, or `nil` when no
    /// indicator is shown. Exposed so a test can prove the keep-awake cup is the
    /// only state mark the battery item adds (and that no stray dot is drawn).
    private(set) var displayedIndicatorSymbolName: String?
    /// Whether the state indicator (the keep-awake cup) is currently drawn.
    var isIndicatorVisible: Bool { !indicatorView.isHidden }
    /// The SF Symbol the badge view currently draws, or `nil` when no badge is
    /// shown. Exposed so a test can prove the charging bolt is a separate
    /// element from the battery outline (#0058).
    private(set) var displayedBadgeSymbolName: String?
    /// Whether the badge (the charging bolt) is currently drawn.
    var isBadgeVisible: Bool { !badgeView.isHidden }
    /// The tint the badge draws with, or `nil` when no badge is shown. Lets a
    /// test prove the charging mark uses the fixed charging green, not the theme
    /// accent (#0074).
    var badgeTintColor: NSColor? { badgeView.isHidden ? nil : badgeView.contentTintColor }
    /// The tint the leading icon draws with, so a test can prove the whole
    /// battery symbol takes the fixed charging green while charging (#0074).
    var iconTintColor: NSColor { iconView.contentTintColor ?? .labelColor }
    /// The text colour, so the label is proven to keep the foreground colour and
    /// not turn charging green (#0074).
    var itemTextColor: NSColor { textField.textColor ?? .labelColor }
    /// The semantic role of the badge currently drawn, or `nil` with no badge.
    private var badgeRole: WidgetBadge.Role?
    /// The chip background opacity, 0–100, matching the workspace chips so the
    /// whole bar fades together (#0052).
    private let chipOpacity: Int

    init(metrics: BarMetrics = .default,
         item: BarItemID? = nil,
         enablesChipStyle: Bool = false,
         chipOpacity: Int = 0) {
        self.metrics = metrics
        self.usesNativeSymbolBox = item?.drawsNativeStatusSymbol ?? false
        self.enablesChipStyle = enablesChipStyle
        self.chipOpacity = max(0, min(chipOpacity, 100))
        super.init(frame: .zero)
        wantsLayer = true
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(iconView)
        // The badge draws over the leading icon, so it must sit above it in the
        // subview order but below the text and the trailing indicator (#0058).
        badgeView.imageScaling = .scaleProportionallyDown
        badgeView.translatesAutoresizingMaskIntoConstraints = true
        badgeView.isHidden = true
        addSubview(badgeView)
        indicatorView.imageScaling = .scaleProportionallyDown
        indicatorView.translatesAutoresizingMaskIntoConstraints = true
        // A plain image only: no AppKit bezel, frame, or selection chrome can
        // draw a second mark around the keep-awake cup (#0051).
        indicatorView.imageFrameStyle = .none
        indicatorView.isEditable = false
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
        applyBadge(presentation.badge)

        setAccessibilityRole(action == .none ? .staticText : .button)
        setAccessibilityLabel(presentation.accessibilityLabel)
        switch action {
        case .none: setAccessibilityHelp(nil)
        case .toggleKeepAwake: setAccessibilityHelp("Toggles keep-awake")
        case .toggleAppearance: setAccessibilityHelp("Opens appearance options")
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
        if let badgeRole {
            badgeView.contentTintColor = badgeColor(for: badgeRole)
        }
        // The chip fill lives in `updateLayer`, so a theme change must ask for a
        // redraw to pick up the new `selected` color.
        needsDisplay = true
    }

    private func applyColors() {
        let isError = presentation?.isError ?? false
        let charging = presentation?.badge?.role == .charging
        let color = isError ? theme.error : theme.foreground
        // While charging the whole battery symbol draws in the fixed charging
        // green, not just the bolt: the larger mark is what makes charging
        // unmistakable on every family (#0074). The label stays the foreground
        // colour, and with no charge the icon keeps the normal colour.
        iconView.contentTintColor = charging ? badgeColor(for: .charging) : color
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
            displayedIndicatorSymbolName = nil
            return
        }
        indicatorView.image = image
        indicatorRole = indicator.role
        displayedIndicatorSymbolName = indicator.symbolName
        indicatorView.contentTintColor = indicatorColor(for: indicator.role)
        indicatorView.isHidden = false
        // A native tooltip is the one thing AGENTS.md forbids; the state is
        // announced through the item's accessible label instead.
        indicatorView.toolTip = nil
    }

    /// Draw (or hide) the symbol that sits over the leading icon. The charging
    /// bolt and the battery symbol both draw in the one fixed charging green, so
    /// the whole icon is the green mark and it never follows the theme accent
    /// (#0074).
    private func applyBadge(_ badge: WidgetBadge?) {
        guard let badge,
              let image = NSImage(systemSymbolName: badge.symbolName, accessibilityDescription: nil) else {
            badgeView.image = nil
            badgeView.isHidden = true
            displayedBadgeSymbolName = nil
            badgeRole = nil
            return
        }
        badgeView.image = image
        badgeRole = badge.role
        badgeView.contentTintColor = badgeColor(for: badge.role)
        badgeView.isHidden = false
        displayedBadgeSymbolName = badge.symbolName
    }

    /// The badge tint: the one fixed charging green (#0074), never the theme
    /// accent. The same value the contrast audit checks is the one the bar draws.
    private func badgeColor(for role: WidgetBadge.Role) -> NSColor {
        switch role {
        case .charging: return NSColor(ChargingIndicatorPalette.green)
        }
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
        let icon = leadingIconSize
        let iconWidth = iconView.isHidden ? 0 : icon.width
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

        // The native-symbol box (#0057) can be taller than the status-icon
        // square, so the row content must clear the tallest of the icon, the
        // status icon and the label (#0057).
        let contentHeight = max(icon.height, max(metrics.iconSize, textField.fittingSize.height))
        // The chip chrome pads every side through the one shared metric, so a
        // right-side chip and the selected workspace chip are the same size
        // (#0059).
        guard enablesChipStyle else { return NSSize(width: contentWidth, height: contentHeight) }
        let chip = metrics.chipSize(contentWidth: contentWidth, contentHeight: contentHeight)
        return NSSize(width: chip.width, height: chip.height)
    }

    /// The box the leading icon draws in. The battery, network and volume
    /// symbols (#0057) use the symbol's own size, so a wide battery or a tall
    /// Wi-Fi glyph is not squeezed into the square status-icon box; every other
    /// icon keeps that square.
    private var leadingIconSize: NSSize {
        guard !iconView.isHidden else { return NSSize(width: 0, height: 0) }
        if usesNativeSymbolBox,
           let image = iconView.image,
           image.size.width > 0, image.size.height > 0 {
            return image.size
        }
        return NSSize(width: metrics.iconSize, height: metrics.iconSize)
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
        guard usesNativeSymbolBox else {
            return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        // The battery, network and volume symbols are drawn at the bar's icon
        // size (#0057), so they read at the same size as the native menu bar
        // and scale with the text-size setting.
        return NativeStatusSymbol.image(symbolName: symbol, metrics: metrics)
    }

    override func layout() {
        super.layout()
        let chipPadding = enablesChipStyle ? BarMetrics.chipPadding : 0.0
        var x: CGFloat = chipPadding
        if !iconView.isHidden {
            let icon = leadingIconSize
            iconView.frame = CGRect(x: x, y: (bounds.height - icon.height) / 2,
                                    width: icon.width, height: icon.height)
            x += icon.width + metrics.iconSpacing
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
        // The badge overlaps the leading icon, so the battery keeps its box and
        // the bolt is centred on top of it rather than widening the item.
        if !badgeView.isHidden, !iconView.isHidden {
            badgeView.frame = iconView.frame
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
        if let badgeRole {
            badgeView.contentTintColor = badgeColor(for: badgeRole)
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
    /// The shared Wi-Fi popover. When present, the network item opens it instead
    /// of jumping straight to System Settings; the popover's last row opens the
    /// pane. `nil` in tests and in any surface without a scanner, where the item
    /// keeps its original settings-pane action.
    private let wifiPopover: WifiPopoverController?
    /// The shared output-volume popover. When present, the volume item opens it
    /// instead of jumping straight to System Settings; the popover's last row
    /// opens the Sound pane. `nil` in tests, where the item keeps its original
    /// settings-pane action.
    private let volumePopover: VolumePopoverController?
    /// The shared appearance popover. When present, the appearance (moon) item
    /// opens it instead of toggling light/dark directly; the popover sets the
    /// mode and the theme family and its last row opens Divot settings. `nil` in
    /// tests, where the item keeps its original one-click toggle.
    private let appearancePopover: AppearancePopoverController?

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
         wifiPopover: WifiPopoverController? = nil,
         volumePopover: VolumePopoverController? = nil,
         appearancePopover: AppearancePopoverController? = nil,
         onActivate: ((WidgetAction) -> Void)? = nil) {
        self.side = side
        self.items = items
        self.metrics = metrics
        self.presentationOptions = presentationOptions
        self.theme = theme
        self.wifiPopover = wifiPopover
        self.volumePopover = volumePopover
        self.appearancePopover = appearancePopover
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
            let view = BarItemView(metrics: metrics, item: id, enablesChipStyle: enablesChipStyle, chipOpacity: chipOpacity)
            view.onActivate = { [weak self, weak view] action in
                guard let self else { return }
                // The network item opens the read-only Wi-Fi popover when one is
                // configured; the popover's last row reaches the settings pane.
                if case .openSettings(.network) = action, let view, let wifiPopover = self.wifiPopover {
                    wifiPopover.present(relativeTo: view)
                    return
                }
                // The volume item opens the output-volume popover when one is
                // configured; the popover's last row reaches the Sound pane.
                if case .openSettings(.sound) = action, let view, let volumePopover = self.volumePopover {
                    volumePopover.present(relativeTo: view)
                    return
                }
                // The appearance (moon) item opens the appearance popover when
                // one is configured; it sets the mode and family and its last
                // row opens Divot's own settings window.
                if case .toggleAppearance = action, let view, let appearancePopover = self.appearancePopover {
                    appearancePopover.present(relativeTo: view)
                    return
                }
                self.onActivate?(action)
            }
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
        // and the left/right groups share one rhythm. The right group leaves the
        // fixed `rightEdgeInset` at the screen edge instead, so the camera-in-use
        // indicator never overlaps the rightmost item (#0060).
        let leadingInset = metrics.rowInset
        let trailingInset = side == .right ? BarMetrics.rightEdgeInset : metrics.rowInset
        let usableWidth = max(0, bounds.width - leadingInset - trailingInset)

        // The optional app mark leads the left group, so it is part of the fixed
        // width and the gap count before the workspace row takes the remainder.
        let appIconWidth = appIconButton?.intrinsicContentSize.width ?? 0
        var fixedTotal: CGFloat = appIconWidth
        for id in items where itemViews[id] != nil {
            fixedTotal += itemViews[id]?.intrinsicContentSize.width ?? 0
        }
        let workspaceCount = items.filter { workspaceViews[$0] != nil }.count

        // Item spacing (#0060): every gap in a group uses the side's spacing
        // (8 pt by default), restoring the pre-#0054 uniform rhythm. #0054's
        // per-side split and fixed front-app gap are gone, so the front app no
        // longer sits 12 pt away.
        let sideSpacing = side == .left ? metrics.leftItemSpacing : metrics.rightItemSpacing
        // Every slot the row lays out, in draw order, with the app mark (if any)
        // represented by `nil` because it precedes the configured items.
        var slots: [BarItemID?] = appIconButton == nil ? [] : [nil]
        slots.append(contentsOf: items.map { Optional($0) })
        let spacingTotal = slots.count > 1 ? sideSpacing * CGFloat(slots.count - 1) : 0
        // The workspace row is elastic: it takes the width the fixed items leave.
        let elasticWidth = workspaceCount > 0 ? max(0, usableWidth - fixedTotal - spacingTotal) : 0
        let perWorkspace = workspaceCount > 0 ? elasticWidth / CGFloat(workspaceCount) : 0

        var x = side == .left
            ? leadingInset
            : max(leadingInset, bounds.width - trailingInset - (fixedTotal + elasticWidth + spacingTotal))
        if let appIconButton {
            let width = appIconButton.intrinsicContentSize.width
            let height = min(bounds.height, appIconButton.intrinsicContentSize.height)
            appIconButton.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
            x += width + sideSpacing
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
            if index + 1 < items.count { x += sideSpacing }
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
