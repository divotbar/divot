import AppKit
import DivotCore

/// A popover that lists nearby Wi-Fi networks and joins them, anchored to the
/// bar's network item.
///
/// It owns one `WifiScanModel` and scans only when it is presented, never on a
/// timer. Opening paints the last completed scan at once when it finished
/// within the last 10 minutes ("Updated Xs ago") and always runs a live scan
/// in the background, updating the list in place. Closing the popover cancels
/// an in-flight scan or connect. Each in-range row is a button: clicking it
/// associates with that network, showing "Connecting…" then the new current
/// network or the macOS error. A secured network with no password yet asks
/// for one through a Divot-styled dialog holding an `NSSecureTextField`; the
/// password is passed only to the connector and never persisted or logged.
/// Networks Divot joined itself appear in a separate "Previously joined"
/// section (system saved profiles are never listed). The last row opens the
/// matching System Settings pane. The popover look and lifecycle come from
/// the shared `BarPopoverHost`.
@MainActor
public final class WifiPopoverController {
    private let model: WifiScanModel
    private let connector: any WifiNetworkConnecting
    private let joinStore: any WifiJoinHistoryStoring
    private let passwordProvider: (@MainActor (String) async -> String?)?
    private let openWifiSettings: @MainActor () -> Void
    private let openLocationSettings: @MainActor () -> Void

    private let host: BarPopoverHost
    private var content: WifiPopoverContentController?
    private var scanTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?

    private var networks: [WifiNetwork] = []
    private var isScanning = false
    private var cacheSummary: String?
    private var connectingSSID: String?
    private var notice: String?
    private var recentJoins: [WifiJoinedNetwork] = []

    private var openStartedAt: Date?
    /// Open-to-first-list-shown, set when the popover first paints a list
    /// (cached or live). Exposed so the task records measured in-app timing.
    public private(set) var firstPaintInterval: TimeInterval?
    /// Open-to-live-list-shown, set when the background scan settles.
    public private(set) var liveListInterval: TimeInterval?

