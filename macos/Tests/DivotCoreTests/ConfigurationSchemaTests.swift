import Foundation
import Testing
@testable import DivotCore

// MARK: - Fixtures

/// A valid document that sets every leaf the model can serialize to a
/// non-default value, so the completeness test can compare the document's leaf
/// keys against the schema.
private func maximalConfiguration() -> DivotConfiguration {
    var configuration = DivotConfiguration.default
    configuration.appearance = AppearanceConfiguration(
        family: .gruvbox,
        mode: .dark,
        accent: "#B7CEFF",
        material: .opaque,
        palette: [
            .foreground: "#EBDBB2",
            .background: "#282828",
            .accent: "#B8BB26",
            .selected: "#458588",
            .occupied: "#83A598",
            .error: "#FB4934"
        ])
    configuration.layout = LayoutConfiguration(height: 30, padding: 10,
                                               rightItemSpacing: 12, leftItemSpacing: 14)
    configuration.text = TextConfiguration(size: 16, font: "Helvetica")
    configuration.left = [.workspaces, .frontApp, .date]
    configuration.right = [.battery, .network, .volume, .time]
    configuration.widgets.workspaces = WorkspacesConfiguration(adapter: .yabai,
                                                              showEmpty: false,
                                                              showAppIcons: true,
                                                              showDetails: false,
                                                              maxAppIconsPerWorkspace: 5)
    configuration.widgets.frontApp = FrontAppConfiguration(showIcon: false, showName: false)
    configuration.widgets.battery = BatteryConfiguration(showPercentage: false)
    configuration.widgets.date = DateConfiguration(weekday: false, year: true, dayFirst: true,
                                                   separator: "-", customPattern: "yyyy-MM-dd")
    configuration.widgets.time = TimeConfiguration(seconds: true, timeFormat: .custom,
                                                   customPattern: "HH:mm:ss")
    configuration.widgets.network = NetworkConfiguration(showWifiName: true)
    configuration.widgets.volume = VolumeConfiguration(showVolumePercent: false, showVolumeMuted: false)
    configuration.keepAwake = KeepAwakeConfiguration(remember: true, isActive: true)
    configuration.menuBar = MenuBarConfiguration(trustAccessibilityProbe: true,
                                                 moveBelowOnCursorReveal: false,
                                                 alwaysBelow: true)
    configuration.showAppIcon = true
    configuration.showOccupiedDot = false
    configuration.showEmptyDot = false
    configuration.bottomShadow = true
    configuration.chipStyle = true
    configuration.chipOpacity = 40
    configuration.appIconSize = 20
    return configuration
}

/// Every dotted leaf path in a JSON object tree; arrays are leaves.
private func leafPaths(_ object: Any, prefix: String = "") -> [String] {
    guard let dictionary = object as? [String: Any] else { return [prefix] }
    return dictionary.flatMap { key, value -> [String] in
        let path = prefix.isEmpty ? key : "\(prefix).\(key)"
        if let nested = value as? [String: Any] {
            return leafPaths(nested, prefix: path)
        }
        return [path]
    }.sorted()
}

private func makeCommand() throws -> (command: ConfigurationCommand, url: URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("config.json")
    let store = ConfigurationStore(configURL: url)
    return (ConfigurationCommand(store: store), url)
}

// MARK: - Schema completeness

@Suite struct ConfigurationSchemaTests {
    /// The schema must describe every leaf the model serializes, and must not
    /// describe a setting the model does not have. This is what fails when a new
    /// `DivotConfiguration` field is added without a schema entry.
    @Test func schemaCoversEverySerializedSetting() throws {
        let document = maximalConfiguration().jsonObject
        let serialized = Set(leafPaths(document))
        let declared = Set(ConfigurationSchema.entries.map(\.key))
        #expect(serialized == declared,
                "schema/serialization mismatch: only in document \(serialized.subtracting(declared)); only in schema \(declared.subtracting(serialized))")
    }

    @Test func schemaKeysAreUnique() {
        let keys = ConfigurationSchema.entries.map(\.key)
        #expect(Set(keys).count == keys.count)
        #expect(!keys.isEmpty)
    }

    @Test func maximalConfigurationRoundTripsThroughTheLoader() throws {
        _ = try ConfigurationParser.parse(jsonObject: maximalConfiguration().jsonObject)
    }

    /// Each writable entry's read and write agree, so get/set cannot diverge
    /// from the model.
    @Test func everyWritableEntryReadsBackWhatItWrites() throws {
        let maximal = maximalConfiguration()
        for entry in ConfigurationSchema.entries where entry.writable {
            var configuration = DivotConfiguration.default
            let value = entry.read(maximal)
            try ConfigurationSchema.apply(value, to: entry, in: &configuration)
            #expect(entry.read(configuration) == value, "entry \(entry.key) did not round-trip")
        }
    }

    /// `unset` writes the declared default, so defaults are loadable too.
    @Test func everyWritableEntryAcceptsItsDefault() throws {
        for entry in ConfigurationSchema.entries where entry.writable {
            var configuration = maximalConfiguration()
            try ConfigurationSchema.apply(entry.defaultValue, to: entry, in: &configuration)
            #expect(entry.read(configuration) == entry.defaultValue, "entry \(entry.key) default did not apply")
        }
    }

    @Test func schemaJSONHasKeyTypeDefaultAndDescription() {
        for entry in ConfigurationSchema.jsonObject() {
            #expect(entry["key"] is String)
            #expect(entry["type"] is String)
            #expect(entry["default"] != nil)
            #expect(entry["description"] is String)
            #expect(entry["writable"] is Bool)
        }
    }

    @Test func unknownSettingHasNoEntry() {
        #expect(ConfigurationSchema.entry(for: "widgets.clock.seconds") == nil)
        #expect(ConfigurationSchema.entry(for: "nope") == nil)
    }

    @Test func parseRejectsValuesThatDoNotMatchTheType() {
        let boolean = ConfigurationSchema.entry(for: "widgets.time.seconds")!
        #expect(throws: ConfigurationError.self) { _ = try ConfigurationSchema.parse("maybe", as: boolean) }

        let options = ConfigurationSchema.entry(for: "appearance.family")!
        #expect(throws: ConfigurationError.self) { _ = try ConfigurationSchema.parse("blues", as: options) }

        let hex = ConfigurationSchema.entry(for: "appearance.accent")!
        #expect(throws: ConfigurationError.self) { _ = try ConfigurationSchema.parse("blue", as: hex) }
    }
}

