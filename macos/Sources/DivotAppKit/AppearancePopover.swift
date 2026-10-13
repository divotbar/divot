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
    public func present(relativeTo view: NSView) {
        dismiss()
        let controller = AppearancePopoverContentController()
        controller.onModeSelected = { [weak self] mode in self?.apply(mode) }
        controller.onFamilySelected = { [weak self] family in self?.apply(family) }
        controller.onOpenDivotSettings = { [weak self] in self?.openDivotSettings() }

        host.present(controller, relativeTo: view)
        self.content = controller
        model.refresh()
        model.startObserving()
        render()
        // Give the selected radio button first responder so the arrow keys move
        // through the options as soon as the popover opens.
        controller.focusInitialResponder()
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

    private func render() {
        guard let content else { return }
        content.update(model.appearance)
        host.resize(to: content.preferredSize)
    }
}

/// The popover's content: a header, the System/Light/Dark mode choices, the
/// theme-family choices, and the settings row.
///
/// Both lists are built from the configuration enums (`Mode.allCases`,
/// `Family.allCases`) so a new family or mode appears here automatically. The
/// rows are built once and updated in place, so a selection made elsewhere is
/// reflected without rebuilding the popover.
@MainActor
final class AppearancePopoverContentController: BarPopoverContentController {
    var onModeSelected: ((AppearanceConfiguration.Mode) -> Void)?
    var onFamilySelected: ((AppearanceConfiguration.Family) -> Void)?
    var onOpenDivotSettings: (() -> Void)?

    /// The mode radio buttons, keyed by the value they select.
    private(set) var modeButtons: [AppearanceConfiguration.Mode: NSButton] = [:]
    /// The family radio buttons, keyed by the value they select.
    private(set) var familyButtons: [AppearanceConfiguration.Family: NSButton] = [:]

    override func loadView() {
        super.loadView()
        configure()
    }

    private func configure() {
        clearRows()

        stack.addArrangedSubview(header("Appearance"))
        stack.addArrangedSubview(sectionLabel("Mode"))
        var modes: [NSButton] = []
        for mode in AppearanceConfiguration.Mode.allCases {
            let button = radioButton(title: mode.displayName,
                                     accessibilityLabel: "Mode: \(mode.displayName)",
                                     action: #selector(modeChosen(_:)))
            modeButtons[mode] = button
            modes.append(button)
        }
        stack.addArrangedSubview(group(modes, accessibilityLabel: "Mode"))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionLabel("Theme"))
        var families: [NSButton] = []
        for family in AppearanceConfiguration.Family.allCases {
            let button = radioButton(title: family.displayName,
                                     accessibilityLabel: "Theme: \(family.displayName)",
                                     action: #selector(familyChosen(_:)))
            familyButtons[family] = button
            families.append(button)
        }
        stack.addArrangedSubview(group(families, accessibilityLabel: "Theme"))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Divot Settings…",
                                            action: #selector(openDivotSettings)))
        stack.needsLayout = true
    }

    /// Repaint every choice from the latest selection and announce the selected
    /// state, so the popover never shows a stale check.
    func update(_ appearance: AppearanceConfiguration) {
        for (mode, button) in modeButtons {
            applySelection(mode == appearance.mode, to: button)
        }
        for (family, button) in familyButtons {
            applySelection(family == appearance.family, to: button)
        }
    }

    /// Make the selected radio button the first responder so a keyboard user can
    /// move between choices with the arrow keys immediately.
    func focusInitialResponder() {
        let selectedMode = modeButtons.first { $0.value.state == .on }?.value
            ?? modeButtons[AppearanceConfiguration.Mode.allCases[0]]
        selectedMode?.window?.makeFirstResponder(selectedMode)
    }

    // MARK: - Building blocks

    /// A small all-caps section title above a group of choices.
    private func sectionLabel(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func radioButton(title: String,
                             accessibilityLabel: String,
                             action: Selector) -> NSButton {
        let button = NSButton(radioButtonWithTitle: title, target: self, action: action)
        button.setAccessibilityLabel(accessibilityLabel)
        return button
    }

    /// A vertical group of radio buttons, exposed to accessibility as one radio
    /// group so a keyboard/VoiceOver user hears the choices as a set.
    private func group(_ buttons: [NSButton], accessibilityLabel: String) -> NSStackView {
        let group = NSStackView(views: buttons)
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 4
        group.setAccessibilityRole(.radioGroup)
        group.setAccessibilityLabel(accessibilityLabel)
        return group
    }

    private func applySelection(_ selected: Bool, to button: NSButton) {
        button.state = selected ? .on : .off
        button.setAccessibilityValue(selected ? "Selected" : "Not selected")
    }

    /// The button's owner value from the sender, so one action serves a group.
    private func mode(for sender: NSButton) -> AppearanceConfiguration.Mode? {
        modeButtons.first { $0.value === sender }?.key
    }

    private func family(for sender: NSButton) -> AppearanceConfiguration.Family? {
        familyButtons.first { $0.value === sender }?.key
    }

    // MARK: - Actions

    @objc private func modeChosen(_ sender: NSButton) {
        guard let mode = mode(for: sender) else { return }
        onModeSelected?(mode)
    }

    @objc private func familyChosen(_ sender: NSButton) {
        guard let family = family(for: sender) else { return }
        onFamilySelected?(family)
    }

    @objc private func openDivotSettings() {
        onOpenDivotSettings?()
    }
}
