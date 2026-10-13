import AppKit
import DivotCore

/// A popover anchored to the bar's volume item that shows and changes the
/// default output device's volume and mute state.
///
/// It owns one `VolumePopoverModel`. Opening reads the output once and
/// subscribes to Core Audio property listeners — never a timer — so a keyboard
/// volume key or another app moves the slider while it is open. Closing removes
/// those listeners. The last row opens the Sound settings pane. The popover look
/// and lifecycle come from the shared `BarPopoverHost`.
@MainActor
public final class VolumePopoverController {
    private let model: VolumePopoverModel
    private let openSoundSettings: @MainActor () -> Void

    private let host = BarPopoverHost()
    private var content: VolumePopoverContentController?

    public init(control: any OutputVolumeControlling,
                openSoundSettings: @escaping @MainActor () -> Void) {
        self.model = VolumePopoverModel(control: control)
        self.openSoundSettings = openSoundSettings
        self.model.onChange = { [weak self] in self?.render() }
        // A `.transient` popover closes on a click outside or Escape without
        // calling `dismiss()`; remove the Core Audio listeners on any close.
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Show the popover below `view` and start following external changes.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()
        let controller = VolumePopoverContentController()
        controller.theme = theme
        controller.onLevelChanged = { [weak self] level in self?.applyLevel(level) }
        controller.onMuteToggled = { [weak self] muted in self?.applyMute(muted) }
        controller.onOpenSoundSettings = { [weak self] in self?.openSoundSettings() }

        host.present(controller, relativeTo: view)
        self.content = controller
        // Give the slider first responder so the arrow keys adjust it as soon
        // as the popover opens, without a tab first.
        controller.view.window?.makeFirstResponder(controller.slider)
        model.refresh()
        model.startObserving()
        render()
    }

    /// A click on the volume item. When this item already owns the open popover
    /// the click closes it; otherwise it opens the popover.
    public func toggle(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        if host.itemClickCloses(relativeTo: view) {
            dismiss()
        } else {
            present(relativeTo: view, theme: theme)
        }
    }

    /// Close the popover and remove the Core Audio listeners.
    public func dismiss() {
        model.stopObserving()
        host.dismiss()
        content = nil
    }

    /// Whether the popover is currently shown. Exposed for tests and callers.
    public var isShown: Bool { host.isShown }

    /// The popover closed for any reason; drop the listeners and the rows.
    private func handleClosed() {
        model.stopObserving()
        content = nil
    }

    private func applyLevel(_ level: Double) {
        model.setLevel(level)
        render()
    }

    private func applyMute(_ muted: Bool) {
        model.setMuted(muted)
        render()
    }

    private func render() {
        guard let content else { return }
        content.update(model.state)
        host.resize(to: content.preferredSize)
    }
}

/// The popover's content: a header, the output-volume slider with its
/// percentage, a mute toggle, a note when the output cannot be changed, and the
/// settings row.
///
/// The rows are built once and updated in place, so a live slider drag is never
/// interrupted by a rebuild (an external change calls the same `update`).
@MainActor
final class VolumePopoverContentController: BarPopoverContentController {
    var onLevelChanged: ((Double) -> Void)?
    var onMuteToggled: ((Bool) -> Void)?
    var onOpenSoundSettings: (() -> Void)?

    let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    let percentLabel = NSTextField(labelWithString: "")
    let muteButton = NSButton(checkboxWithTitle: "Mute", target: nil, action: nil)
    let statusLabel = NSTextField(wrappingLabelWithString: "")

    override func loadView() {
        super.loadView()
        configure()
    }

    private func configure() {
        clearRows()

        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.setAccessibilityLabel("Output volume")
        slider.setAccessibilityValue("0%")
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        percentLabel.alignment = .left
        percentLabel.textColor = theme.popoverPalette.label
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true

        let sliderRow = NSStackView(views: [slider, percentLabel])
        sliderRow.orientation = .horizontal
        sliderRow.alignment = .centerY
        sliderRow.spacing = 8
        sliderRow.distribution = .fill

        muteButton.target = self
        muteButton.action = #selector(muteToggled)
        muteButton.setAccessibilityLabel("Mute output")

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = theme.popoverPalette.secondary
        statusLabel.maximumNumberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 248).isActive = true

        stack.addArrangedSubview(header("Volume"))
        stack.addArrangedSubview(sliderRow)
        stack.addArrangedSubview(muteButton)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Sound Settings…",
                                            action: #selector(openSoundSettings)))
    }

    /// Repaint every control from the latest state. Handles three code paths:
    /// no output device, a settable output, and an output whose volume control
    /// is exposed but not writable.
    func update(_ snapshot: VolumeSnapshot?) {
        guard let snapshot, snapshot.hasOutputDevice else {
            slider.isEnabled = false
            muteButton.isEnabled = false
            muteButton.state = .off
            slider.doubleValue = 0
            percentLabel.stringValue = "—"
            statusLabel.stringValue = "No audio output device."
            statusLabel.isHidden = false
            slider.setAccessibilityValue("Unavailable")
            return
        }

        let percent = OutputVolume.percent(snapshot.level)
        slider.doubleValue = snapshot.level
        muteButton.state = snapshot.isMuted ? .on : .off

        if snapshot.isSettable {
            slider.isEnabled = true
            muteButton.isEnabled = true
            percentLabel.stringValue = "\(percent)%"
            statusLabel.stringValue = ""
            statusLabel.isHidden = true
            slider.setAccessibilityValue("\(percent)%")
        } else {
            // A device (some HDMI/DisplayPort outputs) reports no writable volume
            // control. The slider and mute are disabled and a short note explains
            // why, instead of offering a control that cannot move anything.
            slider.isEnabled = false
            muteButton.isEnabled = false
            percentLabel.stringValue = "—"
            statusLabel.stringValue = "This output has no settable volume. "
                + "Use the display's or device's own controls."
            statusLabel.isHidden = false
            slider.setAccessibilityValue("Unavailable")
        }
    }

    // MARK: - Actions

    @objc private func sliderChanged() {
        onLevelChanged?(slider.doubleValue)
    }

    @objc private func muteToggled() {
        onMuteToggled?(muteButton.state == .on)
    }

    @objc private func openSoundSettings() {
        onOpenSoundSettings?()
    }
}
