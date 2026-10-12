import AppKit
import DivotCore

/// A read-only popover that lists nearby Wi-Fi networks, anchored to the bar's
/// network item.
///
/// It owns one `WifiScanModel` and scans only when it is presented, never on a
/// timer. Closing the popover cancels an in-flight scan. The list is read-only
/// by design: there is no join, no password field, and no network configuration.
/// The last row opens the matching System Settings pane.
@MainActor
public final class WifiPopoverController {
    private let model: WifiScanModel
    private let openWifiSettings: @MainActor () -> Void
    private let openLocationSettings: @MainActor () -> Void

    private var popover: NSPopover?
    private var content: WifiPopoverContentController?
    private var scanTask: Task<Void, Never>?

    public init(scanner: any WifiNetworkScanning,
                openWifiSettings: @escaping @MainActor () -> Void,
                openLocationSettings: @escaping @MainActor () -> Void) {
        self.model = WifiScanModel(scanner: scanner)
        self.openWifiSettings = openWifiSettings
        self.openLocationSettings = openLocationSettings
    }

    /// Show the popover below `view`, then scan once off the main actor.
    public func present(relativeTo view: NSView) {
        dismiss()
        let controller = WifiPopoverContentController()
        controller.onOpenWifiSettings = { [weak self] in self?.openWifiSettings() }
        controller.onOpenLocationSettings = { [weak self] in self?.openLocationSettings() }
        controller.onRetry = { [weak self] in self?.refresh() }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = controller
        popover.contentSize = controller.preferredSize
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)

        self.popover = popover
        self.content = controller
        refresh()
    }

    /// Close the popover and cancel any in-flight scan.
    public func dismiss() {
        scanTask?.cancel()
        scanTask = nil
        popover?.performClose(nil)
        popover = nil
        content = nil
    }

    /// Whether the popover is currently shown. Exposed for tests and callers.
    public var isShown: Bool { popover?.isShown ?? false }

    private func refresh() {
        scanTask?.cancel()
        render(.scanning)
        scanTask = Task { [weak self] in
            guard let self else { return }
            let state = await self.model.scan()
            guard !Task.isCancelled else { return }
            self.render(state)
        }
    }

    private func render(_ state: WifiScanState) {
        guard let content, let popover else { return }
        content.render(state)
        popover.contentSize = content.preferredSize
    }
}

/// The popover's content: a header, a scannable body, and the settings row.
@MainActor
final class WifiPopoverContentController: NSViewController {
    var onOpenWifiSettings: (() -> Void)?
    var onOpenLocationSettings: (() -> Void)?
    var onRetry: (() -> Void)?

    private let stack = NSStackView()

    /// The size the popover should occupy for the currently rendered state.
    var preferredSize: NSSize {
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        return NSSize(width: max(272, fitting.width), height: max(1, fitting.height))
    }

    override func loadView() {
        let root = NSView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12)
        ])
        self.view = root
        render(.scanning)
    }

    /// Rebuild the body for a new scan state. The header and settings row are
    /// always present; only the body swaps.
    func render(_ state: WifiScanState) {
        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        stack.addArrangedSubview(header())
        switch state {
        case .idle, .scanning:
            stack.addArrangedSubview(message("Scanning for networks…"))
        case .networks(let networks):
            if networks.isEmpty {
                stack.addArrangedSubview(message("No networks found."))
            } else {
                for network in networks {
                    stack.addArrangedSubview(row(for: network))
                }
            }
        case .permissionDenied:
            stack.addArrangedSubview(message("Location access is needed to list nearby Wi-Fi networks. "
                                             + "Divot never reads network names without it."))
            stack.addArrangedSubview(linkButton("Open Location Services…",
                                                action: #selector(openLocationServices)))
        case .unavailable:
            stack.addArrangedSubview(message("Wi-Fi is not available on this Mac."))
        case .failed(let reason):
            stack.addArrangedSubview(message("Couldn't scan for networks. \(reason)"))
            stack.addArrangedSubview(linkButton("Try Again", action: #selector(retry)))
        }
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Wi-Fi Settings…",
                                            action: #selector(openWifiSettings)))
        stack.needsLayout = true
    }

    // MARK: - Rows

    private func header() -> NSView {
        let label = NSTextField(labelWithString: "Wi-Fi")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func message(_ text: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 248).isActive = true
        return label
    }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    private func linkButton(_ title: String, action: Selector) -> NSView {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.alignment = .left
        button.font = .systemFont(ofSize: 12)
        button.contentTintColor = .controlAccentColor
        return button
    }

    /// One network row: signal, name, a spacer, then the lock and current marks.
    private func row(for network: WifiNetwork) -> NSView {
        let signal = NSImageView()
        signal.image = Self.signalImage(level: network.signalLevel)
        signal.contentTintColor = .labelColor
        signal.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: network.ssid)
        name.font = network.isCurrent ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingMiddle
        name.maximumNumberOfLines = 1
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var views: [NSView] = [signal, name, spacer]
        if network.isCurrent {
            let check = NSImageView()
            check.image = NSImage(systemSymbolName: "checkmark.circle.fill",
                                  accessibilityDescription: "Connected")
            check.contentTintColor = .controlAccentColor
            check.setContentHuggingPriority(.required, for: .horizontal)
            views.append(check)
        }
        if network.isSecure {
            let lock = NSImageView()
            lock.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure")
            lock.contentTintColor = .secondaryLabelColor
            lock.setContentHuggingPriority(.required, for: .horizontal)
            views.append(lock)
        }

        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.staticText)
        row.setAccessibilityLabel(Self.accessibilityLabel(for: network))
        return row
    }

    private static func accessibilityLabel(for network: WifiNetwork) -> String {
        var parts = [network.ssid]
        parts.append(network.isSecure ? "secure" : "open")
        parts.append("\(network.signalLevel) of 4 bars")
        if network.isCurrent { parts.append("connected") }
        return parts.joined(separator: ", ")
    }

    /// The `wifi` symbol with its variable-strength fill. Level 0 still draws a
    /// weak glyph rather than an empty box; the row is a visible network.
    private static func signalImage(level: Int) -> NSImage? {
        let clamped = max(1, min(level, 4))
        return NSImage(systemSymbolName: "wifi",
                       variableValue: Double(clamped) / 4.0,
                       accessibilityDescription: nil)
    }

    // MARK: - Actions

    @objc private func openWifiSettings() {
        onOpenWifiSettings?()
    }

    @objc private func openLocationServices() {
        onOpenLocationSettings?()
    }

    @objc private func retry() {
        onRetry?()
    }
}
