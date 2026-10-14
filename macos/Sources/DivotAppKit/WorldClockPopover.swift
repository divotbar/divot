import AppKit
import DivotCore

/// NSSearchField subclass that handles Escape (clear the search) and Tab (move
/// focus into the results list) keys.
@MainActor
private final class SearchFieldWithEscape: NSSearchField {
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onEscape?()   // Escape
        case 48: onTab?()      // Tab
        default: super.keyDown(with: event)
        }
    }
}

/// The time scrubber slider. Arrow keys move it one step (the task's keyboard
/// rule: 15 minutes); the controller maps that onto `WorldClockScrubber`. It
/// takes first responder so Tab and a click both reach it.
@MainActor
private final class TimeScrubberSlider: NSSlider {
    /// Called with -1 (back) or +1 (forward) for an arrow-key press.
    var onStep: ((Int) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 125: onStep?(-1) // left arrow, down arrow
        case 124, 126: onStep?(1)  // right arrow, up arrow
        default: super.keyDown(with: event)
        }
    }
}

/// One left-aligned zone row: a day/night marker, the zone name over its time,
/// offset and day label, and a remove control at the trailing edge.
///
/// It is a controller rather than a bare view so scrubbing updates the time and
/// marker in place instead of rebuilding the stack, which would interrupt a drag
/// and drop the search field's focus.
@MainActor
private final class WorldClockZoneRow {
    let view: NSView
    let removeButton = NSButton()

    private let marker = NSImageView()
    private let nameLabel: NSTextField
    private let infoLabel = NSTextField(labelWithString: "")
    private let timezone: String
    private let displayName: String

    init(entry: WorldClockEntry, theme: BarTheme,
         removeTarget: AnyObject?, removeAction: Selector) {
        self.timezone = entry.timezone
        self.displayName = entry.displayName

        marker.translatesAutoresizingMaskIntoConstraints = false
        marker.imageScaling = .scaleProportionallyDown
        marker.setAccessibilityRole(.image)
        NSLayoutConstraint.activate([
            marker.widthAnchor.constraint(equalToConstant: 14),
            marker.heightAnchor.constraint(equalToConstant: 14)
        ])

        nameLabel = NSTextField(labelWithString: entry.displayName)
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = theme.popoverPalette.label
        nameLabel.identifier = BarPopoverContentController.headerIdentifier
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        infoLabel.font = .systemFont(ofSize: 11)
        infoLabel.textColor = theme.popoverPalette.secondary
        infoLabel.identifier = BarPopoverContentController.secondaryIdentifier
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        removeButton.setButtonType(.momentaryPushIn)
        removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                     accessibilityDescription: "Remove \(entry.displayName)")
        removeButton.bezelStyle = .circular
        removeButton.font = .systemFont(ofSize: 11)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.identifier = NSUserInterfaceItemIdentifier(entry.timezone)
        removeButton.target = removeTarget
        removeButton.action = removeAction
        removeButton.setAccessibilityLabel("Remove \(entry.displayName)")
        removeButton.toolTip = "Remove \(entry.displayName)"

        let textStack = NSStackView(views: [nameLabel, infoLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = NSStackView(views: [marker, textStack, removeButton])
        rowStack.orientation = .horizontal
        rowStack.spacing = 8
        rowStack.alignment = .centerY
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.distribution = .fill
        self.view = rowStack
    }

    /// Repaint the converted time, offset, day label and day/night marker.
    func update(entry: WorldClockEntry,
                timeFormat: TimeConfiguration.Format,
                showSeconds: Bool,
                customPattern: String?,
                theme: BarTheme) {
        guard entry.timezone == timezone else { return }
        let zone = TimeZone(identifier: entry.timezone) ?? .current
        let timeText = worldClockTimeString(entry.date, timeZone: zone,
                                            timeFormat: timeFormat,
                                            showSeconds: showSeconds,
                                            customPattern: customPattern)
        let offsetText = WorldClock.formatHourOffset(entry.hourOffset)
        let dayText = entry.dayLabel.map { " \($0)" } ?? ""
        infoLabel.stringValue = "\(timeText) (\(offsetText))\(dayText)"

        let symbol = entry.isWorkingHours ? "sun.max.fill" : "moon.fill"
        let description = entry.isWorkingHours ? "Working hours" : "Outside working hours"
        marker.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        marker.contentTintColor = entry.isWorkingHours
            ? theme.popoverPalette.label
            : theme.popoverPalette.secondary
        marker.setAccessibilityLabel(description)

        let dayAnnouncement = entry.dayLabel.map { ", \($0)" } ?? ""
        infoLabel.setAccessibilityLabel("\(timeText), \(offsetText)\(dayAnnouncement), \(description)")
    }
}

/// A results row whose cell is flush with the leading edge. AppKit's default
/// full-width row insets its cell by 6pt, which would misalign the results with
/// the rest of the popover's rows.
@MainActor
private final class TimezoneResultRowView: NSTableRowView {
    override func layout() {
        super.layout()
        for subview in subviews {
            var frame = subview.frame
            frame.origin.x = 0
            frame.size.width = bounds.width
            subview.frame = frame
        }
    }
}

/// NSTableView subclass that handles Return (add the highlighted row), Escape
/// (clear the search) and Tab (move focus back to the search field) keys.
@MainActor
private final class TimezoneResultsTableView: NSTableView {
    var onReturnKey: (() -> Void)?
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    /// Move the selection by one row. The controller owns the move so the arrow
    /// keys can skip rows that cannot be added (already-added zones).
    var onMoveSelection: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36: // Return key
            onReturnKey?()
        case 53: // Escape key
            onEscape?()
        case 48: // Tab key
            onTab?()
        case 125: // Down arrow
            onMoveSelection?(1)
        case 126: // Up arrow
            onMoveSelection?(-1)
        default:
            super.keyDown(with: event)
        }
    }
}

