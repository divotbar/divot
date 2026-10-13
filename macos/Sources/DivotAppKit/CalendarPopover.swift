import AppKit
import DivotCore

/// A popover anchored to the bar's date item that shows a calendar month grid
/// with navigation and today highlighting.
///
/// Opening the popover always starts on the current month. Back/forward buttons
/// navigate by one month; a Today button jumps to the current month. The layout
/// respects the system's locale and calendar settings for week start and
/// weekday names. The last row opens the Date & Time pane. The popover look
/// and lifecycle come from the shared `BarPopoverHost`.
@MainActor
public final class CalendarPopoverController {
    private let openDateTimeSettings: @MainActor () -> Void

    private let host = BarPopoverHost()
    private var content: CalendarPopoverContentController?
    private var currentMonth: CalendarMonth = .today()
    private var dayChangeObserver: NSObjectProtocol?

    public init(openDateTimeSettings: @escaping @MainActor () -> Void) {
        self.openDateTimeSettings = openDateTimeSettings
        host.onClose = { [weak self] in self?.handleClosed() }
    }

    /// Show the popover below `view` starting on the current month.
    public func present(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        dismiss()
        currentMonth = .today()
        let controller = CalendarPopoverContentController()
        controller.theme = theme
        controller.onMonthChanged = { [weak self] month in self?.currentMonth = month; self?.render() }
        controller.onTodayTapped = { [weak self] in
            self?.currentMonth = .today()
            self?.render()
        }
        controller.onOpenDateTimeSettings = { [weak self] in self?.openDateTimeSettings() }

        host.present(controller, relativeTo: view)
        self.content = controller
        render()

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.render()
        }
        dayChangeObserver = observer
    }

    /// A click on the date item. When this item already owns the open popover
    /// the click closes it; otherwise it opens the popover.
    public func toggle(relativeTo view: NSView, theme: BarTheme = .systemDefault) {
        if host.itemClickCloses(relativeTo: view) {
            dismiss()
        } else {
            present(relativeTo: view, theme: theme)
        }
    }

    /// Close the popover.
    public func dismiss() {
        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        dayChangeObserver = nil
        host.dismiss()
        content = nil
    }

    /// Whether the popover is currently shown.
    public var isShown: Bool { host.isShown }

    /// The popover closed for any reason.
    private func handleClosed() {
        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        dayChangeObserver = nil
        content = nil
    }

    /// Update the content for the current month.
    private func render() {
        guard let content else { return }
        let layout = CalendarMonthLayout.`for`(currentMonth)
        content.update(layout)
        host.resize(to: content.preferredSize)
    }
}

/// The popover's content: a header with month/year, navigation buttons,
/// a weekday row, day grid, today button, and settings row.
@MainActor
final class CalendarPopoverContentController: BarPopoverContentController {
    var onMonthChanged: ((CalendarMonth) -> Void)?
    var onTodayTapped: (() -> Void)?
    var onOpenDateTimeSettings: (() -> Void)?

