import AppKit
import DivotCore

/// A popover anchored to the bar's time item that shows world clock entries for added timezones.
@MainActor
public final class WorldClockPopoverController {
    private let openDateTimeSettings: @MainActor () -> Void
    private let getConfiguration: @MainActor () -> DivotConfiguration

    private let host = BarPopoverHost()
    private var content: WorldClockPopoverContentController?

    public init(openDateTimeSettings: @escaping @MainActor () -> Void,
               getConfiguration: @escaping @MainActor () -> DivotConfiguration) {
        self.openDateTimeSettings = openDateTimeSettings
        self.getConfiguration = getConfiguration
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Show the popover below `view` with the current time and added timezones.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()

        let config = getConfiguration()
        let controller = WorldClockPopoverContentController()
        controller.theme = theme
        controller.onOpenDateTimeSettings = { [weak self] in self?.openDateTimeSettings() }

        host.present(controller, relativeTo: view)
        self.content = controller

        controller.render(timezones: config.widgets.time.timezones,
                         timeFormat: config.widgets.time.timeFormat,
                         showSeconds: config.widgets.time.seconds,
                         customPattern: config.widgets.time.customPattern)
    }

    /// Hide the popover and clear the controller reference.
    public func dismiss() {
        host.dismiss()
        content = nil
    }

    /// Toggle the popover: dismiss if open, present otherwise.
    public func toggle(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        if host.isShown {
            dismiss()
        } else {
            present(relativeTo: view, theme: theme)
        }
    }

    /// Apply a theme to the open popover without closing it.
    public func applyTheme(_ theme: BarTheme) {
        content?.apply(theme: theme)
    }

    private func handleClosed() {
        content = nil
    }
}

/// The content controller for the world clock popover.
@MainActor
final class WorldClockPopoverContentController: BarPopoverContentController {
    var onOpenDateTimeSettings: @MainActor () -> Void = {}

    override func loadView() {
        super.loadView()
        stack.addArrangedSubview(separator())

        let settingsButton = NSButton()
        settingsButton.setButtonType(.momentaryPushIn)
        settingsButton.title = "Open Date & Time Settings..."
        settingsButton.font = .systemFont(ofSize: 12)
        settingsButton.identifier = Self.linkIdentifier
        settingsButton.bezelStyle = .recessed
        settingsButton.target = self
        settingsButton.action = #selector(openDateTimeSettings)
        stack.addArrangedSubview(settingsButton)
    }

    func render(timezones: [String], timeFormat: TimeConfiguration.Format, showSeconds: Bool, customPattern: String? = nil) {
        clearRows()

        let now = Date()
        let entries = WorldClock.entries(for: timezones)

        let localLabel = NSTextField(labelWithString: "Local")
        localLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        localLabel.textColor = theme.popoverPalette.label
        localLabel.identifier = Self.headerIdentifier
        stack.addArrangedSubview(localLabel)

        let localTime = NSTextField(labelWithString: formatLocalTime(now, timeFormat: timeFormat, showSeconds: showSeconds, customPattern: customPattern))
        localTime.font = .systemFont(ofSize: 12)
        localTime.textColor = theme.popoverPalette.secondary
        localTime.identifier = Self.secondaryIdentifier
        stack.addArrangedSubview(localTime)

        if !entries.isEmpty {
            stack.addArrangedSubview(separator())
        }

        for entry in entries {
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

            let stack = NSStackView(views: [label, info])
            stack.orientation = .vertical
            stack.spacing = 2
            stack.alignment = .leading
            stack.translatesAutoresizingMaskIntoConstraints = false

            self.stack.addArrangedSubview(stack)
        }

        if entries.isEmpty {
            let noTimezones = NSTextField(labelWithString: "Click the time to add timezones")
            noTimezones.font = .systemFont(ofSize: 11)
            noTimezones.textColor = theme.popoverPalette.secondary
            noTimezones.identifier = Self.secondaryIdentifier
            stack.addArrangedSubview(noTimezones)
            stack.addArrangedSubview(separator())
        }
    }

    private func formatLocalTime(_ date: Date, timeFormat: TimeConfiguration.Format, showSeconds: Bool, customPattern: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current

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

        let offset = TimeZone.current.secondsFromGMT(for: date)
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        let offsetStr = String(format: "%+03d:%02d", hours, minutes)

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
