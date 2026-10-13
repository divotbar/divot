import AppKit

/// Shared scaffolding for the popovers anchored to Divot's bar items.
///
/// Both the read-only Wi-Fi popover (task 0070) and the output-volume popover
/// (task 0071) present the same way: an `NSPopover` anchored below the item,
/// holding a vertical stack of a header, a body, a separator, and a final
/// settings row. This base owns that AppKit look and the show/dismiss lifecycle
/// so a second popover does not copy it.
@MainActor
class BarPopoverContentController: NSViewController {
    let stack = NSStackView()

    /// The size the popover should occupy for the currently rendered state.
    var preferredSize: NSSize {
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        return NSSize(width: max(272, fitting.width), height: max(1, fitting.height))
    }

    override func loadView() {
        let root = NSView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12)
        ])
        self.view = root
    }

    /// Remove every arranged row so a state change can rebuild the stack.
    func clearRows() {
        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    func header(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    func message(_ text: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 248).isActive = true
        return label
    }

    func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    func linkButton(_ title: String, action: Selector) -> NSView {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .inline
        button.alignment = .left
        button.font = .systemFont(ofSize: 12)
        button.contentTintColor = .controlAccentColor
        return button
    }
}

/// Owns one anchored `NSPopover` and its content controller. A popover is
/// `.transient`, so clicking elsewhere dismisses it without the owning
/// controller doing anything special; `onClose` reports that close so the owner
/// can tear down observers.
@MainActor
final class BarPopoverHost: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?

    /// Called after the popover closes for any reason — an explicit `dismiss()`,
    /// a click outside, or Escape — so the owner can remove its observers.
    var onClose: (() -> Void)?

    var isShown: Bool { popover?.isShown ?? false }

    func present(_ content: BarPopoverContentController, relativeTo view: NSView) {
        dismiss()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = content
        popover.contentSize = content.preferredSize
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        self.popover = popover
    }

    /// Match the popover to a content controller whose preferred size changed.
    func resize(to size: NSSize) {
        popover?.contentSize = size
    }

    func dismiss() {
        popover?.performClose(nil)
        popover = nil
    }

    func popoverDidClose(_ notification: Notification) {
        // A close that arrives after a newer popover was presented must not
        // tear down the current one's state.
        guard let closed = notification.object as? NSPopover, closed === popover else { return }
        popover = nil
        onClose?()
    }
}