    public init(scanner: any WifiNetworkScanning,
                connector: any WifiNetworkConnecting = CoreWLANWifiConnector(),
                joinStore: any WifiJoinHistoryStoring = FileWifiJoinHistoryStore(),
                passwordProvider: (@MainActor (String) async -> String?)? = nil,
                openWifiSettings: @escaping @MainActor () -> Void,
                openLocationSettings: @escaping @MainActor () -> Void,
                presenter: any WindowPresenting = SystemWindowPresenter()) {
        self.model = WifiScanModel(scanner: scanner)
        self.connector = connector
        self.joinStore = joinStore
        self.passwordProvider = passwordProvider
        self.openWifiSettings = openWifiSettings
        self.openLocationSettings = openLocationSettings
        self.host = BarPopoverHost(presenter: presenter)
        // A `.transient` popover closes on a click outside or Escape without
        // calling `dismiss()`; cancel an in-flight scan or connect on any close.
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// The cached rows the next open paints at once, when fresh. Exposed for
    /// tests that assert the immediate first paint without a window server.
    var cachedNetworksIfFresh: (networks: [WifiNetwork], summary: String)? {
        model.cachedNetworksIfFresh()
    }

    /// The shown content, exposed for tests that click rows windowlessly.
    var contentForTesting: WifiPopoverContentController? { content }

    /// Test seam: the same controller behind an injected host, so windowless
    /// tests never touch the event stream or the window server (#0091).
    init(scanner: any WifiNetworkScanning,
         connector: any WifiNetworkConnecting,
         joinStore: any WifiJoinHistoryStoring,
         passwordProvider: (@MainActor (String) async -> String?)?,
         openWifiSettings: @escaping @MainActor () -> Void,
         openLocationSettings: @escaping @MainActor () -> Void,
         testingHost host: BarPopoverHost) {
        self.model = WifiScanModel(scanner: scanner)
        self.connector = connector
        self.joinStore = joinStore
        self.passwordProvider = passwordProvider
        self.openWifiSettings = openWifiSettings
        self.openLocationSettings = openLocationSettings
        self.host = host
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Show the popover below `view`: paint the fresh cache at once when there
    /// is one, then scan live in the background and update in place.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()
        openStartedAt = Date()
        firstPaintInterval = nil
        liveListInterval = nil
        recentJoins = joinStore.load()
        let controller = WifiPopoverContentController()
        controller.theme = theme
        controller.onOpenWifiSettings = { [weak self] in self?.openWifiSettings() }
        controller.onOpenLocationSettings = { [weak self] in self?.openLocationSettings() }
        controller.onRetry = { [weak self] in self?.refresh() }
        controller.onSelect = { [weak self] network in self?.select(network) }

        host.present(controller, relativeTo: view)
        self.content = controller
        paintCachedThenScan()
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

    /// Close the popover and cancel any in-flight scan or connect.
    public func dismiss() {
        scanTask?.cancel()
        scanTask = nil
        connectTask?.cancel()
        connectTask = nil
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

    /// The popover closed for any reason; stop the scan, the connect, and rows.
    private func handleClosed() {
        scanTask?.cancel()
        scanTask = nil
        connectTask?.cancel()
        connectTask = nil
        content = nil
    }

    /// Paint the fresh cache at once when there is one (recording the
    /// open-to-first-paint timing), then always run the live scan in the
    /// background and update the list in place when it settles.
    private func paintCachedThenScan() {
        scanTask?.cancel()
        isScanning = true
        connectingSSID = nil
        notice = nil
        if let cached = model.cachedNetworksIfFresh() {
            networks = cached.networks
            cacheSummary = cached.summary
            if let openStartedAt { firstPaintInterval = Date().timeIntervalSince(openStartedAt) }
        } else {
            networks = []
            cacheSummary = nil
        }
        renderCurrent()
        scanTask = Task { [weak self] in
            guard let self else { return }
            let state = await self.model.scan()
            guard !Task.isCancelled else { return }
            self.applyScanned(state)
        }
    }

    private func refresh() {
        guard content != nil else { return }
        notice = nil
        isScanning = true
        renderCurrent()
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            let state = await self.model.scan()
            guard !Task.isCancelled else { return }
            self.applyScanned(state)
        }
    }

    /// Settle the background scan: replace the list in place on success (the
    /// cached rows stay visible until now), or show the failure while keeping
    /// the cached rows when there are any.
    private func applyScanned(_ state: WifiScanState) {
        isScanning = false
        switch state {
        case .networks(let found):
            networks = found
            cacheSummary = model.lastCompleted.map { $0.ageSummary() }
            notice = nil
            if let openStartedAt {
                let elapsed = Date().timeIntervalSince(openStartedAt)
                liveListInterval = elapsed
                if firstPaintInterval == nil { firstPaintInterval = elapsed }
            }
            renderCurrent()
        case .permissionDenied, .unavailable, .failed:
            // A cached list outlives a failed rescan: keep the rows and note
            // the failure instead of blanking the popover.
            if networks.isEmpty {
                render(state)
            } else {
                if case .failed(let reason) = state { notice = reason }
                if let openStartedAt, liveListInterval == nil {
                    liveListInterval = Date().timeIntervalSince(openStartedAt)
                }
                renderCurrent()
            }
        case .idle, .scanning:
            renderCurrent()
        }
    }

    /// A click on an in-range row: associate with that network, showing
    /// "Connecting…" until macOS answers. Serialized: taps while a connect is
    /// in flight are ignored.
    private func select(_ network: WifiNetwork) {
        guard connectingSSID == nil, content != nil else { return }
        connectingSSID = network.ssid
        notice = nil
        renderCurrent()
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            guard let self else { return }
            await self.connect(network: network, password: nil)
        }
    }

    private func connect(network: WifiNetwork, password: String?) async {
        let outcome = await connector.connect(ssid: network.ssid,
                                              isSecure: network.isSecure,
                                              password: password)
        guard !Task.isCancelled else { return }
        switch outcome {
        case .connected(let ssid):
            connectingSSID = nil
            notice = nil
            recentJoins = WifiJoinHistory.recorded(recentJoins, ssid: ssid)
            joinStore.save(recentJoins)
            model.markCurrent(ssid: ssid)
            networks = networks.map {
                WifiNetwork(ssid: $0.ssid, rssi: $0.rssi,
                            isSecure: $0.isSecure, isCurrent: $0.ssid == ssid)
            }
            // A network that connected but was not in the scanned list (a
            // hidden join completing late) still appears, marked current.
            if !networks.contains(where: { $0.ssid == ssid }) {
                networks.insert(WifiNetwork(ssid: ssid, rssi: -50,
                                            isSecure: network.isSecure, isCurrent: true), at: 0)
            }
            renderCurrent()
        case .requiresPassword:
            let entered = await requestPassword(for: network.ssid)
            guard !Task.isCancelled else { return }
            guard let entered else {
                // The dialog was cancelled: back to the list, no error.
                connectingSSID = nil
                renderCurrent()
                return
            }
            // `entered` lives only in this call chain: it is passed to the
            // connector and never stored or logged.
            await connect(network: network, password: entered)
        case .failed(let reason):
            connectingSSID = nil
            notice = "Couldn't join “\(network.ssid)”. \(reason)"
            renderCurrent()
        }
    }

    /// Ask for the network's password through the injected provider (tests) or
    /// the Divot-styled dialog (production). The result is never stored.
    private func requestPassword(for ssid: String) async -> String? {
        if let passwordProvider {
            return await passwordProvider(ssid)
        }
        return await WifiPasswordPrompt.prompt(ssid: ssid)
    }

    private func renderCurrent() {
        let inRange = Set(networks.map(\.ssid))
        let previous = WifiJoinHistory.recent(recentJoins, excludingInRange: inRange)
        guard let content else { return }
        content.renderList(networks: networks,
                           isScanning: isScanning,
                           cacheSummary: cacheSummary,
                           connectingSSID: connectingSSID,
                           notice: notice,
                           recentJoins: previous)
        host.resize(to: content.preferredSize)
    }

    private func render(_ state: WifiScanState) {
        guard let content else { return }
        content.render(state)
        host.resize(to: content.preferredSize)
    }
}

/// The scrollable list of nearby Wi-Fi networks. It fits its content up to a
/// maximum of 90% of the screen height and scrolls beyond that, so a long list
/// of networks cannot grow the popover without bound (the header and the
/// settings link stay on screen).
@MainActor
final class WifiNetworkListView: NSView {
    /// The fraction of the screen height the list may occupy before scrolling.
    static let maximumHeightFraction: CGFloat = 0.9
    private static let rowSpacing: CGFloat = 6

