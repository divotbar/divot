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
    private var theme: BarTheme
    private let metrics: BarMetrics
    /// Whether the filled-dot and hollow-ring occupancy markers are drawn
    /// (#0026). Root configuration, applied when the panel is built; the name
    /// and focus highlight stay either way.
    private let showOccupiedDot: Bool
    private let showEmptyDot: Bool

    private let horizontalInset: CGFloat
    private let chipSpacing: CGFloat
    /// The overflow control's real width, measured once from a template button,
    /// so `WorkspaceLayout.fit` reserves the space it actually needs. A fixed
    /// guess under-reserved and let a crowded row cross the notch at larger
    /// text sizes.
    private var overflowControlWidth: CGFloat = 30

    public init(feed: WorkspaceFeed,
                icons: WorkspaceIconProviding,
                displayScreensID: Int?,
                showsFrontApp: Bool = true,
                theme: BarTheme = .systemDefault,
                metrics: BarMetrics = .default,
                showOccupiedDot: Bool = true,
                showEmptyDot: Bool = true) {
        self.feed = feed
        self.icons = icons
        self.displayScreensID = displayScreensID
        self.showsFrontApp = showsFrontApp
        self.theme = theme
        self.metrics = metrics
        self.showOccupiedDot = showOccupiedDot
        self.showEmptyDot = showEmptyDot
        self.horizontalInset = metrics.rowInset
        self.chipSpacing = metrics.chipSpacing
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

        // Measure the overflow control's real width before any fit decision, so
        // the reserved space matches what is drawn.
        overflowControlWidth = makeOverflowButton(hidden: [],
                                                   options: .default,
                                                   occupancy: { _ in .unknown }).fittingSize.width

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
        frontAppLabel.font = BarFont.chip(metrics, weight: .regular)
        frontAppLabel.textColor = theme.secondary
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

    /// Re-color the row for a new theme. Chips are rebuilt because their colors
    /// live in the attributed title and the layer.
    public func apply(theme: BarTheme) {
        self.theme = theme
        frontAppLabel.textColor = theme.secondary
        rebuild()
    }

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
        button.setButtonType(.pushOnPushOff)
        button.state = workspace.isFocused ? .on : .off
        button.controlSize = .small
        button.refusesFirstResponder = false
        button.alignment = .center
        button.identifier = NSUserInterfaceItemIdentifier(workspace.id.rawValue)
        // The themed chip draws its own background so the selected state is the
        // family's `selected` color, not the system accent. Focus also remains
        // the control's selected state and an accessibility value, so state is
        // never color alone.
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        button.layer?.backgroundColor = workspace.isFocused ? theme.selected.cgColor : NSColor.clear.cgColor
        // The accent is the interactive focus emphasis: a restrained border on
        // the focused chip, on top of the selected background.
        button.layer?.borderWidth = workspace.isFocused ? 1 : 0
        button.layer?.borderColor = workspace.isFocused ? theme.accent.cgColor : NSColor.clear.cgColor

        let label = accessibilityDescription(for: workspace, options: options, occupancy: occupancy)
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.setAccessibilityValue(workspace.isFocused ? "selected" : "")

        let weight: NSFont.Weight = workspace.isFocused ? .semibold : .regular
        let font = BarFont.chip(metrics, weight: weight)
        let nameColor = workspace.isFocused ? theme.selectedForeground : theme.foreground
        let markerColor: NSColor
        switch occupancy {
        case .occupied: markerColor = theme.occupied
        case .empty, .unknown: markerColor = theme.disabled
        }
        button.attributedTitle = chipTitle(for: workspace,
                                           options: options,
                                           occupancy: occupancy,
                                           font: font,
                                           nameColor: nameColor,
                                           markerColor: markerColor)
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
    /// then a non-color occupancy marker for every non-focused workspace whose
    /// marker is enabled (#0026). The marker carries the `occupied`/`disabled`
    /// role; the name stays in the foreground (or the selected foreground) so
    /// occupancy is never conveyed by text tint alone.
    private func chipTitle(for workspace: Workspace,
                           options: WorkspaceDisplayOptions,
                           occupancy: WorkspaceOccupancy,
                           font: NSFont,
                           nameColor: NSColor,
                           markerColor: NSColor) -> NSAttributedString {
        let nameAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: nameColor]
        let markerAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: markerColor]

        let title = NSMutableAttributedString(string: workspace.id.rawValue, attributes: nameAttributes)
        let iconSize = max(8, metrics.chipFontSize.rounded())
        for identity in WorkspaceLayout.displayApps(for: workspace, options: options) {
            guard let icon = icons.icon(for: identity.bundleID, pointSize: iconSize) else { continue }
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -1.5, width: iconSize, height: iconSize)
            title.append(NSAttributedString(string: " ", attributes: nameAttributes))
            title.append(NSAttributedString(attachment: attachment))
        }
        if !workspace.isFocused, showsMarker(for: occupancy) {
            title.append(NSAttributedString(string: " ", attributes: markerAttributes))
            title.append(NSAttributedString(string: Self.occupancyMarker(for: occupancy),
                                            attributes: markerAttributes))
        }
        return title
    }

    /// Whether the configured marker for this occupancy is drawn. An occupied
    /// chip's filled dot and an empty chip's ring are each optional (#0026); the
    /// unknown ring has no toggle and stays as the honest "could not inspect"
    /// cue.
    private func showsMarker(for occupancy: WorkspaceOccupancy) -> Bool {
        switch occupancy {
        case .occupied: return showOccupiedDot
        case .empty: return showEmptyDot
        case .unknown: return true
        }
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
