import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

@MainActor
private final class StubLoginItem: LoginItemControlling {
    var isEnabled = false
    var statusDescription = "Stub login item"
    var succeeds = true
    private(set) var lastRequest: Bool?

    func setEnabled(_ enabled: Bool) -> Bool {
        lastRequest = enabled
        if succeeds { isEnabled = enabled }
        return succeeds
    }
}

@MainActor
private func makeModel(loginItem: LoginItemControlling = StubLoginItem())
    throws -> (DivotSettingsModel, ConfigurationController) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = ConfigurationStore(configURL: directory.appendingPathComponent("config.json"))
    let controller = ConfigurationController(store: store)
    return (DivotSettingsModel(controller: controller, loginItem: loginItem), controller)
}

@MainActor
@Test func familyAndModePersistSeparately() throws {
    let (model, controller) = try makeModel()

    model.update { $0.appearance.family = .gruvbox }
    model.update { $0.appearance.mode = .dark }

    // Changing the variant did not reset the family.
    #expect(model.configuration.appearance.family == .gruvbox)
    #expect(model.configuration.appearance.mode == .dark)

    // Both survive a reload from disk.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.appearance.family == .gruvbox)
    #expect(reloaded.current.appearance.mode == .dark)
}

@MainActor
@Test func anInvalidEditIsRefusedAndReported() throws {
    let (model, _) = try makeModel()
    let good = model.configuration.appearance.accent

    model.update { $0.appearance.accent = "not-hex" }

    #expect(model.errorMessage?.contains("appearance.accent") == true)
    #expect(model.configuration.appearance.accent == good)
}

@MainActor
@Test func itemsCanBeHiddenMovedAndReordered() throws {
    let (model, _) = try makeModel()

    model.setPlaced(.frontApp, false)
    #expect(!model.configuration.isPlaced(.frontApp))

    model.setPlaced(.frontApp, true)
    #expect(model.configuration.side(of: .frontApp) == .left)

    model.setSide(.frontApp, .right)
    #expect(model.configuration.side(of: .frontApp) == .right)

    // Reorder within the right group.
    let right = model.configuration.right
    guard let index = right.firstIndex(of: .frontApp), index > 0 else {
        Issue.record("expected front-app on the right after a non-first slot")
        return
    }
    model.moveWithinSide(.frontApp, delta: -1)
    #expect(model.configuration.right.firstIndex(of: .frontApp) == index - 1)
}

@MainActor
@Test func loginItemToggleRoutesThroughTheControl() throws {
    let stub = StubLoginItem()
    let (model, _) = try makeModel(loginItem: stub)

    #expect(!model.loginItemEnabled)
    model.setLaunchAtLogin(true)
    #expect(stub.lastRequest == true)
    #expect(model.loginItemEnabled)

    stub.succeeds = false
    model.setLaunchAtLogin(false)
    #expect(model.errorMessage != nil)
}

@MainActor
@Test func modelFollowsChangesPublishedByTheSharedController() throws {
    let (model, controller) = try makeModel()

    // An external reload or a save elsewhere publishes through the controller;
    // the open window follows it instead of holding a stale copy.
    controller.update { $0.appearance.mode = .dark }
    #expect(model.configuration.appearance.mode == .dark)
}
