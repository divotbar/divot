import AppKit
import DivotCore

/// A custom button for calendar day cells that handles arrow key forwarding.
@MainActor
private class CalendarDayButton: NSButton {
    weak var navigationHandler: CalendarPopoverContentController?

    /// The filled selected-state disc (today), or `nil` for a plain day.
    var highlightFill: NSColor? { didSet { needsDisplay = true } }
    var textColor: NSColor = .labelColor { didSet { needsDisplay = true } }
    var isEmphasised = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        if let fill = highlightFill {
            fill.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: isEmphasised ? .semibold : .regular),
            .foregroundColor: textColor
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: floor((bounds.width - size.width) / 2),
                                             y: floor((bounds.height - size.height) / 2)),
                                 withAttributes: attributes)
    }

    override func keyDown(with event: NSEvent) {
        guard let handler = navigationHandler else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 123, 124, 125, 126: // Arrow keys
            handler.handleArrowKey(event.keyCode)
        default:
            super.keyDown(with: event)
        }
    }
}

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

        // Focus the first day button for keyboard navigation
        if !controller.dayButtons.isEmpty && !controller.dayButtons[0].isEmpty {
            controller.view.window?.makeFirstResponder(controller.dayButtons[0][0])
        }

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.render()
            }
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
    private lazy var todayButton: NSView = linkButton("Today", action: #selector(todayTapped))
    private let weekdayStack = NSStackView()
    private var dayGridView: NSView?
    private var currentLayout: CalendarMonthLayout?
    fileprivate var dayButtons: [[CalendarDayButton]] = []

    /// The grid is a fixed seven columns wide; hug it rather than pad.
    override var minimumContentWidth: CGFloat { 0 }

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


        let headerRow = NSStackView(views: [headerLabel, prevButton, nextButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        headerRow.distribution = .fill
        prevButton.contentTintColor = theme.popoverPalette.label
        nextButton.contentTintColor = theme.popoverPalette.label
        headerLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(headerRow)

        weekdayStack.orientation = .horizontal
        weekdayStack.alignment = .centerY
        weekdayStack.distribution = .gravityAreas
        weekdayStack.spacing = 2
        stack.addArrangedSubview(weekdayStack)

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(todayButton)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(linkButton("Open Date & Time Settings...", action: #selector(openDateTimeSettings)))
    }

    /// Rebuild the grid and header colours when the theme changes after load.
    override func restyle(_ theme: BarTheme) {
        super.restyle(theme)
        prevButton.contentTintColor = theme.popoverPalette.label
        nextButton.contentTintColor = theme.popoverPalette.label
        if let layout = currentLayout { update(layout) }
    }

    /// Update the calendar display for a new month layout.
    func update(_ layout: CalendarMonthLayout) {
        currentLayout = layout
        headerLabel.stringValue = layout.monthYearString

        weekdayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for name in layout.weekdayNames {
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = theme.popoverPalette.secondary
            label.identifier = Self.secondaryIdentifier
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 28).isActive = true
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
        dayButtons = []

        for (weekIdx, week) in layout.weeks.enumerated() {
            var weekButtons: [CalendarDayButton] = []
            for (dayIdx, calDay) in week.enumerated() {
                let button = CalendarDayButton(title: "\(calDay.day)", target: self, action: nil)
                button.isBordered = false
                button.bezelStyle = .inline
                button.font = .systemFont(ofSize: 11)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.navigationHandler = self

                let isToday = isToday(calDay.date)
                let dayFormatter = DateFormatter()
                dayFormatter.locale = .current
                dayFormatter.dateStyle = .long
                let dayLabel = dayFormatter.string(from: calDay.date)
                let accessibilityLabel = isToday ? "\(dayLabel), today" : dayLabel
                button.setAccessibilityLabel(accessibilityLabel)

                button.font = .systemFont(ofSize: 11)
                button.setButtonType(.momentaryPushIn)

                let palette = theme.popoverPalette
                if isToday {
                    button.highlightFill = palette.selected
                    button.textColor = palette.selectedForeground
                    button.isEmphasised = true
                } else {
                    button.textColor = calDay.isCurrentMonth ? palette.label : palette.secondary
                }

                gridView.addSubview(button)
                weekButtons.append(button)

                x = CGFloat(dayIdx) * (cellWidth + spacing)
                y = CGFloat(weekIdx) * (cellHeight + spacing)

                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: gridView.leadingAnchor, constant: x),
                    button.topAnchor.constraint(equalTo: gridView.topAnchor, constant: y),
                    button.widthAnchor.constraint(equalToConstant: cellWidth),
                    button.heightAnchor.constraint(equalToConstant: cellHeight)
                ])
            }
            dayButtons.append(weekButtons)
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

    func handleArrowKey(_ keyCode: UInt16) {
        guard !dayButtons.isEmpty else { return }

        if let firstResponder = view.window?.firstResponder as? CalendarDayButton,
           let (row, col) = findButtonPosition(firstResponder) {
            let dayCount = dayButtons.count
            let colCount = dayButtons[0].count

            switch keyCode {
            case 123: // Left arrow
                let newCol = col > 0 ? col - 1 : colCount - 1
                let newRow = col > 0 ? row : (row > 0 ? row - 1 : dayCount - 1)
                if newRow >= 0 && newRow < dayCount && newCol >= 0 && newCol < colCount {
                    view.window?.makeFirstResponder(dayButtons[newRow][newCol])
                }
            case 124: // Right arrow
                let newCol = col < colCount - 1 ? col + 1 : 0
                let newRow = col < colCount - 1 ? row : (row < dayCount - 1 ? row + 1 : 0)
                if newRow >= 0 && newRow < dayCount && newCol >= 0 && newCol < colCount {
                    view.window?.makeFirstResponder(dayButtons[newRow][newCol])
                }
            case 125: // Down arrow
                let newRow = row < dayCount - 1 ? row + 1 : 0
                if newRow >= 0 && newRow < dayCount && col >= 0 && col < colCount {
                    view.window?.makeFirstResponder(dayButtons[newRow][col])
                }
            case 126: // Up arrow
                let newRow = row > 0 ? row - 1 : dayCount - 1
                if newRow >= 0 && newRow < dayCount && col >= 0 && col < colCount {
                    view.window?.makeFirstResponder(dayButtons[newRow][col])
                }
            default:
                break
            }
        }
    }

    private func findButtonPosition(_ button: CalendarDayButton) -> (row: Int, col: Int)? {
        for (rowIdx, row) in dayButtons.enumerated() {
            for (colIdx, btn) in row.enumerated() {
                if btn === button {
                    return (rowIdx, colIdx)
                }
            }
        }
        return nil
    }
}
