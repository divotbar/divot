import AppKit
import DivotCore

/// A popover anchored to the bar's appearance (moon/sun) item that sets Divot's
/// own light/dark variant and theme family.
///
/// It replaces the item's old one-click light/dark toggle: the click now opens
/// this popover. It owns one `AppearancePopoverModel`, reads the current
/// selection and subscribes to published configuration changes while it is open
/// — so a change made in the Settings window or by the file watcher is reflected
/// without reopening — and removes that subscription when it closes. Edits apply
/// immediately through the shared configuration store (atomic write, live
/// reload), the same source the Settings window uses. The last row opens Divot's
/// own Settings window, never a System Settings pane. The popover look and
/// lifecycle come from the shared `BarPopoverHost`.
@MainActor
public final class AppearancePopoverController {
    private let model: AppearancePopoverModel
    private let openDivotSettings: @MainActor () -> Void

    private let host = BarPopoverHost()
    private var content: AppearancePopoverContentController?

    public init(settings: any AppearanceSettingsControlling,
                openDivotSettings: @escaping @MainActor () -> Void) {
        self.model = AppearancePopoverModel(settings: settings)
        self.openDivotSettings = openDivotSettings
        self.model.onChange = { [weak self] in self?.render() }
        // A `.transient` popover closes on a click outside or Escape without
        // calling `dismiss()`; remove the published-change observer on any close.
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Show the popover below `view` and start following published changes.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()
        let controller = AppearancePopoverContentController()
        controller.theme = theme
        controller.onModeSelected = { [weak self] mode in self?.apply(mode) }
        controller.onFamilySelected = { [weak self] family in self?.apply(family) }
        controller.onOpenDivotSettings = { [weak self] in self?.openDivotSettings() }

        host.present(controller, relativeTo: view)
        self.content = controller
        model.refresh()
        model.startObserving()
        render()
        // Give the mode control first responder so the arrow keys move through
        // the choices as soon as the popover opens.
        controller.focusInitialResponder()
    }

    /// A click on the appearance item. When this item already owns the open
    /// popover the click closes it; otherwise it opens the popover.
    public func toggle(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        if host.itemClickCloses(relativeTo: view) {
            dismiss()
        } else {
            present(relativeTo: view, theme: theme)
        }
    }

    /// Close the popover and remove the published-change observer.
    public func dismiss() {
        model.stopObserving()
        host.dismiss()
        content = nil
    }

    /// Whether the popover is currently shown. Exposed for tests and callers.
    public var isShown: Bool { host.isShown }

    /// The popover closed for any reason; drop the observer and the rows.
    private func handleClosed() {
        model.stopObserving()
        content = nil
    }

    private func apply(_ mode: AppearanceConfiguration.Mode) {
        model.select(mode)
        render()
    }

    private func apply(_ family: AppearanceConfiguration.Family) {
        model.select(family)
        render()
    }

    /// Whether the Mac is in dark appearance right now, so a `system` mode
    /// previews the variant the bar is actually drawing.
    private var systemIsDark: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private func render() {
        guard let content else { return }
        content.update(model.appearance, systemDark: systemIsDark)
        host.resize(to: content.preferredSize)
    }
}

/// The popover's content: a header, one horizontal System/Light/Dark segmented
/// control, a vertical list of theme swatches, and the settings row.
///
/// Every choice is built from the configuration enums
/// (`AppearanceConfiguration.Mode.allCases`, `.Family.allCases`) so a new family
/// appears here automatically, and each theme's swatch is taken from the real
/// palette via `ThemeResolver.swatch` — never a hand-copied colour. The rows are
/// built once and updated in place, so a selection made elsewhere is reflected
/// without rebuilding the popover.
@MainActor
final class AppearancePopoverContentController: BarPopoverContentController {
    var onModeSelected: ((AppearanceConfiguration.Mode) -> Void)?
    var onFamilySelected: ((AppearanceConfiguration.Family) -> Void)?
    var onOpenDivotSettings: (() -> Void)?