/// The scrollable list of the user's zone rows. It fits its content up to
/// `maximumVisibleRows` and scrolls beyond that, so a long list cannot grow the
/// panel without bound (the Add row and the settings link stay on screen).
@MainActor
private final class TimezoneZoneListView: NSView {
    /// The most rows to show before the list scrolls.
    static let maximumVisibleRows = 8
    private static let rowSpacing: CGFloat = 6

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

    /// Replace the rows and resize to fit up to `maximumVisibleRows`, scrolling
    /// when there are more.
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
        let visibleCount = min(newRows.count, Self.maximumVisibleRows)
        let visible = heights.prefix(visibleCount).reduce(0, +)
            + spacing * CGFloat(max(0, visibleCount - 1))
        setHeight(min(total, visible))
    }

    private func setHeight(_ height: CGFloat) {
        heightConstraint?.isActive = false
        let constraint = heightAnchor.constraint(equalToConstant: max(1, height))
        constraint.isActive = true
        heightConstraint = constraint
    }
}

/// A popover anchored to the bar's time item that shows world clock entries for added timezones.
@MainActor
public final class WorldClockPopoverController {
    private let openDateTimeSettings: @MainActor () -> Void
    private let getConfiguration: @MainActor () -> DivotConfiguration
    private let updateTimezones: @MainActor ([String]) -> Void

    private let host: BarPopoverHost
    private var content: WorldClockPopoverContentController?

