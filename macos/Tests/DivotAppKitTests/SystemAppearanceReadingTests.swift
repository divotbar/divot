import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// The reading touches `NSApplication.shared.appearance`, a process-wide value, so these run
/// serially and each restores the ambient override.
@Suite(.serialized)
@MainActor
struct SystemAppearanceReadingTests {
    /// The reported crash path: toggling twice must flip Divot's override each
    /// time and never trap. The toggle used to run inside `DispatchQueue.main`
    /// while the provider's push already ran on the main thread (#0050).
    @Test func toggleFlipsDivotAppearanceTwiceWithoutCrashing() {
        let original = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = original }

        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let reading = SystemAppearanceReading()
        #expect(reading.snapshot()?.mode == .light)

        reading.toggleAppearance()
        #expect(NSApplication.shared.appearance?.name == .darkAqua)
        #expect(reading.snapshot()?.mode == .dark)

        reading.toggleAppearance()
        #expect(NSApplication.shared.appearance?.name == .aqua)
        #expect(reading.snapshot()?.mode == .light)
    }

    /// Several clicks in a row keep alternating and never trap (#0050).
    @Test func repeatedTogglesKeepAlternatingWithoutCrashing() {
        let original = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = original }
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

        let reading = SystemAppearanceReading()
        for index in 0..<6 {
            reading.toggleAppearance()
            #expect(reading.snapshot()?.mode == (index.isMultiple(of: 2) ? .dark : .light))
        }
    }

    @Test func toggleNotifiesTheObserver() {
        let original = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = original }
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

        let reading = SystemAppearanceReading()
        let counter = AppearanceChangeCounter()
        let subscription = reading.observeChanges { counter.value += 1 }

        reading.toggleAppearance()
        reading.toggleAppearance()
        #expect(counter.value == 2)
        subscription.cancel()
    }

    /// The provider's initial push reads `snapshot()` from the main actor. That
    /// is the exact call that trapped before the fix, so this test would crash
    /// the whole suite against the old implementation.
    @Test func providerEmitsOnStartAndAfterToggle() async {
        let original = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = original }
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

        let reading = SystemAppearanceReading()
        let collector = AppearanceModeCollector()
        let subscription = AppearanceProvider(reading: reading).start { collector.append($0) }

        await waitFor { collector.count >= 1 }
        #expect(collector.firstMode == .light)

        reading.toggleAppearance()
        await waitFor { collector.count >= 2 }
        #expect(collector.lastMode == .dark)
        subscription.cancel()
    }
}

@MainActor
private final class AppearanceChangeCounter {
    var value = 0
}

/// Thread-safe sink for appearance emissions from the provider's main-actor task.
private final class AppearanceModeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var modes: [AppearanceMode] = []

    func append(_ content: WidgetContent) {
        guard case .appearance(let snapshot) = content else { return }
        lock.lock(); modes.append(snapshot.mode); lock.unlock()
    }

    var count: Int { lock.lock(); defer { lock.unlock() }; return modes.count }
    var firstMode: AppearanceMode? { lock.lock(); defer { lock.unlock() }; return modes.first }
    var lastMode: AppearanceMode? { lock.lock(); defer { lock.unlock() }; return modes.last }
}

private func waitFor(_ condition: @Sendable () -> Bool, timeout: TimeInterval = 2) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
}