    /// The presentation order for the mode segments, left to right.
    static let modeOrder: [AppearanceConfiguration.Mode] = [.system, .light, .dark]

    /// The horizontal System/Light/Dark control.
    let modeControl = NSSegmentedControl(labels: modeOrder.map(\.displayName),
                                         trackingMode: .selectOne,
                                         target: nil,
                                         action: nil)

    /// The theme options, keyed by the value they select.
    private(set) var familyButtons: [AppearanceConfiguration.Family: ThemeSwatchButton] = [:]
    /// The order the theme options appear in, so tests and sizing agree.
    private(set) var familyOrder: [AppearanceConfiguration.Family] = []

    /// The Appearance content is narrower than the Wi-Fi/volume floor, so let the
    /// popover hug it rather than pad a large empty area beside the choices.
    override var minimumContentWidth: CGFloat { 0 }

    override func loadView() {
        super.loadView()
        configure()
    }

    /// One theme per row for a vertical list.
    static func themeGridColumns(for count: Int) -> Int {
        1
    }

    /// Paint the swatch options from the theme too: the name in the theme's
    /// label role and the chosen ring in its contrast-safe link role, so the
    /// highlight matches the bar instead of a fixed system accent.
    override func restyle(_ theme: BarTheme) {
        super.restyle(theme)
        for button in familyButtons.values {
            button.contentTintColor = theme.popoverPalette.label
            button.highlightColor = theme.popoverPalette.link
        }
    }

    private func configure() {
        clearRows()
        configureModeControl()

        stack.addArrangedSubview(header("Appearance"))
        stack.addArrangedSubview(sectionLabel("Mode"))
        stack.addArrangedSubview(modeControl)

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionLabel("Theme"))

        familyOrder = AppearanceConfiguration.Family.allCases
        for row in themeGridRows(familyOrder) {
            stack.addArrangedSubview(row)
        }

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Divot Settings…",
                                            action: #selector(openDivotSettings)))
        stack.needsLayout = true
    }

    private func configureModeControl() {
        modeControl.target = self
        modeControl.action = #selector(modeChosen)
        modeControl.trackingMode = .selectOne
        modeControl.segmentStyle = .rounded
        modeControl.refusesFirstResponder = false
        modeControl.setAccessibilityLabel("Mode")
        modeControl.setContentHuggingPriority(.required, for: .horizontal)
    }

    /// Build one swatch option per family, each on its own row for a vertical list.
    private func themeGridRows(_ families: [AppearanceConfiguration.Family]) -> [NSView] {
        let columns = Self.themeGridColumns(for: families.count)
        var rows: [NSView] = []
        var index = 0
        while index < families.count {
            let end = min(index + columns, families.count)
            let buttons = families[index..<end].map { family -> ThemeSwatchButton in
                let button = ThemeSwatchButton(family: family,
                                               target: self,
                                               action: #selector(familyChosen(_:)))
                familyButtons[family] = button
                return button
            }
            let row = NSStackView(views: buttons)
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 6
            rows.append(row)
            index = end
        }
        return rows
    }

    /// Repaint every choice from the latest selection: the mode segment, and each
    /// theme's chosen highlight and swatch for the current variant. The swatch is
    /// redrawn from the family's own palette so a change made elsewhere shows up.
    func update(_ appearance: AppearanceConfiguration, systemDark: Bool = false) {
        let variant = appearance.mode.variant(systemDark: systemDark)
        modeControl.selectedSegment = Self.modeOrder.firstIndex(of: appearance.mode) ?? 0
        modeControl.setAccessibilityValue(appearance.mode.displayName)

        for (family, button) in familyButtons {
            let chosen = family == appearance.family
            button.isChosen = chosen
            button.setSwatch(ThemeResolver.swatch(family: family, variant: variant))
            button.setAccessibilityValue(chosen ? "Selected" : "Not selected")
        }
    }

    /// Make the mode control the first responder so a keyboard user can move
    /// through the choices with the arrow keys immediately.
    func focusInitialResponder() {
        modeControl.window?.makeFirstResponder(modeControl)
    }

    /// The mode currently drawn by the segmented control's selected segment.
    var selectedMode: AppearanceConfiguration.Mode {
        Self.modeOrder[safe: modeControl.selectedSegment] ?? Self.modeOrder[0]
    }

    // MARK: - Actions

    @objc private func modeChosen() {
        onModeSelected?(selectedMode)
    }

    @objc private func familyChosen(_ sender: NSButton) {
        guard let family = familyButtons.first(where: { $0.value === sender })?.key else { return }
        onFamilySelected?(family)
    }

    @objc private func openDivotSettings() {
        onOpenDivotSettings?()
    }
}

