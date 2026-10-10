import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Records power-assertion releases without touching the machine's power state.
private final class RecordingAssertionCreator: PowerAssertionCreating, @unchecked Sendable {
    private let lock = NSLock()
    private var releases = 0

    var releaseCount: Int { lock.lock(); defer { lock.unlock() }; return releases }

    func acquireAssertion(reason: String) -> (any PowerAssertionHandle)? {
        RecordingAssertionHandle { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.releases += 1; self.lock.unlock()
        }
    }
}

private final class RecordingAssertionHandle: PowerAssertionHandle, @unchecked Sendable {
    private let onRelease: @Sendable () -> Void
    init(_ onRelease: @escaping @Sendable () -> Void) { self.onRelease = onRelease }
    func release() { onRelease() }
}

/// The menu-bar menu and the Settings window must reach one quit path, and that
/// path must release keep-awake. A no-op terminate keeps the test runner alive.
@MainActor
@Test func menuQuitItemAndSettingsButtonShareTheQuitPath() throws {
    var terminateCount = 0
    let coordinator = QuitCoordinator(terminate: { terminateCount += 1 })

    // Both menus use this exact item shape: the shared coordinator's quit action
    // as the target. Firing it must take the quit path.
    let item = NSMenuItem(title: "Quit Divot",
                          action: #selector(QuitCoordinator.quit(_:)),
                          keyEquivalent: "q")
    item.target = coordinator
    if let action = item.action {
        _ = item.target?.perform(action, with: item)
    }
    #expect(terminateCount == 1)

    // The Settings button reaches the same coordinator through its model, after
    // the shared dialog confirms.
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = ConfigurationStore(configURL: directory.appendingPathComponent("config.json"))
    let model = DivotSettingsModel(controller: ConfigurationController(store: store),
                                   requestQuit: { coordinator.quit() })
    model.quit()
    #expect(terminateCount == 2)
}

@MainActor
@Test func quitReleasesTheKeepAwakeAssertion() {
    let creator = RecordingAssertionCreator()
    let keepAwake = KeepAwakeController(creator: creator)
    #expect(keepAwake.setActive(true))

    let coordinator = QuitCoordinator(terminate: {},
                                      releasePowerAssertions: { keepAwake.releaseAll() })
    coordinator.quit()

    #expect(!keepAwake.isActive)
    #expect(creator.releaseCount == 1)
}