    public init(openDateTimeSettings: @escaping @MainActor () -> Void,
               getConfiguration: @escaping @MainActor () -> DivotConfiguration,
               updateTimezones: @escaping @MainActor ([String]) -> Void) {
        self.host = BarPopoverHost()
        self.openDateTimeSettings = openDateTimeSettings
        self.getConfiguration = getConfiguration
        self.updateTimezones = updateTimezones
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Test seam: inject the host so a test can drive the real
    /// present → render → rebuild path with a windowless presenter (#0091).
    init(testingHost host: BarPopoverHost,
         openDateTimeSettings: @escaping @MainActor () -> Void,
         getConfiguration: @escaping @MainActor () -> DivotConfiguration,
         updateTimezones: @escaping @MainActor ([String]) -> Void) {
        self.host = host
        self.openDateTimeSettings = openDateTimeSettings
        self.getConfiguration = getConfiguration
        self.updateTimezones = updateTimezones
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// The live content controller while presented, for tests that assert on the
    /// rows the real present → render path built.
    var contentForTesting: WorldClockPopoverContentController? { content }

    /// Show the popover below `view` with the current time and added timezones.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()

        let controller = WorldClockPopoverContentController()
        controller.theme = theme
        controller.onOpenDateTimeSettings = { [weak self] in self?.openDateTimeSettings() }
        controller.onUpdateTimezones = { [weak self] timezones in
            self?.updateTimezones(timezones)
            self?.render()
        }
        controller.onContentSizeChanged = { [weak self] in self?.resizeToContent() }

        host.present(controller, relativeTo: view)
        self.content = controller
        render()
    }

    /// Re-render from the current configuration. The bar calls this from the
    /// time item's own tick (the `TimeProvider` minute/second boundary emission)
    /// while the popover is open, so the panel runs no timer of its own.
    public func refreshIfShown() {
        guard host.isShown, content != nil else { return }
        render()
    }

    private func render() {
        guard let content else { return }
        let config = getConfiguration()
        let timezones = timezoneListFromConfiguration(config)
        content.render(timezones: timezones,
                       timeFormat: config.widgets.time.timeFormat,
                       showSeconds: config.widgets.time.seconds,
                       customPattern: config.widgets.time.customPattern)
        resizeToContent()
    }

    /// Match the shown panel to the content's current preferred size. Used after
    /// a full render and whenever the content changes size on its own (the
    /// search results list appearing or disappearing).
    private func resizeToContent() {
        guard let content else { return }
        host.resize(to: content.preferredSize)
    }

    /// Resolve the stored list into the zones to show. Internal so the
    /// absent-vs-empty and local-duplicate rules are unit-tested through the
    /// controller's own path.
    func timezoneListFromConfiguration(_ config: DivotConfiguration) -> [String] {
        WorldClock.resolvedTimezones(configured: config.widgets.time.timezones)
    }

    /// Hide the popover and clear the controller reference.
    public func dismiss() {
        host.dismiss()
        content = nil
    }

    /// Toggle the popover: dismiss if open, present otherwise.
    public func toggle(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        if host.itemClickCloses(relativeTo: view) {
            dismiss()
        } else {
            present(relativeTo: view, theme: theme)
        }
    }

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

    private func handleClosed() {
        content = nil
    }
}

/// The content controller for the world clock popover.
@MainActor
final class WorldClockPopoverContentController: BarPopoverContentController {
    var onOpenDateTimeSettings: @MainActor () -> Void = {}
    var onUpdateTimezones: (([String]) -> Void)? = nil
    /// Called when the content's own size changes outside a full render — the
    /// search results list appearing or disappearing — so the host can resize
    /// the real panel to match. A full render resizes through the host anyway.
    var onContentSizeChanged: (() -> Void)? = nil

    /// The value a single scrub step moves, in minutes (mirrors the core rule).
    static let scrubStepMinutes = WorldClockScrubber.stepMinutes
    /// The slider's top value, in local minutes of day.
    static let lastMinuteOfDay = 24 * 60 - 1

    private var currentTimezones: [String] = []
    private var timeFormat: TimeConfiguration.Format = .twentyFourHour
    private var showSeconds = false
    private var customPattern: String?
    private var localTimeZone: TimeZone = .current
    private var calendar: Calendar = .current
    /// The converter state. Persists across the bar's per-minute refresh so a
    /// scrubbed instant is not reset to "now" while the popover stays open.
    private var scrubber: WorldClockScrubber?

    private var localTimeLabel: NSTextField?
    private var scrubberSlider: TimeScrubberSlider?
    private var scrubberTimeLabel: NSTextField?
    private var nowButton: NSButton?
    private var zoneRows: [WorldClockZoneRow] = []

    private var searchField: NSSearchField?
    private var resultsController: TimezoneSearchResultsController?
    private var searchObserver: NSObjectProtocol?
    private let zoneList = TimezoneZoneListView()

    /// Test seam: the live slider, so a test can drive the real arrow-key path.
    var scrubberSliderForTesting: NSSlider? { scrubberSlider }

    /// The fraction of the screen height the search results — and the popover
    /// around them — may occupy before scrolling.
    static let maximumResultsHeightFraction: CGFloat = 0.9

    /// Test seam: pins the screen height the results cap is computed from. `nil`
    /// (the default) uses the popover window's screen, then the main screen; when
    /// no screen is known (a headless run) the results are left uncapped.
    var screenHeightForTesting: CGFloat?

    /// The search results controller while a render is live, for tests that
    /// assert the live panel path's cap and scrolling.
    var searchResultsForTesting: TimezoneSearchResultsController? { resultsController }

    /// The always-last row: a separator and the Date & Time settings link. Built
    /// by every render because `clearRows()` removes the previous one.
    private func addSettingsRow() {
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Date & Time Settings...",
                                            action: #selector(openDateTimeSettings)))
    }