    /// Test seam: pins the screen height the cap is computed from. `nil` (the
    /// default) uses the list's own window screen, then the main screen; when no
    /// screen is known (a headless run) the list is left uncapped.
    var screenHeightOverride: CGFloat?

    private let scrollView = NSScrollView()
    private let rows = PopoverRowStack()
    private var heightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        // Draw nothing of its own; the popover's solid fill shows through, and no
        // vibrancy material is introduced (#0083).
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = Self.rowSpacing
        rows.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = rows
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rows.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            rows.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("created in code") }

    /// Replace the rows and size to fit the content, clamped to the screen cap.
    func setRows(_ newRows: [NSView]) {
        for view in rows.arrangedSubviews {
            rows.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for view in newRows {
            rows.addArrangedSubview(view)
        }
        rows.layoutSubtreeIfNeeded()

        let spacing = Self.rowSpacing
        let heights = newRows.map { $0.fittingSize.height }
        let total = heights.reduce(0, +) + spacing * CGFloat(max(0, newRows.count - 1))
        setHeight(min(total, maximumHeight ?? total))
    }

    /// The height the list is currently pinned to. Exposed for tests that assert
    /// the screen cap without depending on a laid-out frame.
    var cappedHeight: CGFloat { heightConstraint?.constant ?? 0 }

    /// 90% of the screen the list is shown on, or `nil` when no screen is known
    /// (a headless run), which leaves the list uncapped.
    private var maximumHeight: CGFloat? {
        let screenHeight = screenHeightOverride
            ?? window?.screen?.frame.height
            ?? NSScreen.main?.frame.height
        guard let screenHeight else { return nil }
        return screenHeight * Self.maximumHeightFraction
    }

    private func setHeight(_ height: CGFloat) {
        heightConstraint?.isActive = false
        let constraint = heightAnchor.constraint(equalToConstant: max(1, height))
        constraint.isActive = true
        heightConstraint = constraint
    }
}

/// The popover's content: a header, a scannable body, and the settings row.
@MainActor
final class WifiPopoverContentController: BarPopoverContentController {
    var onOpenWifiSettings: (() -> Void)?
    var onOpenLocationSettings: (() -> Void)?
    var onRetry: (() -> Void)?
    var onSelect: ((WifiNetwork) -> Void)?