    private let headerLabel = NSTextField(labelWithString: "")
    private let prevButton = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil) ?? NSImage(), target: nil, action: nil)
    private let nextButton = NSButton(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage(), target: nil, action: nil)
    private let todayButton = NSButton(title: "Today", target: nil, action: nil)
    private let weekdayStack = NSStackView()
    private var dayGridView: NSView?
    private var currentLayout: CalendarMonthLayout?

    override func loadView() {
        super.loadView()
        configure()
    }

    private func configure() {
        clearRows()

        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = theme.popoverPalette.label
        headerLabel.identifier = Self.headerIdentifier
        headerLabel.alignment = .left

        prevButton.isBordered = false
        prevButton.bezelStyle = .inline
        prevButton.setAccessibilityLabel("Previous month")
        prevButton.target = self
        prevButton.action = #selector(previousMonth)

        nextButton.isBordered = false
        nextButton.bezelStyle = .inline
        nextButton.setAccessibilityLabel("Next month")
        nextButton.target = self
        nextButton.action = #selector(nextMonth)

        todayButton.isBordered = false
        todayButton.bezelStyle = .inline
        todayButton.font = .systemFont(ofSize: 12)
        todayButton.setAccessibilityLabel("Today")
        todayButton.target = self
        todayButton.action = #selector(todayTapped)

        let headerRow = NSStackView(views: [prevButton, headerLabel, nextButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        headerRow.distribution = .fill
        headerLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(headerRow)

        weekdayStack.orientation = .horizontal
        weekdayStack.alignment = .centerY
        weekdayStack.distribution = .fillEqually
        weekdayStack.spacing = 0
        stack.addArrangedSubview(weekdayStack)

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(todayButton)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Date & Time Settings...", action: #selector(openDateTimeSettings)))
    }

    /// Update the calendar display for a new month layout.
    func update(_ layout: CalendarMonthLayout) {
        currentLayout = layout
        headerLabel.stringValue = layout.monthYearString

        weekdayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for name in layout.weekdayNames {
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = theme.popoverPalette.secondary
            label.identifier = Self.secondaryIdentifier
            label.alignment = .center
            weekdayStack.addArrangedSubview(label)
        }

        if let old = dayGridView {
            stack.removeArrangedSubview(old)
            old.removeFromSuperview()
        }

        let gridView = buildDayGrid(layout)
        dayGridView = gridView
        stack.insertArrangedSubview(gridView, at: 2)
    }

    /// Build the grid of day buttons.
    private func buildDayGrid(_ layout: CalendarMonthLayout) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let gridView = NSView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gridView)

        let cellWidth: CGFloat = 28
        let cellHeight: CGFloat = 24
        let spacing: CGFloat = 2

        var x: CGFloat = 0
        var y: CGFloat = 0

        for (weekIdx, week) in layout.weeks.enumerated() {
            for (dayIdx, calDay) in week.enumerated() {
                let button = NSButton(title: "\(calDay.day)", target: self, action: nil)
                button.isBordered = false
                button.bezelStyle = .inline
                button.font = .systemFont(ofSize: 11)
                button.translatesAutoresizingMaskIntoConstraints = false

                let isToday = isToday(calDay.date)
                let dayFormatter = DateFormatter()
                dayFormatter.locale = .current
                dayFormatter.dateStyle = .long
                let dayLabel = dayFormatter.string(from: calDay.date)
                let accessibilityLabel = isToday ? "\(dayLabel), today" : dayLabel
                button.setAccessibilityLabel(accessibilityLabel)

                if isToday {
                    button.contentTintColor = theme.accent
                    button.bezelColor = theme.accent
                    button.font = .systemFont(ofSize: 11, weight: .semibold)
                }

                if !calDay.isCurrentMonth {
                    button.alphaValue = 0.4
                }

                gridView.addSubview(button)

                x = CGFloat(dayIdx) * (cellWidth + spacing)
                y = CGFloat(weekIdx) * (cellHeight + spacing)

                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: gridView.leadingAnchor, constant: x),
                    button.topAnchor.constraint(equalTo: gridView.topAnchor, constant: y),
                    button.widthAnchor.constraint(equalToConstant: cellWidth),
                    button.heightAnchor.constraint(equalToConstant: cellHeight)
                ])
            }
        }

        let gridWidth = CGFloat(7) * cellWidth + CGFloat(6) * spacing
        let gridHeight = CGFloat(layout.weeks.count) * cellHeight + CGFloat(layout.weeks.count - 1) * spacing

        NSLayoutConstraint.activate([
            gridView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gridView.topAnchor.constraint(equalTo: container.topAnchor),
            gridView.widthAnchor.constraint(equalToConstant: gridWidth),
            gridView.heightAnchor.constraint(equalToConstant: gridHeight),
            container.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
            container.topAnchor.constraint(equalTo: gridView.topAnchor),
            container.widthAnchor.constraint(equalTo: gridView.widthAnchor),
            container.heightAnchor.constraint(equalTo: gridView.heightAnchor)
        ])

        return container
    }

    @objc private func previousMonth() {
        if let layout = currentLayout {
            onMonthChanged?(layout.month.previous())
        }
    }

    @objc private func nextMonth() {
        if let layout = currentLayout {
            onMonthChanged?(layout.month.next())
        }
    }

    @objc private func todayTapped() {
        onTodayTapped?()
    }

    @objc private func openDateTimeSettings() {
        onOpenDateTimeSettings?()
    }
}