    func render(timezones: [String],
                timeFormat: TimeConfiguration.Format,
                showSeconds: Bool,
                customPattern: String? = nil,
                at date: Date = Date(),
                localTimeZone: TimeZone = .current,
                calendar: Calendar = .current) {
        clearRows()
        self.currentTimezones = timezones
        self.timeFormat = timeFormat
        self.showSeconds = showSeconds
        self.customPattern = customPattern
        self.localTimeZone = localTimeZone
        self.calendar = calendar

        // Keep a scrubbed instant across the bar's per-minute refresh, but always
        // advance the reference so the "Now" control means the current minute.
        if var existing = scrubber, existing.localTimeZone == localTimeZone {
            existing.referenceDate = date
            scrubber = existing
        } else {
            scrubber = WorldClockScrubber(referenceDate: date,
                                          localTimeZone: localTimeZone,
                                          calendar: calendar)
        }

        let entries = WorldClock.entries(for: timezones, at: date,
                                         localTimeZone: localTimeZone, calendar: calendar)

        let localTime = NSTextField(labelWithString: "")
        localTime.font = .systemFont(ofSize: 14, weight: .semibold)
        localTime.textColor = theme.popoverPalette.label
        localTime.identifier = Self.headerIdentifier
        localTimeLabel = localTime
        stack.addArrangedSubview(localTime)

        let localCityLabel = NSTextField(labelWithString: WorldClock.friendlyName(for: localTimeZone.identifier))
        localCityLabel.font = .systemFont(ofSize: 10)
        localCityLabel.textColor = theme.popoverPalette.secondary
        localCityLabel.identifier = Self.secondaryIdentifier
        stack.addArrangedSubview(localCityLabel)

        // The time converter: a scrubber over the local day and its "Now" reset.
        stack.addArrangedSubview(separator())
        addScrubberRows()
        stack.addArrangedSubview(separator())

        if !entries.isEmpty {
            zoneRows = entries.map { entry in
                WorldClockZoneRow(entry: entry, theme: theme,
                                  removeTarget: self, removeAction: #selector(removeTimezone(_:)))
            }
            zoneList.setRows(zoneRows.map(\.view))
            stack.addArrangedSubview(zoneList)
            stack.addArrangedSubview(separator())
        } else {
            zoneRows = []
            let hintLabel = NSTextField(labelWithString: "No other timezones. Add one below.")
            hintLabel.font = .systemFont(ofSize: 11)
            hintLabel.textColor = theme.popoverPalette.secondary
            hintLabel.identifier = Self.secondaryIdentifier
            stack.addArrangedSubview(hintLabel)
        }

        let addLabel = NSTextField(labelWithString: "Add timezone…")
        addLabel.font = .systemFont(ofSize: 12)
        addLabel.textColor = theme.popoverPalette.label
        addLabel.identifier = Self.headerIdentifier
        addLabel.translatesAutoresizingMaskIntoConstraints = false

        let search = SearchFieldWithEscape()
        search.placeholderString = "Search (e.g., Tokyo)"
        search.font = .systemFont(ofSize: 11)
        search.translatesAutoresizingMaskIntoConstraints = false
        search.setAccessibilityLabel("Add timezone")
        search.onEscape = { [weak self] in
            self?.clearSearch()
        }
        search.onTab = { [weak self] in
            self?.focusResults()
        }
        self.searchField = search
        styleSearchField()

        if let oldObserver = searchObserver {
            NotificationCenter.default.removeObserver(oldObserver)
        }

        searchObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: search,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateSearchResults() }
        }

        let resultsController = TimezoneSearchResultsController(
            onSelect: { [weak self] timezone in
                self?.addTimezone(timezone)
            },
            theme: theme
        )
        resultsController.onEscape = { [weak self] in self?.clearSearch() }
        resultsController.onTab = { [weak self] in self?.focusSearchField() }
        self.resultsController = resultsController

        let addStack = NSStackView(views: [addLabel, search])
        addStack.orientation = .vertical
        addStack.spacing = 4
        addStack.alignment = .leading
        addStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(addStack)

        resultsController.view.isHidden = true
        stack.addArrangedSubview(resultsController.view)

        addSettingsRow()
        updateTimes()
    }

    /// Build the scrubber row: the slider with its selected time, and a "Now"
    /// reset beside the fixed working-hours note. Added directly to the row
    /// stack so the slider stretches to the popover's width.
    private func addScrubberRows() {
        let slider = TimeScrubberSlider(value: 0, minValue: 0,
                                        maxValue: Double(Self.lastMinuteOfDay),
                                        target: nil, action: nil)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(scrubberDragged)
        slider.onStep = { [weak self] direction in self?.stepScrubber(by: direction) }
        slider.setAccessibilityLabel("Time to convert")
        slider.setAccessibilityHelp("Arrow keys adjust by 15 minutes")
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        slider.translatesAutoresizingMaskIntoConstraints = false
        scrubberSlider = slider

        let timeLabel = NSTextField(labelWithString: "")
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        timeLabel.alignment = .right
        timeLabel.textColor = theme.popoverPalette.label
        timeLabel.identifier = Self.headerIdentifier
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        scrubberTimeLabel = timeLabel

        let sliderRow = NSStackView(views: [slider, timeLabel])
        sliderRow.orientation = .horizontal
        sliderRow.alignment = .centerY
        sliderRow.spacing = 8
        sliderRow.distribution = .fill
        sliderRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sliderRow)