/// One theme option: a small swatch drawn from the family's own palette plus the
/// family name, with the current theme outlined so the choice does not rely on
/// colour alone.
@MainActor
final class ThemeSwatchButton: NSButton {
    /// The palette sample the button is currently drawing; `nil` for native.
    private(set) var swatch: ThemeSwatch?
    /// Whether this option is the current theme.
    var isChosen = false {
        didSet { needsDisplay = true }
    }
    /// The colour of the chosen outline: the theme's contrast-safe link role, so
    /// the highlight matches the bar instead of a fixed system accent.
    var highlightColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    init(family: AppearanceConfiguration.Family, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = family.displayName
        self.target = target
        self.action = action
        self.isBordered = false
        self.setButtonType(.momentaryPushIn)
        self.alignment = .center
        self.font = .systemFont(ofSize: 12)
        self.imagePosition = .imageLeading
        self.imageHugsTitle = true
        self.refusesFirstResponder = false
        self.setAccessibilityRole(.radioButton)
        self.setAccessibilityLabel("Theme: \(family.displayName)")
        self.setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("ThemeSwatchButton is created in code")
    }

    /// Add breathing room around the swatch and name so the chosen ring has
    /// somewhere to sit.
    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: base.width + 14, height: base.height + 8)
    }

    /// Draw the swatch for a palette sample, or the macOS semantic colours for
    /// the native family (which has no hex palette).
    func setSwatch(_ swatch: ThemeSwatch?) {
        self.swatch = swatch
        self.image = ThemeSwatchButton.image(for: swatch)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isChosen, let context = NSGraphicsContext.current {
            context.saveGraphicsState()
            let highlight = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                         xRadius: 7,
                                         yRadius: 7)
            highlightColor.withAlphaComponent(0.16).setFill()
            highlight.fill()
            highlightColor.setStroke()
            highlight.lineWidth = 1.5
            highlight.stroke()
            context.restoreGraphicsState()
        }
        super.draw(dirtyRect)
    }

    /// A rounded swatch: the family's background with its accent as a centred
    /// dot, so it reads at a glance in both light and dark popovers. The outline
    /// is a system separator, which strengthens automatically under the
    /// increased-contrast setting.
    static func image(for swatch: ThemeSwatch?) -> NSImage {
        let side: CGFloat = 18
        let background = swatch.map { NSColor($0.background) } ?? .windowBackgroundColor
        let accent = swatch.map { NSColor($0.accent) } ?? .controlAccentColor
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let outer = NSBezierPath(roundedRect: NSRect(x: 0.75, y: 0.75,
                                                         width: side - 1.5, height: side - 1.5),
                                     xRadius: 4,
                                     yRadius: 4)
            background.setFill()
            outer.fill()
            NSColor.separatorColor.setStroke()
            outer.lineWidth = 1
            outer.stroke()

            let dot = side * 0.4
            let dotRect = NSRect(x: (side - dot) / 2,
                                 y: (side - dot) / 2,
                                 width: dot,
                                 height: dot)
            accent.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
