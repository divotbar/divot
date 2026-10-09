import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

private func makeDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let validV2 = ##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":["battery"]}"##

@MainActor
@Test func controllerPublishesALoadedFile() throws {
    let url = try makeDirectory().appendingPathComponent("config.json")
    try Data(validV2.utf8).write(to: url, options: .atomic)
    let controller = ConfigurationController(store: ConfigurationStore(configURL: url))

    var published: [DivotConfiguration] = []
    controller.addObserver { published.append($0) }

    #expect(controller.reload() == .loaded)
    #expect(controller.configuration.left == [.clock])
    #expect(controller.configuration.right == [.battery])
    #expect(published == [controller.configuration])
}

@MainActor
@Test func controllerRefusesAnInvalidEditAndKeepsTheLastGoodSnapshot() throws {
    let url = try makeDirectory().appendingPathComponent("config.json")
    try Data(validV2.utf8).write(to: url, options: .atomic)
    let controller = ConfigurationController(store: ConfigurationStore(configURL: url))
    controller.reload()
    let good = controller.configuration

    var publishedAfterInvalid = 0
    controller.addObserver { _ in publishedAfterInvalid += 1 }

    let result = controller.update { $0.layout.height = 900 }
    guard case .failure(let error) = result else {
        Issue.record("expected a failure")
        return
    }
    #expect(error.path == "layout.height")
    #expect(controller.configuration == good)
    #expect(controller.lastError?.path == "layout.height")
    #expect(publishedAfterInvalid == 0)
}

@MainActor
@Test func controllerPersistsAValidEditToDisk() throws {
    let url = try makeDirectory().appendingPathComponent("config.json")
    let store = ConfigurationStore(configURL: url)
    let controller = ConfigurationController(store: store)

    #expect(controller.update { $0.widgets.clock.seconds = true }.isSuccess)
    #expect(controller.configuration.widgets.clock.seconds)

    let reloaded = ConfigurationStore(configURL: url)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.widgets.clock.seconds)
}

@MainActor
@Test func controllerReportsAMigration() throws {
    let url = try makeDirectory().appendingPathComponent("config.json")
    try Data(#"{"version":1,"status":["battery","clock"]}"#.utf8).write(to: url, options: .atomic)
    let controller = ConfigurationController(store: ConfigurationStore(configURL: url))

    guard case .migrated(let from, _) = controller.reload() else {
        Issue.record("expected a migration")
        return
    }
    #expect(from == 1)
    #expect(controller.configuration.version == 2)
    #expect(controller.configuration.right == [.battery, .clock])
}

@Test func environmentOverridesAdjustWorkspaceDisplayOptionsOnly() {
    let base = WorkspaceDisplayOptions(showEmpty: true, showAppIcons: false, showDetails: true)
    let overridden = WorkspaceEnvironmentOverrides.displayOptions(
        base,
        environment: ["DIVOT_WORKSPACES_SHOW_EMPTY": "false",
                      "DIVOT_WORKSPACES_SHOW_ICONS": "on"])
    #expect(overridden.showEmpty == false)
    #expect(overridden.showAppIcons == true)
    #expect(overridden.showDetails == true)
}

@MainActor
@Test func placedProviderIDsFollowTheConfiguration() {
    var configuration = DivotConfiguration.default
    #expect(DefaultWidgetProviders.placedProviderIDs(in: configuration)
        == [.battery, .clock, .network, .volume, .frontApp])

    // Remove the status items from both sides: their providers stop.
    configuration.remove(.battery)
    configuration.remove(.network)
    configuration.remove(.volume)
    #expect(DefaultWidgetProviders.placedProviderIDs(in: configuration) == [.clock, .frontApp])

    // Moving an item does not duplicate provider activity.
    configuration.move(.frontApp, to: .right)
    #expect(DefaultWidgetProviders.placedProviderIDs(in: configuration) == [.clock, .frontApp])
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