// MARK: - Command round trips

@Suite struct ConfigurationCommandTests {
    @Test func setAndUnsetRoundTripThroughTheFile() throws {
        let (command, url) = try makeCommand()

        let set = command.run(["set", "widgets.time.seconds", "true"])
        #expect(set.exitCode == 0)
        #expect(set.output.contains("widgets.time.seconds = true"))

        let reloaded = ConfigurationStore(configURL: url)
        #expect(reloaded.load() == .loaded)
        #expect(reloaded.current.widgets.time.seconds)

        #expect(command.run(["get", "widgets.time.seconds"]).output == "true")

        let unset = command.run(["unset", "widgets.time.seconds"])
        #expect(unset.exitCode == 0)
        let again = ConfigurationStore(configURL: url)
        #expect(again.load() == .loaded)
        #expect(again.current.widgets.time.seconds == false)
    }

    @Test func setPersistsOptionalAndPaletteValues() throws {
        let (command, url) = try makeCommand()
        #expect(command.run(["set", "widgets.workspaces.maxAppIconsPerWorkspace", "4"]).exitCode == 0)
        #expect(command.run(["set", "appearance.palette.accent", "#B7CEFF"]).exitCode == 0)

        let reloaded = ConfigurationStore(configURL: url)
        #expect(reloaded.load() == .loaded)
        #expect(reloaded.current.widgets.workspaces.maxAppIconsPerWorkspace == 4)
        #expect(reloaded.current.appearance.palette[.accent] == "#B7CEFF")

        #expect(command.run(["unset", "appearance.palette.accent"]).exitCode == 0)
        #expect(command.run(["get", "appearance.palette.accent"]).output == "(unset)")
    }

    @Test func invalidValueIsRejectedAndLeavesTheFileUntouched() throws {
        let (command, url) = try makeCommand()
        #expect(command.run(["set", "layout.height", "32"]).exitCode == 0)
        let before = try Data(contentsOf: url)

        let result = command.run(["set", "layout.height", "900"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("expected 24–40"))
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func invalidEnumNamesTheValidValues() throws {
        let (command, _) = try makeCommand()
        let result = command.run(["set", "appearance.family", "blues"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("native | gruvbox | ayu | dracula | tokyo-night"))
    }

    @Test func readOnlyAndUnknownKeysAreRefused() throws {
        let (command, _) = try makeCommand()
        #expect(command.run(["set", "version", "3"]).exitCode == 1)
        #expect(command.run(["get", "nope"]).exitCode == 1)
        // Usage errors carry exit code 2; a missing key is a usage error.
        #expect(command.run(["get"]).exitCode == 2)
    }

    @Test func dryRunValidatesWithoutCreatingTheFile() throws {
        let (command, url) = try makeCommand()
        let result = command.run(["set", "layout.height", "40", "--dry-run"])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("not written"))
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    @Test func diffShowsTheChangedLine() throws {
        let (command, _) = try makeCommand()
        #expect(command.run(["set", "layout.height", "32"]).exitCode == 0)
        let result = command.run(["set", "layout.height", "40", "--diff"])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("-     \"height\" : 32,"))
        #expect(result.output.contains("+     \"height\" : 40,"))
    }

    @Test func writeIsAtomicAndLeavesNoStagingFile() throws {
        let (command, url) = try makeCommand()
        #expect(command.run(["set", "chipOpacity", "40"]).exitCode == 0)
        let directory = url.deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(contents == ["config.json"])
        // The staged-and-renamed document re-parses as the loader expects.
        _ = try ConfigurationParser.parse(Data(contentsOf: url))
    }

    @Test func editingAnInvalidFileIsRefusedWithoutOverwriting() throws {
        let (command, url) = try makeCommand()
        let invalid = ##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":900,"padding":10},"left":[],"right":[]}"##
        try Data(invalid.utf8).write(to: url)
        let result = command.run(["set", "layout.height", "30"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("layout.height"))
        #expect(try String(contentsOf: url, encoding: .utf8) == invalid)
    }

    @Test func validateReportsAValidFileAndAnInvalidOne() throws {
        let (command, url) = try makeCommand()
        // No file yet: the defaults are valid.
        let defaults = command.run(["validate"])
        #expect(defaults.exitCode == 0)
        #expect(defaults.output.contains("valid"))

        #expect(command.run(["set", "layout.height", "30"]).exitCode == 0)
        #expect(command.run(["validate", "--file", url.path]).exitCode == 0)

        try Data(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":900,"padding":10},"left":[],"right":[]}"##.utf8).write(to: url)
        let invalid = command.run(["validate", "--file", url.path, "--json"])
        #expect(invalid.exitCode == 1)
        #expect(invalid.output.contains("layout.height"))
    }

    @Test func schemaJSONIsMachineReadable() throws {
        let (command, _) = try makeCommand()
        let result = command.run(["schema", "--json"])
        #expect(result.exitCode == 0)
        let data = try #require(result.output.data(using: .utf8))
        let entries = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(entries.count == ConfigurationSchema.entries.count)
    }
}
