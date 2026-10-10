import Foundation
import Testing
@testable import DivotCore

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ json: String, to url: URL) throws {
    try Data(json.utf8).write(to: url, options: .atomic)
}

@Test func missingFileUsesTheNativeDefaults() throws {
    let directory = try makeTempDirectory()
    let store = ConfigurationStore(configURL: directory.appendingPathComponent("config.json"))
    #expect(store.load() == .defaults)
    #expect(store.current == .default)
}

@Test func aValidFileBecomesCurrent() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    try write(##"{"version":2,"appearance":{"family":"native","mode":"dark","accent":"#D6F58A","material":"native"},"layout":{"height":30,"padding":10,"notchGap":8},"left":["clock"],"right":["battery"]}"##, to: url)
    let store = ConfigurationStore(configURL: url)
    #expect(store.load() == .loaded)
    #expect(store.current.left == [.clock])
    #expect(store.current.right == [.battery])
    #expect(store.current.appearance.mode == .dark)
    #expect(store.current.layout.height == 30)
}

@Test func invalidReloadPreservesTheLastGoodSnapshot() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    try write(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":["battery"]}"##, to: url)
    let store = ConfigurationStore(configURL: url)
    #expect(store.load() == .loaded)
    let good = store.current

    // An out-of-range height must not blank the bar or silently clamp.
    try write(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":900,"padding":12,"notchGap":10},"left":["clock"],"right":["battery"]}"##, to: url)
    guard case .invalid(let error) = store.load() else {
        Issue.record("expected an invalid outcome")
        return
    }
    #expect(error.path == "layout.height")
    #expect(store.current == good)

    // A later good write recovers.
    try write(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":34,"padding":12,"notchGap":10},"left":["clock"],"right":["battery"]}"##, to: url)
    #expect(store.load() == .loaded)
    #expect(store.current.layout.height == 34)
}

@Test func saveIsAtomicAndReloadable() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    let store = ConfigurationStore(configURL: url)
    var configuration = DivotConfiguration.default
    configuration.widgets.clock.seconds = true
    configuration.left = [.frontApp, .workspaces]
    try store.save(configuration)

    let reloaded = ConfigurationStore(configURL: url)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current == configuration)
    // The written document is the canonical version 2 shape.
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect(object?["version"] as? Int == 2)
}

@Test func savePersistsKeepAwakeAndOmitsItWhenDefault() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    let store = ConfigurationStore(configURL: url)

    // A plain unremembered document writes no keep-awake object at all.
    try store.save(.default)
    var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect(object?["keepAwake"] == nil)

    var configuration = DivotConfiguration.default
    configuration.keepAwake = KeepAwakeConfiguration(remember: true, isActive: true)
    try store.save(configuration)

    let reloaded = ConfigurationStore(configURL: url)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.keepAwake == KeepAwakeConfiguration(remember: true, isActive: true))
    object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect((object?["keepAwake"] as? [String: Any])?["remember"] as? Bool == true)
}

@Test func savePersistsMenuBarOptInAndOmitsItWhenDefault() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    let store = ConfigurationStore(configURL: url)

    // The conservative default writes no menu-bar object at all.
    try store.save(.default)
    var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect(object?["menuBar"] == nil)

    var configuration = DivotConfiguration.default
    configuration.menuBar.trustAccessibilityProbe = true
    try store.save(configuration)

    let reloaded = ConfigurationStore(configURL: url)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.menuBar.trustAccessibilityProbe)
    object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect((object?["menuBar"] as? [String: Any])?["trustAccessibilityProbe"] as? Bool == true)
}

@Test func saveRefusesAnInvalidConfiguration() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    let store = ConfigurationStore(configURL: url)
    var configuration = DivotConfiguration.default
    configuration.right.append(.workspaces) // already on the left
    #expect(throws: ConfigurationError.self) { try store.save(configuration) }
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func versionOneMigrationBacksUpTheOriginalAndRewritesVersionTwo() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    try write(##"{"version":1,"status":["battery","clock"]}"##, to: url)
    let store = ConfigurationStore(configURL: url)

    guard case .migrated(let fromVersion, let backupURL) = store.load() else {
        Issue.record("expected a migration outcome")
        return
    }
    #expect(fromVersion == 1)
    #expect(FileManager.default.fileExists(atPath: backupURL.path))
    #expect(backupURL.lastPathComponent == "config-v1-backup.json")
    #expect(store.current.version == 2)
    #expect(store.current.right == [.battery, .clock])

    // The rewritten file is now a plain version 2 document.
    let rewritten = try ConfigurationParser.parse(Data(contentsOf: url))
    #expect(rewritten.migratedFromVersion == nil)
    #expect(rewritten.configuration == store.current)

    // And a second launch is a plain load, not another migration.
    let second = ConfigurationStore(configURL: url)
    #expect(second.load() == .loaded)
}

@Test func failedMigrationWriteKeepsTheLastGoodSnapshot() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    try write(#"{"version":1,"status":["battery","clock"]}"#, to: url)

    // The backup succeeds, then the version 2 rewrite fails.
    let store = ConfigurationStore(configURL: url,
                                   fileManager: .default,
                                   writeData: { _, _ in throw CocoaError(.fileWriteUnknown) })
    let before = store.current

    guard case .invalid(let error) = store.load() else {
        Issue.record("expected the migration write to fail")
        return
    }
    #expect(error.message.contains("migration could not be written"))
    // The migrated document never becomes current on a failed write.
    #expect(store.current == before)
    #expect(store.lastOutcome == .invalid(error))

    // The original version 1 document is untouched, so the next launch retries.
    let original = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect(original?["version"] as? Int == 1)
}

@Test func migrationWithoutABackupableOriginalKeepsTheLastGoodSnapshot() throws {
    let directory = try makeTempDirectory()
    let url = directory.appendingPathComponent("config.json")
    try write(#"{"version":1,"status":["clock"]}"#, to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    // A privileged runner can write through the permission bits; only assert
    // when the directory is genuinely not writable.
    let probe = directory.appendingPathComponent("probe.json")
    let writable = (try? Data("x".utf8).write(to: probe)) != nil
    try? FileManager.default.removeItem(at: probe)
    guard !writable else { return }

    let store = ConfigurationStore(configURL: url)
    guard case .invalid = store.load() else {
        Issue.record("expected the migration to fail")
        return
    }
    #expect(store.current == .default)
}

@Test func defaultLocationHonorsXDGConfigHome() {
    let xdg = DivotConfigLocation.defaultURL(homeDirectory: "/Users/x",
                                             environment: ["XDG_CONFIG_HOME": "/tmp/cfg"])
    #expect(xdg.path == "/tmp/cfg/divot/config.json")

    let fallback = DivotConfigLocation.defaultURL(homeDirectory: "/Users/x", environment: [:])
    #expect(fallback.path == "/Users/x/.config/divot/config.json")
}
