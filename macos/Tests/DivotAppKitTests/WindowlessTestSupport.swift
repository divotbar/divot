import AppKit
import CoreGraphics
import Testing
@testable import DivotAppKit

/// A `WindowPresenting` that records what production would have shown but never
/// orders a window front. Tests inject it so a run can assert "would present"
/// without putting a bar or popover on the maintainer's screen (#0091).
@MainActor
final class RecordingWindowPresenter: WindowPresenting {
    private(set) var orderFrontRegardlessCount = 0
    private(set) var makeKeyAndOrderFrontCount = 0
    private(set) var orderedWindows: [NSWindow] = []

    /// True once any production path asked to show a window.
    var wouldPresent: Bool { orderFrontRegardlessCount + makeKeyAndOrderFrontCount > 0 }

    func orderFrontRegardless(_ window: NSWindow) {
        orderFrontRegardlessCount += 1
        orderedWindows.append(window)
    }

    func makeKeyAndOrderFront(_ window: NSWindow) {
        makeKeyAndOrderFrontCount += 1
        orderedWindows.append(window)
    }
}

/// A popover monitor that records its lifecycle without installing a real event
/// tap, so a windowless test never touches the event stream.
@MainActor
final class NoopPopoverMonitor: PopoverEventMonitoring {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isMonitoring = false
    private var onDismiss: (() -> Void)?

    func start(action: @escaping (NSEvent) -> PopoverPressAction, onDismiss: @escaping () -> Void) {
        _ = action
        startCount += 1
        isMonitoring = true
        self.onDismiss = onDismiss
    }

    func stop() {
        stopCount += 1
        isMonitoring = false
        onDismiss = nil
    }

    /// Fire the dismiss callback the live global monitor would call.
    func fireOutsideClick() { onDismiss?() }
}

/// On-screen windows owned by this test process, read straight from the window
/// server. Empty for a correctly windowless run; the guard suite asserts it
/// before and after it exercises the presentation paths.
func onScreenWindowsOwnedByThisProcess() -> [[String: Any]] {
    guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    let pid = ProcessInfo.processInfo.processIdentifier
    return info.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }
}

/// Fails the wrapped test if any window is left visible on screen.
///
/// Applied to the AppKit tests that build Divot windows (`@Test(.windowless)`
/// or `@Suite(.windowless)`), so a regression in the `WindowPresenting` seam is
/// caught here instead of on the maintainer's desktop (#0091). Every other test
/// in the target is covered by the seam itself: production only shows a window
/// through an injected presenter, and tests inject the recording no-op.
struct WindowlessTestGuard: TestTrait, SuiteTrait, TestScoping {
    func provideScope(for test: Test,
                      testCase: Test.Case?,
                      performing function: @Sendable () async throws -> Void) async throws {
        var thrown: (any Error)?
        do {
            try await function()
        } catch {
            thrown = error
        }

        let visible = await MainActor.run {
            NSApplication.shared.windows
                .filter(\.isVisible)
                .map { $0.title.isEmpty ? $0.className : $0.title }
        }
        if !visible.isEmpty {
            Issue.record("""
                Test \(test.name) left \(visible.count) visible window(s) on screen \
                (\(visible.joined(separator: ", "))). Divot tests must be windowless: \
                inject a no-op WindowPresenting and never order a window front.
                """)
        }

        if let thrown { throw thrown }
    }
}

extension Trait where Self == WindowlessTestGuard {
    static var windowless: Self { WindowlessTestGuard() }
}