        let reset = NSButton(title: "Now", target: self, action: #selector(resetScrubber))
        reset.bezelStyle = .rounded
        reset.controlSize = .small
        reset.setAccessibilityLabel("Reset to now")
        reset.setAccessibilityHelp("Return the converter to the current time")
        reset.translatesAutoresizingMaskIntoConstraints = false
        nowButton = reset

        let caption = NSTextField(labelWithString: "Working hours 09:00–18:00")
        caption.font = .systemFont(ofSize: 10)
        caption.textColor = theme.popoverPalette.secondary
        caption.identifier = Self.secondaryIdentifier
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let captionRow = NSStackView(views: [reset, caption, spacer])
        captionRow.orientation = .horizontal
        captionRow.alignment = .centerY
        captionRow.spacing = 8
        captionRow.distribution = .fill
        captionRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(captionRow)
    }

    /// Repaint the header, the scrubber and every zone row for the instant the
    /// converter currently shows. Called after a render, a scrub step, a drag,
    /// a "Now" reset and a theme change.
    func updateTimes() {
        guard let scrubber else { return }
        let shown = scrubber.shownDate

        let localOffset = localTimeZone.secondsFromGMT(for: shown)
        let localText = worldClockTimeString(shown, timeZone: localTimeZone,
                                             timeFormat: timeFormat, showSeconds: showSeconds,
                                             customPattern: customPattern)
        localTimeLabel?.stringValue = "\(localText)  UTC\(formatCompactOffset(localOffset))"

        let entries = WorldClock.entries(for: currentTimezones, at: shown,
                                         localTimeZone: localTimeZone, calendar: calendar)
        for (row, entry) in zip(zoneRows, entries) {
            row.update(entry: entry, timeFormat: timeFormat, showSeconds: showSeconds,
                       customPattern: customPattern, theme: theme)
        }

        let minutes = scrubber.shownMinutesOfDay
        let timeText = worldClockTimeString(shown, timeZone: localTimeZone,
                                            timeFormat: timeFormat, showSeconds: false,
                                            customPattern: customPattern)
        scrubberTimeLabel?.stringValue = timeText
        scrubberSlider?.doubleValue = Double(minutes)
        scrubberSlider?.setAccessibilityValue(timeText)
        nowButton?.isEnabled = !scrubber.isFollowingNow
    }

    /// Move the converter by whole 15-minute steps. The slider's arrow keys and
    /// a test both go through here, so the keyboard rule is exercised end to end.
    func stepScrubber(by steps: Int) {
        guard scrubber != nil else { return }
        scrubber?.step(by: steps)
        updateTimes()
    }

    @objc private func scrubberDragged() {
        guard let slider = scrubberSlider else { return }
        let minutes = min(Self.lastMinuteOfDay, max(0, Int(slider.doubleValue.rounded())))
        let snapped = (minutes / Self.scrubStepMinutes) * Self.scrubStepMinutes
        scrubber?.setTimeOfDay(hour: snapped / 60, minute: snapped % 60)
        updateTimes()
    }

    @objc private func resetScrubber() {
        scrubber?.reset()
        updateTimes()
    }

    /// Recolour the search field's text and placeholder from the theme, so the
    /// placeholder clears the same contrast floor as the other secondary text
    /// (the system default placeholder colour is intentionally dimmer).
    override func restyle(_ theme: BarTheme) {
        super.restyle(theme)
        styleSearchField()
        resultsController?.restyle(theme)
        // A theme change must repaint the zone markers, which are images, not
        // text fields, so the row colours are re-derived from the new palette.
        updateTimes()
    }

    private func styleSearchField() {
        guard let search = searchField else { return }
        let palette = theme.popoverPalette
        search.textColor = palette.label
        let font = search.font ?? .systemFont(ofSize: 11)
        search.placeholderAttributedString = NSAttributedString(
            string: "Search (e.g., Tokyo, Asia/Tokyo)",
            attributes: [.foregroundColor: palette.secondary, .font: font])
    }

