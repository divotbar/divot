import AppKit
import DivotCore

/// A read-only popover that lists nearby Wi-Fi networks, anchored to the bar's
/// network item.
///
/// It owns one `WifiScanModel` and scans only when it is presented, never on a
/// timer. Closing the popover cancels an in-flight scan. The list is read-only
/// by design: there is no join, no password field, and no network configuration.
/// The last row opens the matching System Settings pane. The popover look and
/// lifecycle come from the shared `BarPopoverHost`.
@MainActor
public final class WifiPopoverController {
    private let model: WifiScanModel
    private let openWifiSettings: @MainActor () -> Void
    private let openLocationSettings: @MainActor () -> Void

    private let host = BarPopoverHost()
    private var content: WifiPopoverContentController?
    private var scanTask: Task<Void, Never>?

    public init(scanner: any WifiNetworkScanning,
                openWifiSettings: @escaping @MainActor () -> Void,
                openLocationSettings: @escaping @MainActor () -> Void) {
        self.model = WifiScanModel(scanner: scanner)
        self.openWifiSettings = openWifiSettings
        self.openLocationSettings = openLocationSettings
        // A `.transient` popover closes on a click outside or Escape without
        // calling `dismiss()`; cancel an in-flight scan on any close.
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Show the popover below `view`, then scan once off the main actor.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()
        let controller = WifiPopoverContentController()
        controller.theme = theme
        controller.onOpenWifiSettings = { [weak self] in self?.openWifiSettings() }
        controller.onOpenLocationSettings = { [weak self] in self?.openLocationSettings() }
        controller.onRetry = { [weak self] in self?.refresh() }

        host.present(controller, relativeTo: view)
        self.content = controller
        refresh()
    }

    /// A click on the network item. When this item already owns the open
    /// popover the click closes it; otherwise it opens the popover.
    public func toggle(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        if host.itemClickCloses(relativeTo: view) {
            dismiss()
        } else {
            present(relativeTo: view, theme: theme)
        }
    }

    /// Close the popover and cancel any in-flight scan.
    public func dismiss() {
        scanTask?.cancel()
        scanTask = nil
        host.dismiss()
        content = nil
    }

    /// Whether the popover is currently shown. Exposed for tests and callers.
    public var isShown: Bool { host.isShown }

    /// Update the shown popover's theme without closing it.
    /// Used when the bar's theme changes while the popover is open.
    public func updateTheme(_ theme: BarTheme) {
        if host.isShown {
            host.restyle(theme: theme)
        }
        if let content {
            content.theme = theme
        }
    }

    /// The popover closed for any reason; stop the scan and the rows.
    private func handleClosed() {
        scanTask?.cancel()
        scanTask = nil
        content = nil
    }

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
        guard let content else { return }
        content.render(state)
        host.resize(to: content.preferredSize)
    }
}

/// The popover's content: a header, a scannable body, and the settings row.
@MainActor
final class WifiPopoverContentController: BarPopoverContentController {
    var onOpenWifiSettings: (() -> Void)?
    var onOpenLocationSettings: (() -> Void)?
    var onRetry: (() -> Void)?

    private var lastState: WifiScanState = .scanning

    override func loadView() {
        super.loadView()
        render(.scanning)
    }

    /// Rows bake their colours in when built, so a theme change rebuilds them.
    override func restyle(_ theme: BarTheme) {
        super.restyle(theme)
        render(lastState)
    }

    /// Rebuild the body for a new scan state. The header and settings row are
    /// always present; only the body swaps.
    func render(_ state: WifiScanState) {
        lastState = state
        clearRows()
        stack.addArrangedSubview(header("Wi-Fi"))
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

    /// One network row: signal, name, a spacer, then the lock and current marks.
    private func row(for network: WifiNetwork) -> NSView {
        let signal = NSImageView()
        signal.image = Self.signalImage(level: network.signalLevel)
        signal.contentTintColor = theme.popoverPalette.label
        signal.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: network.ssid)
        name.font = network.isCurrent ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13)
        name.textColor = theme.popoverPalette.label
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
            check.contentTintColor = theme.popoverPalette.link
            check.setContentHuggingPriority(.required, for: .horizontal)
            views.append(check)
        }
        if network.isSecure {
            let lock = NSImageView()
            lock.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure")
            lock.contentTintColor = theme.popoverPalette.secondary
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
