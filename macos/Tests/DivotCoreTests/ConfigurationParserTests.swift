import Foundation
import Testing
@testable import DivotCore

private func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DivotCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // macos
        .deletingLastPathComponent() // repository root
}

private func exampleData(_ name: String) throws -> Data {
    try Data(contentsOf: repoRoot().appendingPathComponent("examples/\(name)"))
}

private func migrationData(_ name: String) throws -> Data {
    try Data(contentsOf: repoRoot().appendingPathComponent("examples/migrations/\(name)"))
}

private func json(_ string: String) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(string.utf8))
}

private func error<T>(_ body: () throws -> T) -> ConfigurationError? {
    do {
        _ = try body()
        return nil
    } catch let error as ConfigurationError {
        return error
    } catch {
        return nil
    }
}

// MARK: - Version 2

@Test func defaultExampleParsesToTheFirstLaunchConfiguration() throws {
    let parsed = try ConfigurationParser.parse(try exampleData("default.json"))
    #expect(parsed.migratedFromVersion == nil)
    #expect(parsed.configuration == .default)
}

@Test func focusExampleParsesItsOptions() throws {
    let parsed = try ConfigurationParser.parse(try exampleData("focus.json"))
    let configuration = parsed.configuration
    #expect(configuration.left == [.workspaces])
    #expect(configuration.right == [.clock])
    #expect(configuration.appearance.mode == .dark)
    #expect(configuration.appearance.material == .opaque)
    #expect(configuration.layout == LayoutConfiguration(height: 28, padding: 10, notchGap: 12))
    #expect(configuration.widgets.workspaces.showEmpty == false)
    #expect(configuration.widgets.clock == ClockConfiguration(weekday: false, date: true, seconds: false))
}

@Test func everyTopLevelExampleParsesNatively() throws {
    let directory = repoRoot().appendingPathComponent("examples")
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }
    #expect(!files.isEmpty)
    for file in files {
        _ = try ConfigurationParser.parse(Data(contentsOf: file))
    }
}

@Test func customPaletteIsPreserved() throws {
    let parsed = try ConfigurationParser.parse(try exampleData("custom-palette.json"))
    let configuration = parsed.configuration
    #expect(configuration.appearance.family == .gruvbox)
    #expect(configuration.appearance.palette[.background] == "#282828")
    // A palette accent overrides the root accent.
    #expect(configuration.appearance.effectiveAccent == "#B8BB26")
}

@Test func configurationRoundTripsThroughJSON() throws {
    let parsed = try ConfigurationParser.parse(try exampleData("custom-palette.json"))
    let encoded = try JSONSerialization.data(withJSONObject: parsed.configuration.jsonObject,
                                             options: [.sortedKeys])
    let reparsed = try ConfigurationParser.parse(encoded)
    #expect(reparsed.configuration == parsed.configuration)
}

@Test func unsupportedVersionIsRejectedNotReinterpreted() throws {
    let data = try JSONSerialization.data(withJSONObject: [
        "version": 3, "appearance": [:], "layout": [:], "left": [], "right": []
    ])
    let failure = error { try ConfigurationParser.parse(data) }
    #expect(failure?.path == "version")
    #expect(failure?.message.contains("unsupported version 3") == true)
}

@Test func unknownRootFieldIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"extra":true}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "root")
    #expect(failure?.message == "unknown field extra")
}

@Test func outOfRangeLayoutIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":80,"padding":12,"notchGap":10},"left":["clock"],"right":[]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "layout.height")
    #expect(failure?.message == "expected 24–40")
}

@Test func duplicateItemAcrossGroupsIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":["clock"]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "left/right")
}

@Test func unknownWidgetNamespaceIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"widgets":{"weather":{}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets")
    #expect(failure?.message == "unknown field weather")
}

@Test func unknownWidgetOptionIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"widgets":{"clock":{"timezone":"UTC"}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.clock")
    #expect(failure?.message == "unknown field timezone")
}

@Test func optionsForAnUnplacedItemAreRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["workspaces"],"right":[],"widgets":{"front-app":{"showIcon":false}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.front-app")
    #expect(failure?.message == "not placed on left or right")
}

@Test func invalidAppearanceValuesAreRejected() throws {
    let badFamily = try json(##"{"version":2,"appearance":{"family":"solarized","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[]}"##)
    #expect(error { try ConfigurationParser.parse(jsonObject: badFamily) }?.path == "appearance.family")

    let badHex = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[]}"##)
    #expect(error { try ConfigurationParser.parse(jsonObject: badHex) }?.path == "appearance.accent")

    let badMode = try json(##"{"version":2,"appearance":{"family":"native","mode":"twilight","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[]}"##)
    #expect(error { try ConfigurationParser.parse(jsonObject: badMode) }?.path == "appearance.mode")
}

@Test func nonBooleanOptionIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"widgets":{"clock":{"seconds":"yes"}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.clock.seconds")
    #expect(failure?.message == "expected boolean")
}

@Test func maxAppIconsIsRangeChecked() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["workspaces"],"right":[],"widgets":{"workspaces":{"maxAppIconsPerWorkspace":99}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.workspaces.maxAppIconsPerWorkspace")
    #expect(failure?.message == "expected 0–32")
}

@Test func batteryOptionsMustBeAnEmptyObject() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":[],"right":["battery"],"widgets":{"battery":{"showIcon":true}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.battery")
    #expect(failure?.message == "unknown field showIcon")
}

// MARK: - Version 1 migration fixtures

@Test func starterV1DefaultMigratesToAVersionTwoDocument() throws {
    let parsed = try ConfigurationParser.parse(try migrationData("v1-default.json"))
    #expect(parsed.migratedFromVersion == 1)
    let configuration = parsed.configuration
    #expect(configuration.version == 2)
    #expect(configuration.left == [.workspaces])
    #expect(configuration.right == [.battery, .clock, .network, .volume])
    #expect(configuration.appearance == .default)
    #expect(configuration.layout == .default)
    #expect(configuration.widgets == .default)
}

@Test func starterV1FocusMigratesItsWorkspacesOptions() throws {
    let parsed = try ConfigurationParser.parse(try migrationData("v1-focus.json"))
    #expect(parsed.migratedFromVersion == 1)
    let configuration = parsed.configuration
    #expect(configuration.left == [.workspaces])
    #expect(configuration.right == [.clock])
    #expect(configuration.appearance.mode == .dark)
    #expect(configuration.widgets.workspaces.showEmpty == false)
    #expect(configuration.widgets.workspaces.showAppIcons == false)
    #expect(configuration.widgets.workspaces.adapter == .aerospace)
    // Migration fills the options it did not know about with the defaults.
    #expect(configuration.widgets.workspaces.showDetails == true)
}

@Test func versionOneWithUnknownFieldIsRejected() throws {
    let value = try json(##"{"version":1,"status":["clock"],"mystery":true}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "root")
    #expect(failure?.message == "unknown field mystery")
}

@Test func versionOneStatusMayNotRepeatTheHardCodedWorkspacesItem() throws {
    let value = try json(##"{"version":1,"status":["workspaces","clock"]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "left/right")
}