    @objc private func removeTimezone(_ sender: NSButton) {
        guard let timezone = sender.identifier?.rawValue else { return }
        var updated = currentTimezones
        updated.removeAll { $0 == timezone }
        currentTimezones = updated
        onUpdateTimezones?(updated)
    }

    private func updateSearchResults() {
        guard let resultsController = resultsController,
              let searchField = searchField else { return }
        let query = searchField.stringValue
        // Build the list uncapped first, then trim it by the height it pushes
        // past the 90% screen cap. Measuring the rendered content (rather than
        // guessing the rows' overhead) keeps the whole popover inside the cap.
        resultsController.maximumHeight = nil
        resultsController.updateResults(for: query, currentTimezones: currentTimezones)
        // Show the list when there is something to show, and hide it for an
        // unmatched query so it does not leave a blank gap under the field.
        resultsController.view.isHidden = resultsController.results.isEmpty
        if !resultsController.results.isEmpty, let cap = maximumPanelContentHeight {
            let fullHeight = view.fittingSize.height
            if fullHeight > cap {
                let excess = fullHeight - cap
                resultsController.maximumHeight = max(
                    TimezoneSearchResultsController.rowHeight,
                    resultsController.cappedHeight - excess)
                resultsController.applyHeight()
            }
        }
        // The list just appeared or disappeared, so the panel must grow or
        // shrink with it (the host only resizes on a full render otherwise).
        onContentSizeChanged?()
    }

    /// 90% of the screen, less the popover chrome the host draws around the
    /// content, so the live panel itself stays within the cap.
    private var maximumPanelContentHeight: CGFloat? {
        guard let screenHeight else { return nil }
        return screenHeight * Self.maximumResultsHeightFraction
            - PopoverChromeView.arrowHeight - 2
    }

    /// The screen the popover is shown on, or `nil` when none is known (a
    /// headless run), which leaves the results uncapped.
    private var screenHeight: CGFloat? {
        screenHeightForTesting
            ?? view.window?.screen?.frame.height
            ?? NSScreen.main?.frame.height
    }

    private func clearSearch() {
        searchField?.stringValue = ""
        resultsController?.view.isHidden = true
        onContentSizeChanged?()
    }

    /// Move keyboard focus from the search field into the visible results list,
    /// so Return can add the highlighted row without a click.
    private func focusResults() {
        guard let resultsController, !resultsController.view.isHidden,
              !resultsController.results.isEmpty else { return }
        view.window?.makeFirstResponder(resultsController.focusView)
    }

    /// Move keyboard focus back to the search field (Tab from the results list).
    private func focusSearchField() {
        guard let searchField else { return }
        view.window?.makeFirstResponder(searchField)
    }

    private func addTimezone(_ timezone: String) {
        guard !currentTimezones.contains(timezone) else { return }
        var updated = currentTimezones
        updated.append(timezone)
        currentTimezones = updated
        onUpdateTimezones?(updated)
        searchField?.stringValue = ""
        resultsController?.view.isHidden = true
        onContentSizeChanged?()
    }

    func formatCompactOffset(_ offsetSeconds: Int) -> String {
        let sign = offsetSeconds >= 0 ? "+" : "-"
        let absOffset = abs(offsetSeconds)
        let hours = absOffset / 3600
        let minutes = (absOffset % 3600) / 60

        if minutes == 0 {
            return String(format: "%@%d", sign, hours)
        } else {
            return String(format: "%@%d:%02d", sign, hours, minutes)
        }
    }

    @objc private func openDateTimeSettings() {
        onOpenDateTimeSettings()
    }
}

/// The time string for one zone, following the user's time format and custom
/// pattern. Shared by the header, the scrubber label and every zone row so they
/// cannot drift.
private func worldClockTimeString(_ date: Date,
                                  timeZone: TimeZone,
                                  timeFormat: TimeConfiguration.Format,
                                  showSeconds: Bool,
                                  customPattern: String?) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = timeZone

    if timeFormat == .custom, let customPattern, !customPattern.isEmpty {
        formatter.dateFormat = customPattern
    } else {
        let template: String
        switch timeFormat {
        case .twentyFourHour:
            template = showSeconds ? "HHmms" : "HHmm"
        case .ampm:
            template = showSeconds ? "jmms" : "jmm"
        case .custom:
            template = showSeconds ? "HHmms" : "HHmm"
        }
        formatter.setLocalizedDateFormatFromTemplate(template)
    }

    return formatter.string(from: date)
}

