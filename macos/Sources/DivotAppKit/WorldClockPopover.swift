import AppKit
import DivotCore

/// A popover anchored to the bar's time item that shows world clock entries for added timezones.
@MainActor
public final class WorldClockPopoverController {
    private let openDateTimeSettings: @MainActor () -> Void
    private let getConfiguration: @MainActor () -> DivotConfiguration
    private let updateTimezones: @MainActor ([String]) -> Void

    private let host = BarPopoverHost()
    private var content: WorldClockPopoverContentController?
    private var refreshTimer: Timer?

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

        let config = getConfiguration()
        let controller = WorldClockPopoverContentController()
        controller.theme = theme
        controller.onOpenDateTimeSettings = { [weak self] in self?.openDateTimeSettings() }
        controller.onUpdateTimezones = { [weak self] timezones in
            self?.updateTimezones(timezones)
        }

        host.present(controller, relativeTo: view)
        self.content = controller

        controller.render(timezones: config.widgets.time.timezones,
                         timeFormat: config.widgets.time.timeFormat,
                         showSeconds: config.widgets.time.seconds,
                         customPattern: config.widgets.time.customPattern)

        startRefreshTimer()
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshContent()
            }
        }
    }

    private func refreshContent() {
        guard let content = content else { return }
        let config = getConfiguration()
        content.render(timezones: config.widgets.time.timezones,
                      timeFormat: config.widgets.time.timeFormat,
                      showSeconds: config.widgets.time.seconds,
                      customPattern: config.widgets.time.customPattern)
    }

    /// Hide the popover and clear the controller reference.
    public func dismiss() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
        refreshTimer?.invalidate()
        refreshTimer = nil
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

        let localLabel = NSTextField(labelWithString: "Local (\(localTimeZone.identifier))")
        localLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        localLabel.textColor = theme.popoverPalette.label
        localLabel.identifier = Self.headerIdentifier
        stack.addArrangedSubview(localLabel)

        let localTime = NSTextField(labelWithString: formatLocalTime(now, timeZone: localTimeZone, timeFormat: timeFormat, showSeconds: showSeconds, customPattern: customPattern))
        localTime.font = .systemFont(ofSize: 12)
        localTime.textColor = theme.popoverPalette.secondary
        localTime.identifier = Self.secondaryIdentifier
        stack.addArrangedSubview(localTime)

        if !entries.isEmpty {
            stack.addArrangedSubview(separator())
        }

        for (index, entry) in entries.enumerated() {
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false

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
            removeButton.tag = index
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

            self.stack.addArrangedSubview(rowStack)
        }

        if !entries.isEmpty {
            stack.addArrangedSubview(separator())
        }

        let addContainer = NSView()
        addContainer.translatesAutoresizingMaskIntoConstraints = false

        let addLabel = NSTextField(labelWithString: "Add timezone…")
        addLabel.font = .systemFont(ofSize: 12)
        addLabel.textColor = theme.popoverPalette.label
        addLabel.identifier = Self.headerIdentifier
        addLabel.translatesAutoresizingMaskIntoConstraints = false

        let search = NSSearchField()
        search.placeholderString = "Search (e.g., Tokyo, Asia/Tokyo)"
        search.font = .systemFont(ofSize: 11)
        search.translatesAutoresizingMaskIntoConstraints = false
        search.target = self
        search.action = #selector(searchTimezones(_:))
        search.searchMenuTemplate = makeTimezoneMenu()
        search.setAccessibilityLabel("Add timezone")
        self.searchField = search
        styleSearchField()

        let addStack = NSStackView(views: [addLabel])
        addStack.orientation = .vertical
        addStack.spacing = 4
        addStack.alignment = .leading
        addStack.translatesAutoresizingMaskIntoConstraints = false

        addStack.addArrangedSubview(search)
        self.stack.addArrangedSubview(addStack)
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
        let index = sender.tag
        guard index >= 0 && index < currentTimezones.count else { return }
        var updated = currentTimezones
        updated.remove(at: index)
        currentTimezones = updated
        onUpdateTimezones?(updated)
    }

    @objc private func searchTimezones(_ sender: NSSearchField) {
        let query = sender.stringValue.lowercased()
        guard !query.isEmpty else { return }

        let allIds = TimeZone.knownTimeZoneIdentifiers
        let matches = allIds.filter { id in
            let parts = id.lowercased().components(separatedBy: "/")
            return parts.contains { $0.contains(query) } || id.lowercased().contains(query)
        }

        if !matches.isEmpty {
            let selected = matches[0]
            if !currentTimezones.contains(selected) {
                var updated = currentTimezones
                updated.append(selected)
                currentTimezones = updated
                onUpdateTimezones?(updated)
                sender.stringValue = ""
            }
        }
    }

    private func makeTimezoneMenu() -> NSMenu {
        let menu = NSMenu()
        let allIds = TimeZone.knownTimeZoneIdentifiers.prefix(20)
        for id in allIds {
            let item = NSMenuItem(title: id, action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        return menu
    }

    private func formatLocalTime(_ date: Date, timeZone: TimeZone, timeFormat: TimeConfiguration.Format, showSeconds: Bool, customPattern: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone

        let dateTimeStr: String
        if timeFormat == .custom, let customPattern = customPattern, !customPattern.isEmpty {
            formatter.dateFormat = customPattern
            dateTimeStr = formatter.string(from: date)
        } else {
            let template: String
            switch timeFormat {
            case .twentyFourHour:
                template = showSeconds ? "yMdHHmms" : "yMdHHmm"
            case .ampm:
                template = showSeconds ? "yMdjmms" : "yMdjmm"
            case .custom:
                template = showSeconds ? "yMdHHmms" : "yMdHHmm"
            }
            formatter.setLocalizedDateFormatFromTemplate(template)
            dateTimeStr = formatter.string(from: date)
        }

        let offset = timeZone.secondsFromGMT(for: date)
        let sign = offset >= 0 ? "+" : "-"
        let absOffset = abs(offset)
        let hours = absOffset / 3600
        let minutes = (absOffset % 3600) / 60
        let offsetStr = String(format: "%@%02d:%02d", sign, hours, minutes)

        return "\(dateTimeStr) (UTC\(offsetStr))"
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
