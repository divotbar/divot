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
    /// When the layout places the `front-app` item beside this row, that item
    /// owns the current program and this view must not duplicate it. When it is
    /// absent from this side, this view shows the program itself.
    private let showsFrontApp: Bool
    private var observerID: UUID?
    private var activationObserver: NSObjectProtocol?
    private var lastState: WorkspaceFeedState?
    private var lastWidth: CGFloat = -1

    private let horizontalInset: CGFloat = 8
    private let chipSpacing: CGFloat = 6
    private let overflowControlWidth: CGFloat = 30

    public init(feed: WorkspaceFeed,
                icons: WorkspaceIconProviding,
                displayScreensID: Int?,
                showsFrontApp: Bool = true) {
        self.feed = feed
        self.icons = icons
        self.displayScreensID = displayScreensID
        self.showsFrontApp = showsFrontApp
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
        // The parent (`BarContentView`) owns the segment chrome; clip this row to
        // the width it assigns so no chip can draw over a neighbour.
        layer?.masksToBounds = true

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

        observerID = feed.addObserver { [weak self] state in
            self?.apply(state)
        }

        guard showsFrontApp else { return }
        frontAppLabel.font = .systemFont(ofSize: 11)
        frontAppLabel.textColor = .secondaryLabelColor
        frontAppLabel.lineBreakMode = .byTruncatingTail
        frontAppLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
        let occupancy: (Workspace) -> WorkspaceOccupancy = { workspace in
            state.snapshot?.occupancy(of: workspace) ?? workspace.occupancy
        }
        let chips = workspaces.map { workspace in
            (workspace: workspace, button: makeChip(for: workspace, options: options, occupancy: occupancy(workspace)))
        }
        let byID = Dictionary(chips.map { ($0.workspace.id, $0.button) },
                              uniquingKeysWith: { first, _ in first })

        let availableWidth = max(0, bounds.width - horizontalInset * 2)
        let overflow = WorkspaceLayout.fit(workspaces,
                                           width: { byID[$0.id]?.fittingSize.width ?? 44 },
                                           availableWidth: availableWidth,
                                           spacing: chipSpacing,
                                           overflowWidth: overflowControlWidth,
                                           trailingReserve: showsFrontApp && options.showDetails
                                               ? frontAppReserve(within: availableWidth)
                                               : 0)

        for workspace in overflow.visible {
            guard let button = byID[workspace.id] else { continue }
            stack.addArrangedSubview(button)
        }
        if !overflow.hidden.isEmpty {
            stack.addArrangedSubview(makeOverflowButton(hidden: overflow.hidden,
                                                        options: options,
                                                        occupancy: occupancy))
        }
        if showsFrontApp && options.showDetails {
            stack.addArrangedSubview(frontAppLabel)
        }
    }

    /// Width to keep free for the current-program label so a crowded row spills
    /// workspaces into the overflow menu instead of clipping the program name.
    /// The label is capped so it can never crowd out the workspace chips.
    private func frontAppReserve(within availableWidth: CGFloat) -> CGFloat {
        let measured = max(0, frontAppLabel.fittingSize.width)
        let cap = max(60, availableWidth * 0.4)
        return min(measured, cap) + chipSpacing
    }

    private func makeChip(for workspace: Workspace,
                          options: WorkspaceDisplayOptions,
                          occupancy: WorkspaceOccupancy) -> NSButton {
        let button = ChipButton(title: workspace.id.rawValue, target: self, action: #selector(chipClicked(_:)))
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.state = workspace.isFocused ? .on : .off
        button.controlSize = .small
        button.refusesFirstResponder = false
        button.alignment = .center
        button.identifier = NSUserInterfaceItemIdentifier(workspace.id.rawValue)

        let label = accessibilityDescription(for: workspace, options: options, occupancy: occupancy)
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.setAccessibilityValue(workspace.isFocused ? "selected" : "")

        let weight: NSFont.Weight = workspace.isFocused ? .semibold : .regular
        let font = NSFont.systemFont(ofSize: 11, weight: weight)
        let tint: NSColor? = (occupancy == .empty || occupancy == .unknown) && !workspace.isFocused
            ? .secondaryLabelColor : nil
        button.attributedTitle = chipTitle(for: workspace,
                                           options: options,
                                           occupancy: occupancy,
                                           font: font,
                                           tint: tint)
        return button
    }

    /// Compact non-color occupancy cue: a filled dot for occupied, a hollow ring
    /// for empty and a dotted ring for unknown. Shape alone separates the three,
    /// so occupancy is never conveyed by text tint alone — especially when app
    /// icons are disabled. Focused chips use the control's selected state.
    static func occupancyMarker(for occupancy: WorkspaceOccupancy) -> String {
        switch occupancy {
        case .occupied: return "●"
        case .empty: return "○"
        case .unknown: return "◌"
        }
    }

    /// The chip title: the workspace name plus one attachment per deduplicated
    /// app icon, so enabling icons shows every app rather than only the first,
    /// then a non-color occupancy marker for every non-focused workspace.
    private func chipTitle(for workspace: Workspace,
                           options: WorkspaceDisplayOptions,
                           occupancy: WorkspaceOccupancy,
                           font: NSFont,
                           tint: NSColor?) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let tint { attributes[.foregroundColor] = tint }

        let title = NSMutableAttributedString(string: workspace.id.rawValue, attributes: attributes)
        for identity in WorkspaceLayout.displayApps(for: workspace, options: options) {
            guard let icon = icons.icon(for: identity.bundleID, pointSize: 12) else { continue }
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -1.5, width: 12, height: 12)
            title.append(NSAttributedString(string: " ", attributes: attributes))
            title.append(NSAttributedString(attachment: attachment))
        }
        if !workspace.isFocused {
            title.append(NSAttributedString(string: " ", attributes: attributes))
            title.append(NSAttributedString(string: Self.occupancyMarker(for: occupancy),
                                            attributes: attributes))
        }
        return title
    }

    private func makeOverflowButton(hidden: [Workspace],
                                    options: WorkspaceDisplayOptions,
                                    occupancy: (Workspace) -> WorkspaceOccupancy) -> NSPopUpButton {
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
            item.toolTip = accessibilityDescription(for: workspace,
                                                    options: options,
                                                    occupancy: occupancy(workspace))
            popup.menu?.addItem(item)
        }
        return popup
    }

    private func accessibilityDescription(for workspace: Workspace,
                                          options: WorkspaceDisplayOptions,
                                          occupancy: WorkspaceOccupancy) -> String {
        let state: String
        if workspace.isFocused {
            state = "focused"
        } else {
            switch occupancy {
            case .occupied: state = "occupied"
            case .empty: state = "empty"
            case .unknown: state = "occupancy unknown"
            }
        }
        guard options.showDetails, occupancy == .occupied else {
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

    /// Render the current row offscreen to an image. Used by tests and headless
    /// checks to verify the view actually draws; it creates no window.
    public func renderPreviewImage() -> NSImage? {
        guard bounds.width > 0, bounds.height > 0,
              let representation = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: representation)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(representation)
        return image
    }
}

/// A chip that reacts on the first click even though the bar panel is
/// nonactivating and never becomes key.
private final class ChipButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
