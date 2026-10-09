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

        if let symbol = presentation.symbolName,
           let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
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
        let iconWidth = iconView.isHidden ? 0 : iconSize + spacing
        let textWidth = textField.isHidden ? 0 : textField.intrinsicContentSize.width
        return NSSize(width: iconWidth + textWidth, height: max(iconSize, textField.intrinsicContentSize.height))
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
final class BarContentView: NSView {
    let side: BarSide
    private let items: [BarItemID]
    private var itemViews: [BarItemID: BarItemView] = [:]
    var onActivate: ((WidgetAction) -> Void)?

    private let spacing: CGFloat = 12

    init(side: BarSide, items: [BarItemID], onActivate: ((WidgetAction) -> Void)? = nil) {
        self.side = side
        self.items = items
        self.onActivate = onActivate
        super.init(frame: .zero)
        wantsLayer = true
        for id in items {
            let view = BarItemView()
            view.onActivate = { [weak self] action in self?.onActivate?(action) }
            itemViews[id] = view
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("BarContentView does not support NSCoding")
    }

    /// Apply a batch of changes. Items not on this side are ignored, so both
    /// panels can be handed the same batch. A removal clears the item.
    func apply(_ changes: [WidgetChange]) {
        for change in changes {
            guard let view = itemViews[change.id] else { continue }
            switch change {
            case .update(let state):
                view.update(WidgetPresenter.present(id: state.id, state: state),
                            action: WidgetActions.defaultAction(for: state.id, content: state.content))
            case .removed(let id):
                view.update(WidgetPresenter.present(id: id, state: nil),
                            action: WidgetActions.defaultAction(for: id))
            }
        }
        needsLayout = true
    }

    /// Fill in every item before the first provider snapshot arrives, so the
    /// bar is complete (and honest about loading) from the first frame.
    func applyInitialState() {
        for id in items {
            itemViews[id]?.update(WidgetPresenter.present(id: id, state: nil),
                                  action: WidgetActions.defaultAction(for: id))
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        var widths: [BarItemID: CGFloat] = [:]
        var total: CGFloat = 0
        for id in items {
            let width = itemViews[id]?.intrinsicContentSize.width ?? 0
            widths[id] = width
            total += width
        }
        if items.count > 1 {
            total += spacing * CGFloat(items.count - 1)
        }
        var x = side == .left ? 0 : max(0, bounds.width - total)
        for id in items {
            guard let view = itemViews[id] else { continue }
            let width = widths[id] ?? 0
            let height = min(bounds.height, view.intrinsicContentSize.height)
            view.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
            x += width + spacing
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
