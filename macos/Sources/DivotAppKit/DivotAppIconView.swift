import AppKit
import DivotCore

/// The optional Divot mark at the start of the left group, before the
/// workspaces.
///
/// It draws the same template mark as the menu-bar item (#0019), tinted with the
/// bar's `foreground` so one asset follows both the light and dark theme, and it
/// scales with the configured icon size (#0022). A click opens Divot's own
/// settings window through the existing opener; there is no native `title`
/// tooltip — the accessible label is the only description.
@MainActor
final class DivotAppIconButton: NSButton {
    /// The spoken label. Kept in one place so a test and VoiceOver agree.
    static let accessibilityLabelText = "Open Divot settings"

    /// Called on click. The panel is nonactivating, so this is the item's whole
    /// behavior.
    var onActivate: (() -> Void)?

    private let metrics: BarMetrics
    private var theme: BarTheme

    init(metrics: BarMetrics = .default, theme: BarTheme = .systemDefault) {
        self.metrics = metrics
        self.theme = theme
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        setButtonType(.momentaryChange)
        // Reachable by keyboard (Full Keyboard Access): a real control that
        // accepts first responder, unlike the static status item views.
        refusesFirstResponder = false
        focusRingType = .default
        // No native `title` tooltip is used; the spoken label is the only
        // description.
        toolTip = nil
        target = self
        action = #selector(clicked(_:))
        setAccessibilityLabel(Self.accessibilityLabelText)
        setAccessibilityRole(.button)
        applyIcon()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("DivotAppIconButton does not support NSCoding")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: metrics.appIconSize, height: metrics.appIconSize)
    }

    /// Re-color for a new theme without re-reading the asset.
    func apply(theme: BarTheme) {
        self.theme = theme
        applyIcon()
    }

    private func applyIcon() {
        let mark = DivotMenuBarMark.image(pointSize: metrics.appIconSize)
        // The mark is already a template image; keep it explicit so the tint
        // below is what carries the theme color.
        mark?.isTemplate = true
        image = mark
        contentTintColor = theme.foreground
    }

    /// A click on an inactive panel should still open settings, not just focus
    /// the panel first (the bar never becomes key).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func clicked(_ sender: Any?) {
        onActivate?()
    }
}
