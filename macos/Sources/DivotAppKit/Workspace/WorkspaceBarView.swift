import AppKit
import DivotCore

/// The left-panel workspace row: real manager workspace names, focused /
/// occupied / empty state, optional deduplicated app icons, an overflow control,
/// and the current program beside them.
///
/// It only reads `WorkspaceFeed` state and forwards clicks to
/// `WorkspaceFeed.activate`. It never runs a query itself, so it adds no
/// subprocess work on layout or display passes.
@MainActor
public final class WorkspaceBarView: NSView, BarContentLifecycle {
    private let feed: WorkspaceFeed
    private let icons: WorkspaceIconProviding
    /// 1-based `NSScreen.screens` index this row belongs to, or `nil` to show
    /// every workspace (single display / unknown mapping).
    private let displayScreensID: Int?

    private let stack = NSStackView()
    private let frontAppLabel = NSTextField(labelWithString: "")
    private var observerID: UUID?
    private var activationObserver: NSObjectProtocol?
    private var lastState: WorkspaceFeedState?
    private var lastWidth: CGFloat = -1

    private let horizontalInset: CGFloat = 8
    private let chipSpacing: CGFloat = 6
    private let overflowControlWidth: CGFloat = 30

    public init(feed: WorkspaceFeed,
                icons: WorkspaceIconProviding,
                displayScreensID: Int?) {
        self.feed = feed
        self.icons = icons
        self.displayScreensID = displayScreensID
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WorkspaceBarView does not support NSCoding")
    }

    // MARK: Setup

    private func setup() {
        wantsLayer = true
        applyChrome()

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = chipSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -horizontalInset),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        frontAppLabel.font = .systemFont(ofSize: 11)
        frontAppLabel.textColor = .secondaryLabelColor
        frontAppLabel.lineBreakMode = .byTruncatingTail
        frontAppLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        observerID = feed.addObserver { [weak self] state in
            self?.apply(state)
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateFrontApp() }
        }
        updateFrontApp()
    }

    public override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        if newSuperview == nil { barContentDidDetach() }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
    }

    /// Match the shell's segment chrome so the workspace row stays visibly part
    /// of the bar rather than leaving a transparent gap.
    private func applyChrome() {
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    public func barContentDidDetach() {
        if let observerID {
            feed.removeObserver(observerID)
            self.observerID = nil
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    // MARK: Rendering

    public override func layout() {
        super.layout()
        if abs(bounds.width - lastWidth) > 0.5 { rebuild() }
    }

    private func apply(_ state: WorkspaceFeedState) {
        lastState = state
        rebuild()
    }

    private func rebuild() {
        lastWidth = bounds.width
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard let state = lastState else { return }
        let options = state.options
        let workspaces = WorkspaceLayout.workspaces(forScreensID: displayScreensID,
                                                     in: state.snapshot,
                                                     options: options)
        let chips = workspaces.map { workspace in
            (workspace: workspace, button: makeChip(for: workspace, options: options))
        }
        let byID = Dictionary(chips.map { ($0.workspace.id, $0.button) },
                              uniquingKeysWith: { first, _ in first })

        let overflow = WorkspaceLayout.fit(workspaces,
                                           width: { byID[$0.id]?.fittingSize.width ?? 44 },
                                           availableWidth: max(0, bounds.width - horizontalInset * 2),
                                           spacing: chipSpacing,
                                           overflowWidth: overflowControlWidth)

        for workspace in overflow.visible {
            guard let button = byID[workspace.id] else { continue }
            stack.addArrangedSubview(button)
        }
        if !overflow.hidden.isEmpty {
            stack.addArrangedSubview(makeOverflowButton(hidden: overflow.hidden, options: options))
        }
        if options.showDetails {
            stack.addArrangedSubview(frontAppLabel)
        }
    }

    private func makeChip(for workspace: Workspace, options: WorkspaceDisplayOptions) -> NSButton {
        let button = ChipButton(title: workspace.id.rawValue, target: self, action: #selector(chipClicked(_:)))
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.state = workspace.isFocused ? .on : .off
        button.font = .systemFont(ofSize: 11, weight: workspace.isFocused ? .semibold : .regular)
        button.controlSize = .small
        button.refusesFirstResponder = false
        button.identifier = NSUserInterfaceItemIdentifier(workspace.id.rawValue)
        button.toolTip = accessibilityDescription(for: workspace, options: options)
        button.setAccessibilityLabel(accessibilityDescription(for: workspace, options: options))
        button.setAccessibilityValue(workspace.isFocused ? "selected" : "")

        if options.showAppIcons,
           let app = workspace.apps.first,
           let icon = icons.icon(for: app.identity.bundleID, pointSize: 13) {
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageLeading
        }
        // Empty and occupied differ by weight and accessibility, not color alone.
        if !workspace.isOccupied && !workspace.isFocused {
            button.contentTintColor = .secondaryLabelColor
        }
        return button
    }

    private func makeOverflowButton(hidden: [Workspace], options: WorkspaceDisplayOptions) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.bezelStyle = .recessed
        popup.controlSize = .small
        popup.addItem(withTitle: "···")
        popup.toolTip = "\(hidden.count) more workspace\(hidden.count == 1 ? "" : "s")"
        popup.setAccessibilityLabel("More workspaces")
        for workspace in hidden {
            let item = NSMenuItem(title: workspace.id.rawValue,
                                  action: #selector(overflowSelected(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = workspace.id.rawValue
            item.state = workspace.isFocused ? .on : .off
            item.toolTip = accessibilityDescription(for: workspace, options: options)
            popup.menu?.addItem(item)
        }
        return popup
    }

    private func accessibilityDescription(for workspace: Workspace,
                                          options: WorkspaceDisplayOptions) -> String {
        let state = workspace.isFocused ? "focused" : (workspace.isOccupied ? "occupied" : "empty")
        guard options.showDetails, workspace.isOccupied else {
            return "Workspace \(workspace.id), \(state)"
        }
        let count = workspace.apps.count
        return "Workspace \(workspace.id), \(state), \(count) app\(count == 1 ? "" : "s")"
    }

    // MARK: Actions

    @objc private func chipClicked(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue else { return }
        activate(WorkspaceID(raw))
    }

    @objc private func overflowSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        activate(WorkspaceID(raw))
    }

    private func activate(_ id: WorkspaceID) {
        Task { [feed] in await feed.activate(id) }
    }

    private func updateFrontApp() {
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "—"
        frontAppLabel.stringValue = name
        frontAppLabel.setAccessibilityLabel("Frontmost app: \(name)")
    }
}

/// A chip that reacts on the first click even though the bar panel is
/// nonactivating and never becomes key.
private final class ChipButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