    /// The last list render, so a theme change rebuilds the same rows.
    private var lastList = WifiPopoverListRender()
    /// The last non-list state, so a theme change rebuilds the message it
    /// showed instead of an empty list.
    private var lastFallback: WifiScanState?
    private let networkList = WifiNetworkListView()

    /// The scrollable network list, exposed for tests that assert its 90%
    /// screen-height cap and scrolling behaviour.
    var networkListForTesting: WifiNetworkListView { networkList }

    override func loadView() {
        super.loadView()
        renderList()
    }

    /// Rows bake their colours in when built, so a theme change rebuilds them.
    override func restyle(_ theme: BarTheme) {
        super.restyle(theme)
        if let lastFallback {
            render(lastFallback)
        } else {
            renderList(lastList)
        }
    }

    /// Rebuild the body for a new scan state. The header and settings row are
    /// always present; only the body swaps.
    func render(_ state: WifiScanState) {
        switch state {
        case .idle, .scanning:
            renderList(WifiPopoverListRender(isScanning: true))
        case .networks(let networks):
            renderList(WifiPopoverListRender(networks: networks))
        case .permissionDenied, .unavailable, .failed:
            lastFallback = state
            lastList = WifiPopoverListRender()
            clearRows()
            stack.addArrangedSubview(header("Wi-Fi"))
            switch state {
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
            case .idle, .scanning, .networks:
                break
            }
            stack.addArrangedSubview(separator())
            stack.addArrangedSubview(linkButton("Open Wi-Fi Settings…",
                                                action: #selector(openWifiSettings)))
            stack.needsLayout = true
        }
    }

    /// Rebuild the body for the live list. The header and settings row are
    /// always present; only the body swaps. A fresh cache paints at once with
    /// its age line while `isScanning` keeps an animated row on screen; the
    /// background scan then updates the list in place.
    func renderList(networks: [WifiNetwork] = [],
                    isScanning: Bool = false,
                    cacheSummary: String? = nil,
                    connectingSSID: String? = nil,
                    notice: String? = nil,
                    recentJoins: [WifiJoinedNetwork] = []) {
        renderList(WifiPopoverListRender(networks: networks,
                                         isScanning: isScanning,
                                         cacheSummary: cacheSummary,
                                         connectingSSID: connectingSSID,
                                         notice: notice,
                                         recentJoins: recentJoins))
    }

    private func renderList(_ list: WifiPopoverListRender) {
        lastList = list
        lastFallback = nil
        clearRows()
        stack.addArrangedSubview(header("Wi-Fi"))
        if let cacheSummary = list.cacheSummary {
            stack.addArrangedSubview(ageLine(cacheSummary))
        }
        if list.isScanning {
            stack.addArrangedSubview(scanningRow())
        }
        if list.networks.isEmpty {
            if !list.isScanning {
                stack.addArrangedSubview(message("No networks found."))
            }
        } else {
            networkList.setRows(list.networks.map {
                rowButton(for: $0, connectingSSID: list.connectingSSID)
            })
            stack.addArrangedSubview(networkList)
        }
        if !list.recentJoins.isEmpty {
            stack.addArrangedSubview(sectionLabel("Previously joined"))
            for join in list.recentJoins {
                stack.addArrangedSubview(previouslyJoinedRow(for: join))
            }
        }
        if let notice = list.notice {
            stack.addArrangedSubview(message(notice))
            stack.addArrangedSubview(linkButton("Try Again", action: #selector(retry)))
        }
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Wi-Fi Settings…",
                                            action: #selector(openWifiSettings)))
        stack.needsLayout = true
    }

    // MARK: - Rows

    /// The cached list's age ("Updated 5s ago"), shown on the immediate first
    /// paint while the live scan runs behind it.
    private func ageLine(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = theme.popoverPalette.secondary
        label.identifier = Self.secondaryIdentifier
        return label
    }

    /// The scanning state: a spinning indicator beside the label, so the wait
    /// visibly moves instead of sitting as static text.
    private func scanningRow() -> NSView {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        spinner.setContentHuggingPriority(.required, for: .horizontal)

        let label = NSTextField(labelWithString: "Scanning…")
        label.font = .systemFont(ofSize: 12)
        label.textColor = theme.popoverPalette.secondary
        label.identifier = Self.secondaryIdentifier

        let row = NSStackView(views: [spinner, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    /// One clickable network row: the whole row is a borderless button holding
    /// the signal, name, and marks. While a connect is in flight every row is
    /// disabled and the joining row shows its own spinner and "Connecting…".
    private func rowButton(for network: WifiNetwork, connectingSSID: String?) -> NSView {
        let button = WifiNetworkRowButton(ssid: network.ssid)
        button.target = self
        button.action = #selector(selectRow(_:))
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(Self.accessibilityLabel(for: network))

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
        if network.ssid == connectingSSID {
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            spinner.setContentHuggingPriority(.required, for: .horizontal)
            let joining = NSTextField(labelWithString: "Connecting…")
            joining.font = .systemFont(ofSize: 12)
            joining.textColor = theme.popoverPalette.secondary
            joining.identifier = Self.secondaryIdentifier
            joining.setContentHuggingPriority(.required, for: .horizontal)
            views += [spinner, joining]
        } else {
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
        }

        let inner = NSStackView(views: views)
        inner.orientation = .horizontal
        inner.alignment = .centerY
        inner.spacing = 8
        inner.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: button.topAnchor),
            inner.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])
        // While one network is joining, the whole list holds still.
        button.isEnabled = connectingSSID == nil
        return button
    }

    /// A previously joined network Divot connected to itself: muted text with
    /// a clock mark, in its own section below the live list. These are not in
    /// range now, so they are shown, not joined, from here.
    private func previouslyJoinedRow(for join: WifiJoinedNetwork) -> NSView {
        let clock = NSImageView()
        clock.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Previously joined")
        clock.contentTintColor = theme.popoverPalette.secondary
        clock.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: join.ssid)
        name.font = .systemFont(ofSize: 12)
        name.textColor = theme.popoverPalette.secondary
        name.lineBreakMode = .byTruncatingMiddle
        name.maximumNumberOfLines = 1

        let row = NSStackView(views: [clock, name])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.staticText)
        row.setAccessibilityLabel("\(join.ssid), previously joined")
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

    @objc private func selectRow(_ sender: WifiNetworkRowButton) {
        guard let network = lastList.networks.first(where: { $0.ssid == sender.ssid }) else { return }
        onSelect?(network)
    }

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

/// The arguments of one `renderList` call, kept so a theme change rebuilds
/// the same rows.
private struct WifiPopoverListRender {
    var networks: [WifiNetwork] = []
    var isScanning = false
    var cacheSummary: String? = nil
    var connectingSSID: String? = nil
    var notice: String? = nil
    var recentJoins: [WifiJoinedNetwork] = []
}

/// A whole-row button holding one network's visuals. The SSID travels on the
/// button itself so the action can find its network without a tag table.
private final class WifiNetworkRowButton: NSButton {
    let ssid: String

    init(ssid: String) {
        self.ssid = ssid
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryPushIn)
        alignment = .left
    }

    required init?(coder: NSCoder) { fatalError("created in code") }
}

/// The Divot-styled password dialog for a secured network: a small panel with
/// a prompt, an `NSSecureTextField` (never a plain field in the bar), and
/// Join/Cancel. The entered password is returned to the caller only; this
/// dialog stores and logs nothing.
@MainActor
enum WifiPasswordPrompt {
    static func prompt(ssid: String) async -> String? {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 132),
                            styleMask: [.titled],
                            backing: .buffered,
                            defer: false)
        panel.title = "Join \u{201C}\(ssid)\u{201D}"
        let label = NSTextField(labelWithString: "Enter the password for \u{201C}\(ssid)\u{201D}.")
        label.font = .systemFont(ofSize: 12)
        let field = NSSecureTextField()
        field.placeholderString = "Password"
        let join = NSButton(title: "Join", target: nil, action: nil)
        join.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: nil, action: nil)
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, join])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        guard let content = panel.contentView else { return nil }
        for view: NSView in [label, field, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            field.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
        let stopper = ModalStopper()
        join.target = stopper
        join.action = #selector(ModalStopper.stopJoin)
        cancel.target = stopper
        cancel.action = #selector(ModalStopper.stopCancel)
        panel.makeFirstResponder(field)
        let code = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        guard code == .OK else { return nil }
        let value = field.stringValue
        return value.isEmpty ? nil : value
    }

    @MainActor
    private final class ModalStopper: NSObject {
        @objc func stopJoin() {
            NSApp.stopModal(withCode: .OK)
        }

        @objc func stopCancel() {
            NSApp.stopModal(withCode: .cancel)
        }
    }
}