/// Controller for displaying and selecting from timezone search results.
///
/// It lists every match, including the zones already in the user's list. Those
/// are shown disabled and marked "Already added", so a default like Singapore
/// reads as present rather than missing. The list fits its content up to the
/// space left under the 90% screen cap and scrolls beyond that, the same way the
/// Wi-Fi network list does.
@MainActor
final class TimezoneSearchResultsController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    /// One search hit, and whether it is already in the user's list, with the
    /// zone's current UTC offset formatted for the row's right-hand column.
    struct Result: Equatable {
        let identifier: String
        let displayName: String
        let isAlreadyAdded: Bool
        let utcOffset: String
    }

    /// The most the list may grow before it scrolls. Set by the content
    /// controller from the 90% screen cap minus the surrounding rows, so the
    /// whole popover stays within the cap. `nil` leaves it uncapped.
    var maximumHeight: CGFloat?

    /// The height of one result row.
    static let rowHeight: CGFloat = 22

    let view: NSScrollView
    private let tableView: TimezoneResultsTableView
    private let onSelect: (String) -> Void
    private(set) var results: [Result] = []
    private var theme: BarTheme
    /// Tab pressed in the list: move focus back to the search field.
    var onTab: (() -> Void)?
    /// Escape pressed in the list: clear the search.
    var onEscape: (() -> Void)?
    /// The view that takes keyboard focus when Tab enters the list.
    var focusView: NSView { tableView }
    /// The scroll view's height, driven by the row count so the visible results
    /// list has a real height under Auto Layout (a plain frame change is ignored
    /// once the view is an arranged subview).
    private var heightConstraint: NSLayoutConstraint?

    /// The height the list is currently pinned to. Exposed for tests that assert
    /// the screen cap without depending on a laid-out frame.
    var cappedHeight: CGFloat { heightConstraint?.constant ?? 0 }

    init(onSelect: @escaping (String) -> Void, theme: BarTheme) {
        self.onSelect = onSelect
        self.theme = theme

        tableView = TimezoneResultsTableView(frame: NSRect(x: 0, y: 0, width: 272, height: 6 * Self.rowHeight))
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .regular
        // `.fullWidth` (the default is `.automatic`, which becomes the inset style
        // on macOS 11+) keeps the result rows flush with the leading inset.
        tableView.style = .fullWidth
        tableView.backgroundColor = theme.popoverPalette.background
        tableView.gridStyleMask = []
        // One column that fills the scroll view: without this the 272pt column
        // is wider than the ~248pt content area and scrolls sideways.
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timezone"))
        column.width = 272
        tableView.addTableColumn(column)
        tableView.intercellSpacing = NSSize(width: 0, height: 2)

        view = NSScrollView(frame: NSRect(x: 0, y: 0, width: 272, height: 132))
        view.documentView = tableView
        view.hasVerticalScroller = true
        view.hasHorizontalScroller = false
        view.autohidesScrollers = true
        view.translatesAutoresizingMaskIntoConstraints = false
        let height = view.heightAnchor.constraint(equalToConstant: Self.rowHeight)
        height.isActive = true
        heightConstraint = height

        super.init()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.onReturnKey = { [weak self] in
            self?.selectCurrentRow()
        }
        tableView.onTab = { [weak self] in self?.onTab?() }
        tableView.onEscape = { [weak self] in self?.onEscape?() }
        tableView.onMoveSelection = { [weak self] delta in self?.moveSelection(by: delta) }
    }

    /// Move the keyboard selection by `delta`, skipping already-added rows so
    /// the arrow keys always land on a row that can be added.
    func moveSelection(by delta: Int) {
        guard !results.isEmpty, delta != 0 else { return }
        var index = tableView.selectedRow
        if index < 0 { index = delta > 0 ? -1 : results.count }
        var next = index + delta
        while next >= 0, next < results.count, results[next].isAlreadyAdded {
            next += delta
        }
        guard next >= 0, next < results.count else { return }
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    func updateResults(for query: String, currentTimezones: [String], at date: Date = Date()) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            tableView.reloadData()
            setHeight(Self.rowHeight)
            return
        }

        let lowercasedQuery = trimmed.lowercased()
        let addedSet = Set(currentTimezones)

        // Rank every match — including zones already added — so a city-name
        // match comes before an identifier-only match, and a name that starts
        // with the query comes first of all. Nothing is truncated here: the list
        // shows every match and scrolls once it exceeds the screen cap.
        var ranked: [(result: Result, score: Int)] = []
        for id in TimeZone.knownTimeZoneIdentifiers {
            let displayName = WorldClock.friendlyName(for: id)
            let lowercasedName = displayName.lowercased()
            let matchesName = lowercasedName.contains(lowercasedQuery)
            let matchesId = id.lowercased().contains(lowercasedQuery)
            guard matchesName || matchesId else { continue }

            let score: Int
            if lowercasedName == lowercasedQuery {
                score = 0
            } else if lowercasedName.hasPrefix(lowercasedQuery) {
                score = 1
            } else if matchesName {
                score = 2
            } else {
                score = 3
            }
            let offsetSeconds = TimeZone(identifier: id)?.secondsFromGMT(for: date) ?? 0
            ranked.append((Result(identifier: id,
                                  displayName: displayName,
                                  isAlreadyAdded: addedSet.contains(id),
                                  utcOffset: WorldClock.utcOffsetLabel(forOffsetSeconds: offsetSeconds)), score))
        }

        ranked.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.result.displayName.localizedCaseInsensitiveCompare($1.result.displayName) == .orderedAscending
        }
        results = ranked.map(\.result)

        tableView.reloadData()
        applyHeight()
    }

    /// Size the list to its content, clamped to `maximumHeight`, so it scrolls
    /// once there are more matches than fit.
    func applyHeight() {
        let contentHeight = CGFloat(results.count) * Self.rowHeight
        setHeight(min(contentHeight, maximumHeight ?? contentHeight))
    }

    private func setHeight(_ height: CGFloat) {
        heightConstraint?.constant = max(Self.rowHeight, height)
    }

    /// Recolour the list after the bar theme changes while the popover is open,
    /// so the rows do not keep the colours they were first built with.
    func restyle(_ theme: BarTheme) {
        self.theme = theme
        tableView.backgroundColor = theme.popoverPalette.background
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        TimezoneResultRowView()
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < results.count else { return nil }

        let result = results[row]
        let font = NSFont.systemFont(ofSize: 11)
        let text = NSMutableAttributedString(
            string: result.displayName,
            attributes: [.font: font, .foregroundColor: theme.popoverPalette.label])
        if result.isAlreadyAdded {
            text.append(NSAttributedString(
                string: "  Already added",
                attributes: [.font: font, .foregroundColor: theme.popoverPalette.secondary]))
        }

        let cell = NSTableCellView()

        // The city name stays in one left-aligned column; the current UTC offset
        // is a separate, right-aligned field that hugs its own width, so rows
        // line up whatever the offset is (UTC+7, UTC-3:30, ...).
        let nameField = NSTextField(labelWithString: "")
        nameField.attributedStringValue = text
        nameField.lineBreakMode = .byTruncatingTail
        nameField.maximumNumberOfLines = 1
        nameField.setAccessibilityLabel(accessibilityLabel(for: result))
        nameField.translatesAutoresizingMaskIntoConstraints = false
        // The name gives way first so the offset never truncates.
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let offsetField = NSTextField(labelWithString: result.utcOffset)
        offsetField.font = font
        offsetField.textColor = theme.popoverPalette.secondary
        offsetField.identifier = BarPopoverContentController.secondaryIdentifier
        offsetField.alignment = .right
        offsetField.translatesAutoresizingMaskIntoConstraints = false
        offsetField.setContentHuggingPriority(.required, for: .horizontal)
        offsetField.setContentCompressionResistancePriority(.required, for: .horizontal)

        cell.addSubview(nameField)
        cell.addSubview(offsetField)

        NSLayoutConstraint.activate([
            nameField.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            nameField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            nameField.trailingAnchor.constraint(lessThanOrEqualTo: offsetField.leadingAnchor, constant: -8),

            offsetField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            offsetField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        cell.setAccessibilityLabel(accessibilityLabel(for: result))
        // An already-added row is informational, not an action.
        cell.setAccessibilityRole(result.isAlreadyAdded ? .staticText : .button)

        return cell
    }

    /// An already-added result cannot be selected or added again.
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row >= 0, row < results.count else { return false }
        return !results[row].isAlreadyAdded
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return Self.rowHeight
    }

    private func accessibilityLabel(for result: Result) -> String {
        let base = "\(result.displayName), \(result.utcOffset)"
        return result.isAlreadyAdded ? "\(base), already added" : base
    }

    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        selectCurrentRow()
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn, row: Int) {
        guard row >= 0, row < results.count, !results[row].isAlreadyAdded else { return }
        onSelect(results[row].identifier)
    }

    private func selectCurrentRow() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < results.count,
              !results[selectedRow].isAlreadyAdded else { return }
        onSelect(results[selectedRow].identifier)
    }
}
