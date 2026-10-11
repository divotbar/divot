import Foundation
import Testing
@testable import DivotCore
@testable import DivotAppKit

private func makeDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let validV2 = ##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["time"],"right":["battery"]}"##

@MainActor
@Test func controllerPublishesALoadedFile() throws {
    let url = try makeDirectory().appendingPathComponent("config.json")
    try Data(validV2.utf8).write(to: url, options: .atomic)
    let controller = ConfigurationController(store: ConfigurationStore(configURL: url))

    var published: [DivotConfiguration] = []
    controller.addObserver { published.append($0) }

    #expect(controller.reload() == .loaded)
    #expect(controller.configuration.left == [.time])
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

    #expect(controller.update { $0.widgets.time.seconds = true }.isSuccess)
    #expect(controller.configuration.widgets.time.seconds)

    let reloaded = ConfigurationStore(configURL: url)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.widgets.time.seconds)
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
    #expect(controller.configuration.right == [.battery, .time])
}

/// A writer that fails its first call (the migration rewrite) and succeeds
/// afterwards, so a test can prove the last-good snapshot is what a later save
/// persists.
private final class FailingThenWorkingWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    func write(_ data: Data, to url: URL) throws {
        lock.lock()
        calls += 1
        let shouldFail = calls == 1
        lock.unlock()
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
@Test func failedMigrationLeavesTheControllerOnTheLastGoodConfiguration() throws {
    let url = try makeDirectory().appendingPathComponent("config.json")
    try Data(#"{"version":1,"status":["battery","clock"]}"#.utf8).write(to: url, options: .atomic)
    let writer = FailingThenWorkingWriter()
    let store = ConfigurationStore(configURL: url, fileManager: .default, writeData: writer.write)
    let controller = ConfigurationController(store: store)

    guard case .invalid = controller.reload() else {
        Issue.record("expected the migration write to fail")
        return
    }
    // The half-applied migration is not published: the controller stays on its
    // last good snapshot.
    #expect(controller.configuration == .default)
    #expect(controller.lastError != nil)

    // A later settings save persists the last-good document, not a half-migrated
    // one: `right` keeps the default items instead of the version 1 status array.
    #expect(controller.update { $0.left = [.frontApp, .workspaces] }.isSuccess)
    let reread = try ConfigurationParser.parse(Data(contentsOf: url))
    #expect(reread.configuration.left == [.frontApp, .workspaces])
    #expect(reread.configuration.right == DivotConfiguration.default.right)
}

@Test func environmentOverridesAdjustWorkspaceDisplayOptions() {
    let base = WorkspaceDisplayOptions(showEmpty: true, showAppIcons: false, showDetails: true)
    let overridden = WorkspaceEnvironmentOverrides.displayOptions(
        base,
        environment: ["DIVOT_WORKSPACES_SHOW_EMPTY": "false",
                      "DIVOT_WORKSPACES_SHOW_ICONS": "on"])
    #expect(overridden.showEmpty == false)
    #expect(overridden.showAppIcons == true)
    #expect(overridden.showDetails == true)
}

@Test func environmentCanOverrideTheWorkspaceAdapter() {
    #expect(WorkspaceEnvironmentOverrides.adapter(.aerospace,
                                                  environment: ["DIVOT_WORKSPACES_ADAPTER": "yabai"]) == .yabai)
    // An absent or unrecognized value keeps the configured adapter.
    #expect(WorkspaceEnvironmentOverrides.adapter(.aerospace, environment: [:]) == .aerospace)
    #expect(WorkspaceEnvironmentOverrides.adapter(.yabai,
                                                  environment: ["DIVOT_WORKSPACES_ADAPTER": "amphibian"]) == .yabai)
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
