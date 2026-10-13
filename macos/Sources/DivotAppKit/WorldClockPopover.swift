import AppKit
import DivotCore

/// NSSearchField subclass that handles Escape key to clear search
@MainActor
private final class SearchFieldWithEscape: NSSearchField {
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// NSTableView subclass that handles Return/arrow keys for results navigation
@MainActor
private final class TimezoneResultsTableView: NSTableView {
    var onReturnKey: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36: // Return key
            onReturnKey?()
        case 125: // Down arrow
            selectRowIndexes(NSIndexSet(index: min(selectedRow + 1, numberOfRows - 1)) as IndexSet, byExtendingSelection: false)
        case 126: // Up arrow
            selectRowIndexes(NSIndexSet(index: max(selectedRow - 1, 0)) as IndexSet, byExtendingSelection: false)
        default:
            super.keyDown(with: event)
        }
    }
}

/// A popover anchored to the bar's time item that shows world clock entries for added timezones.
@MainActor
public final class WorldClockPopoverController {
    private let openDateTimeSettings: @MainActor () -> Void
    private let getConfiguration: @MainActor () -> DivotConfiguration
    private let updateTimezones: @MainActor ([String]) -> Void

    private let host = BarPopoverHost()
    private var content: WorldClockPopoverContentController?

    public init(openDateTimeSettings: @escaping @MainActor () -> Void,
               getConfiguration: @escaping @MainActor () -> DivotConfiguration,
               updateTimezones: @escaping @MainActor ([String]) -> Void) {
        self.openDateTimeSettings = openDateTimeSettings
        self.getConfiguration = getConfiguration
        self.updateTimezones = updateTimezones
        host.onClose = { [weak self] in self?.handleClosed() }
    }

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
        host.resize(to: content.preferredSize)
    }

    private func timezoneListFromConfiguration(_ config: DivotConfiguration) -> [String] {
        if let configuredList = config.widgets.time.timezones {
            return configuredList
        }

        let defaults = ["America/Los_Angeles", "Europe/London", "Asia/Singapore"]
        let localZone = TimeZone.current.identifier
        return defaults.filter { $0 != localZone }
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

    private var currentTimezones: [String] = []
    private var searchField: NSSearchField?
    private var resultsController: TimezoneSearchResultsController?
    private var searchObserver: NSObjectProtocol?

    override func loadView() {
        super.loadView()

        let settingsButton = NSButton()
        settingsButton.setButtonType(.momentaryPushIn)
        settingsButton.title = "Open Date & Time Settings..."
        settingsButton.font = .systemFont(ofSize: 12)
        settingsButton.identifier = Self.linkIdentifier
        settingsButton.bezelStyle = .recessed
        settingsButton.target = self
        settingsButton.action = #selector(openDateTimeSettings)

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(settingsButton)
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

        let now = date
        let entries = WorldClock.entries(for: timezones, at: date,
                                         localTimeZone: localTimeZone, calendar: calendar)

        let localOffset = localTimeZone.secondsFromGMT(for: date)
        let localOffsetStr = formatCompactOffset(localOffset)
        let timeAndOffsetText = "\(formatTime(now, timeZone: localTimeZone, timeFormat: timeFormat, showSeconds: showSeconds, customPattern: customPattern))  UTC\(localOffsetStr)"
        let localTime = NSTextField(labelWithString: timeAndOffsetText)
        localTime.font = .systemFont(ofSize: 14, weight: .semibold)
        localTime.textColor = theme.popoverPalette.label
        localTime.identifier = Self.headerIdentifier
        stack.addArrangedSubview(localTime)

        let localCityLabel = NSTextField(labelWithString: friendlyCityName(localTimeZone.identifier))
        localCityLabel.font = .systemFont(ofSize: 10)
        localCityLabel.textColor = theme.popoverPalette.secondary
        localCityLabel.identifier = Self.secondaryIdentifier
        stack.addArrangedSubview(localCityLabel)

        if !entries.isEmpty {
            stack.addArrangedSubview(separator())
        }

        for entry in entries {
            let label = NSTextField(labelWithString: entry.displayName)
            label.font = .systemFont(ofSize: 12)
            label.textColor = theme.popoverPalette.label
            label.identifier = Self.headerIdentifier
            label.translatesAutoresizingMaskIntoConstraints = false

            let timeText = formatTime(entry.date, timeZone: TimeZone(identifier: entry.timezone)!, timeFormat: timeFormat, showSeconds: showSeconds, customPattern: customPattern)
            let offsetText = WorldClock.formatHourOffset(entry.hourOffset)
            let dayText = entry.dayLabel.map { " \($0)" } ?? ""

            let info = NSTextField(labelWithString: "\(timeText) (\(offsetText))\(dayText)")
            info.font = .systemFont(ofSize: 11)
            info.textColor = theme.popoverPalette.secondary
            info.identifier = Self.secondaryIdentifier
            info.translatesAutoresizingMaskIntoConstraints = false

            let removeButton = NSButton()
            removeButton.setButtonType(.momentaryPushIn)
            removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove \(entry.displayName)")
            removeButton.bezelStyle = .circular
            removeButton.font = .systemFont(ofSize: 11)
            removeButton.translatesAutoresizingMaskIntoConstraints = false
            removeButton.identifier = NSUserInterfaceItemIdentifier(entry.timezone)
            removeButton.target = self
            removeButton.action = #selector(removeTimezone(_:))
            removeButton.setAccessibilityLabel("Remove \(entry.displayName)")
            removeButton.toolTip = "Remove \(entry.displayName)"

            let textStack = NSStackView(views: [label, info])
            textStack.orientation = .vertical
            textStack.spacing = 2
            textStack.alignment = .leading
            textStack.translatesAutoresizingMaskIntoConstraints = false

            let rowStack = NSStackView(views: [textStack, removeButton])
            rowStack.orientation = .horizontal
            rowStack.spacing = 8
            rowStack.alignment = .centerY
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowStack.distribution = .fill

            stack.addArrangedSubview(rowStack)
        }

        if entries.isEmpty {
            let hintLabel = NSTextField(labelWithString: "No other timezones. Add one below.")
            hintLabel.font = .systemFont(ofSize: 11)
            hintLabel.textColor = theme.popoverPalette.secondary
            hintLabel.identifier = Self.secondaryIdentifier
            stack.addArrangedSubview(hintLabel)
        } else {
            stack.addArrangedSubview(separator())
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
            self?.updateSearchResults()
        }

        let resultsController = TimezoneSearchResultsController(
            onSelect: { [weak self] timezone in
                self?.addTimezone(timezone)
            },
            theme: theme,
            currentTimezones: timezones,
            friendlyCityName: { [weak self] tzId in
                self?.friendlyCityName(tzId) ?? ""
            }
        )
        self.resultsController = resultsController

        let addStack = NSStackView(views: [addLabel, search])
        addStack.orientation = .vertical
        addStack.spacing = 4
        addStack.alignment = .leading
        addStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(addStack)

        resultsController.view.isHidden = true
        stack.addArrangedSubview(resultsController.view)
    }

    /// Recolour the search field's text and placeholder from the theme, so the
    /// placeholder clears the same contrast floor as the other secondary text
    /// (the system default placeholder colour is intentionally dimmer).
    override func restyle(_ theme: BarTheme) {
        super.restyle(theme)
        styleSearchField()
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
        resultsController.updateResults(for: query, excluding: currentTimezones)
        resultsController.view.isHidden = query.isEmpty
    }

    @objc private func searchTextDidChange(_ notification: Notification) {
        updateSearchResults()
    }

    private func clearSearch() {
        searchField?.stringValue = ""
        resultsController?.view.isHidden = true
    }

    private func addTimezone(_ timezone: String) {
        guard !currentTimezones.contains(timezone) else { return }
        var updated = currentTimezones
        updated.append(timezone)
        currentTimezones = updated
        onUpdateTimezones?(updated)
        searchField?.stringValue = ""
        resultsController?.view.isHidden = true
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

    private func friendlyCityName(_ tzIdentifier: String) -> String {
        let mapping: [String: String] = [
            "America/Los_Angeles": "San Francisco"
        ]
        if let friendlyName = mapping[tzIdentifier] {
            return friendlyName
        }
        let parts = tzIdentifier.components(separatedBy: "/")
        return (parts.last ?? tzIdentifier).replacingOccurrences(of: "_", with: " ")
    }

    private func formatTime(_ date: Date, timeZone: TimeZone, timeFormat: TimeConfiguration.Format, showSeconds: Bool, customPattern: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone

        if timeFormat == .custom, let customPattern = customPattern, !customPattern.isEmpty {
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

    @objc private func openDateTimeSettings() {
        onOpenDateTimeSettings()
    }
}

/// Controller for displaying and selecting from timezone search results.
@MainActor
private final class TimezoneSearchResultsController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let view: NSScrollView
    private let tableView: TimezoneResultsTableView
    private let onSelect: (String) -> Void
    private(set) var results: [(identifier: String, displayName: String)] = []
    private var theme: BarTheme
    private let currentTimezones: [String]
    private let friendlyCityName: (String) -> String

    init(onSelect: @escaping (String) -> Void, theme: BarTheme, currentTimezones: [String], friendlyCityName: @escaping (String) -> String = { _ in "" }) {
        self.onSelect = onSelect
        self.theme = theme
        self.currentTimezones = currentTimezones
        self.friendlyCityName = friendlyCityName

        tableView = TimezoneResultsTableView(frame: NSRect(x: 0, y: 0, width: 272, height: 6 * 22))
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = theme.popoverPalette.background
        tableView.gridStyleMask = []

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timezone"))
        column.width = 272
        tableView.addTableColumn(column)

        view = NSScrollView(frame: NSRect(x: 0, y: 0, width: 272, height: 132))
        view.documentView = tableView
        view.hasVerticalScroller = true
        view.autohidesScrollers = true
        view.translatesAutoresizingMaskIntoConstraints = false

        super.init()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.onReturnKey = { [weak self] in
            self?.selectCurrentRow()
        }
    }

    func updateResults(for query: String, excluding: [String] = []) {
        if query.isEmpty {
            results = []
        } else {
            let lowercasedQuery = query.lowercased()
            let excludingSet = Set(excluding)
            let allIds = TimeZone.knownTimeZoneIdentifiers
            var matches: [(identifier: String, displayName: String)] = []

            for id in allIds {
                guard !excludingSet.contains(id) else { continue }

                let parts = id.components(separatedBy: "/")
                let displayName = (parts.last ?? id).replacingOccurrences(of: "_", with: " ")
                let matchesId = id.lowercased().contains(lowercasedQuery)
                let matchesDisplay = displayName.lowercased().contains(lowercasedQuery)

                if matchesId || matchesDisplay {
                    matches.append((identifier: id, displayName: displayName))
                }

                if matches.count >= 6 {
                    break
                }
            }

            results = matches
        }

        tableView.reloadData()

        let idealHeight = min(CGFloat(results.count) * 22, 132)
        view.frame.size.height = max(22, idealHeight)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < results.count else { return nil }

        let result = results[row]
        let displayText = friendlyCityName(result.identifier)

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: displayText)
        textField.font = .systemFont(ofSize: 11)
        textField.textColor = theme.popoverPalette.label
        textField.setAccessibilityLabel(displayText)
        cell.addSubview(textField)

        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.topAnchor.constraint(equalTo: cell.topAnchor),
            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])

        cell.setAccessibilityLabel(displayText)
        cell.setAccessibilityRole(.button)

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }

    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        selectCurrentRow()
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn, row: Int) {
        guard row >= 0, row < results.count else { return }
        onSelect(results[row].identifier)
    }

    private func selectCurrentRow() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < results.count else { return }
        onSelect(results[selectedRow].identifier)
    }
}
