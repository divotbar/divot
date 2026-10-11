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
    #expect(configuration.layout == LayoutConfiguration(height: 28, padding: 10))
    #expect(configuration.widgets.workspaces.showEmpty == false)
    #expect(configuration.widgets.clock == ClockConfiguration(weekday: false, date: true, seconds: false))
}

@Test func networkOptionsDefaultToFalseAndParseExplicitly() throws {
    let defaults = try ConfigurationParser.parse(try exampleData("default.json"))
    #expect(defaults.configuration.widgets.network.showWifiName == false)

    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":[],"right":["network"],"widgets":{"network":{"showWifiName":true}}}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: value)
    #expect(parsed.configuration.widgets.network.showWifiName == true)
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
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[],"extra":true}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "root")
    #expect(failure?.message == "unknown field extra")
}

@Test func menuBarDetectionOptInParsesAndValidates() throws {
    let optedIn = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[],"menuBar":{"trustAccessibilityProbe":true}}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: optedIn)
    #expect(parsed.configuration.menuBar.trustAccessibilityProbe)

    // Absent keeps the conservative shipping default.
    let absent = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[]}"##)
    #expect(try ConfigurationParser.parse(jsonObject: absent).configuration.menuBar == .default)

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[],"menuBar":{"trustAccessibilityProbe":"yes"}}"##)
    let typeFailure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(typeFailure?.path == "menuBar.trustAccessibilityProbe")

    let unknown = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"menuBar":{"unknownField":true}}"##)
    let unknownFailure = error { try ConfigurationParser.parse(jsonObject: unknown) }
    #expect(unknownFailure?.path == "menuBar")
    #expect(unknownFailure?.message == "unknown field unknownField")
}

@Test func menuBarCursorRevealAndFallbackParseAndValidate() throws {
    let configured = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"menuBar":{"moveBelowOnCursorReveal":false,"alwaysBelow":true}}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: configured)
    #expect(parsed.configuration.menuBar.moveBelowOnCursorReveal == false)
    #expect(parsed.configuration.menuBar.alwaysBelow == true)

    // The default document follows the pointer reveal and leaves the fallback off.
    let defaults = try ConfigurationParser.parse(jsonObject: try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[]}"##))
    #expect(defaults.configuration.menuBar == .default)
    #expect(defaults.configuration.menuBar.moveBelowOnCursorReveal)
    #expect(!defaults.configuration.menuBar.alwaysBelow)

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":10},"left":["clock"],"right":[],"menuBar":{"alwaysBelow":"yes"}}"##)
    let typeFailure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(typeFailure?.path == "menuBar.alwaysBelow")
}

@Test func cursorRevealMonitoringIsOnlyNeededWhenItCanAffectPlacement() {
    // Default: reveal on, fallback off — the pointer monitor is useful.
    #expect(MenuBarConfiguration().usesCursorRevealMonitoring)
    // Reveal off: there is no pointer behaviour to follow.
    #expect(!MenuBarConfiguration(moveBelowOnCursorReveal: false).usesCursorRevealMonitoring)
    // Fallback on is authoritative, so a cursor engagement cannot change
    // placement and the monitor is not worth running.
    #expect(!MenuBarConfiguration(alwaysBelow: true).usesCursorRevealMonitoring)
    #expect(!MenuBarConfiguration(moveBelowOnCursorReveal: false, alwaysBelow: true).usesCursorRevealMonitoring)
}

@Test func textSizeAndFontRoundTripAndDeriveTheBarMetrics() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"text":{"size":17,"font":"Menlo"},"left":["clock"],"right":[]}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: value)
    #expect(parsed.configuration.text == TextConfiguration(size: 17, font: "Menlo"))

    // The derived metrics carry the size and font, and the icon scales with it.
    let metrics = parsed.configuration.barMetrics
    #expect(metrics.textFontSize == 17)
    #expect(metrics.iconSize == 19)
    #expect(metrics.fontFamily == "Menlo")

    // Round-trip through the canonical JSON.
    let encoded = try JSONSerialization.data(withJSONObject: parsed.configuration.jsonObject,
                                             options: [.sortedKeys])
    #expect(try ConfigurationParser.parse(encoded).configuration == parsed.configuration)
}

@Test func absentTextUsesTheLargerDefault() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[]}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: value)
    #expect(parsed.configuration.text == .default)
    #expect(parsed.configuration.barMetrics.textFontSize == BarMetrics.defaultTextSize)
}

@Test func anUninstalledFontNameIsAcceptedForRenderTimeFallback() throws {
    // The parser cannot know the installed fonts, so it validates the type and
    // leaves the fallback to the renderer rather than rejecting the document.
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"text":{"font":"No Such Font"},"left":["clock"],"right":[]}"##)
    #expect(try ConfigurationParser.parse(jsonObject: value).configuration.text.font == "No Such Font")
}

@Test func outOfRangeTextSizeIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"text":{"size":99},"left":["clock"],"right":[]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "text.size")
    #expect(failure?.message == "expected 10–20")
}

@Test func nonStringTextFontIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"text":{"font":12},"left":["clock"],"right":[]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "text.font")
    #expect(failure?.message == "expected string")
}

@Test func outOfRangeLayoutIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":80,"padding":12},"left":["clock"],"right":[]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "layout.height")
    #expect(failure?.message == "expected 24–40")
}

@Test func duplicateItemAcrossGroupsIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":["clock"]}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "left/right")
}

@Test func unknownWidgetNamespaceIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[],"widgets":{"weather":{}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets")
    #expect(failure?.message == "unknown field weather")
}

@Test func unknownWidgetOptionIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[],"widgets":{"clock":{"timezone":"UTC"}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.clock")
    #expect(failure?.message == "unknown field timezone")
}

@Test func optionsForAnUnplacedItemAreRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"widgets":{"front-app":{"showIcon":false}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.front-app")
    #expect(failure?.message == "not placed on left or right")
}

@Test func invalidAppearanceValuesAreRejected() throws {
    let badFamily = try json(##"{"version":2,"appearance":{"family":"solarized","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[]}"##)
    #expect(error { try ConfigurationParser.parse(jsonObject: badFamily) }?.path == "appearance.family")

    let badHex = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[]}"##)
    #expect(error { try ConfigurationParser.parse(jsonObject: badHex) }?.path == "appearance.accent")

    let badMode = try json(##"{"version":2,"appearance":{"family":"native","mode":"twilight","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[]}"##)
    #expect(error { try ConfigurationParser.parse(jsonObject: badMode) }?.path == "appearance.mode")
}

@Test func nonBooleanOptionIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["clock"],"right":[],"widgets":{"clock":{"seconds":"yes"}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.clock.seconds")
    #expect(failure?.message == "expected boolean")
}

@Test func maxAppIconsIsRangeChecked() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"widgets":{"workspaces":{"maxAppIconsPerWorkspace":99}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.workspaces.maxAppIconsPerWorkspace")
    #expect(failure?.message == "expected 0–32")
}

@Test func legacyNotchGapIsIgnoredAndNotRewritten() throws {
    let legacy = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12,"notchGap":15},"left":["clock"],"right":[]}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: legacy)
    #expect(parsed.configuration.layout == LayoutConfiguration(height: 32, padding: 12))
    #expect(parsed.configuration.layout.contentPolicy.clearance == 0)
}

@Test func eitherSupportedWorkspaceAdapterParses() throws {
    let yabai = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"widgets":{"workspaces":{"adapter":"yabai"}}}"##)
    #expect(try ConfigurationParser.parse(jsonObject: yabai)
        .configuration.widgets.workspaces.adapter == .yabai)

    let aero = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"widgets":{"workspaces":{"adapter":"aerospace"}}}"##)
    #expect(try ConfigurationParser.parse(jsonObject: aero)
        .configuration.widgets.workspaces.adapter == .aerospace)
}

@Test func unknownWorkspaceAdapterIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"widgets":{"workspaces":{"adapter":"amphibian"}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.workspaces.adapter")
    #expect(failure?.message == "expected aerospace | yabai")
}

@Test func batteryOptionsMustBeAnEmptyObject() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":[],"right":["battery"],"widgets":{"battery":{"showIcon":true}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.battery")
    #expect(failure?.message == "unknown field showIcon")
}

@Test func volumeOptionsParseAndValidate() throws {
    let configured = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"right":["volume"],"left":[],"widgets":{"volume":{"showVolumePercent":false,"showVolumeMuted":true}}}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: configured)
    #expect(parsed.configuration.widgets.volume.showVolumePercent == false)
    #expect(parsed.configuration.widgets.volume.showVolumeMuted == true)

    // Defaults are both true
    let defaults = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"right":["volume"],"left":[]}"##)
    let parsedDefaults = try ConfigurationParser.parse(jsonObject: defaults)
    #expect(parsedDefaults.configuration.widgets.volume == VolumeConfiguration.default)
    #expect(parsedDefaults.configuration.widgets.volume.showVolumePercent == true)
    #expect(parsedDefaults.configuration.widgets.volume.showVolumeMuted == true)
}

@Test func volumeOptionsMustBeBoolean() throws {
    let badType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"right":["volume"],"left":[],"widgets":{"volume":{"showVolumePercent":"yes"}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: badType) }
    #expect(failure?.path == "widgets.volume.showVolumePercent")
    #expect(failure?.message == "expected boolean")
}

@Test func volumeUnknownOptionIsRejected() throws {
    let value = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"right":["volume"],"left":[],"widgets":{"volume":{"unknownField":true}}}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: value) }
    #expect(failure?.path == "widgets.volume")
    #expect(failure?.message == "unknown field unknownField")
}

@Test func keepAwakePreferenceDefaultsOffAndParsesExplicitly() throws {
    let without = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":["battery"]}"##)
    #expect(try ConfigurationParser.parse(jsonObject: without).configuration.keepAwake == .default)

    let withValue = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":["battery"],"keepAwake":{"remember":true,"isActive":true}}"##)
    #expect(try ConfigurationParser.parse(jsonObject: withValue).configuration.keepAwake
        == KeepAwakeConfiguration(remember: true, isActive: true))
}

@Test func keepAwakeRejectsUnknownAndWronglyTypedFields() throws {
    let unknown = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"keepAwake":{"forever":true}}"##)
    let unknownFailure = error { try ConfigurationParser.parse(jsonObject: unknown) }
    #expect(unknownFailure?.path == "keepAwake")
    #expect(unknownFailure?.message == "unknown field forever")

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"keepAwake":{"remember":"yes"}}"##)
    let typeFailure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(typeFailure?.path == "keepAwake.remember")
    #expect(typeFailure?.message == "expected boolean")
}

@Test func keepAwakeExampleRoundTrips() throws {
    let parsed = try ConfigurationParser.parse(try exampleData("keep-awake.json"))
    #expect(parsed.configuration.keepAwake == KeepAwakeConfiguration(remember: true, isActive: true))
    #expect(parsed.configuration.isPlaced(.battery))
}

@Test func appIconOptInDefaultsOffAndParsesExplicitly() throws {
    // Absent keeps the first-launch bar unchanged.
    let without = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[]}"##)
    #expect(try ConfigurationParser.parse(jsonObject: without).configuration.showAppIcon == false)

    let withValue = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"showAppIcon":true}"##)
    #expect(try ConfigurationParser.parse(jsonObject: withValue).configuration.showAppIcon)

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"showAppIcon":"yes"}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(failure?.path == "showAppIcon")
    #expect(failure?.message == "expected boolean")
}

@Test func appIconOptInRoundTripsThroughTheCanonicalJSON() throws {
    var configuration = DivotConfiguration.default
    configuration.showAppIcon = true
    let encoded = try JSONSerialization.data(withJSONObject: configuration.jsonObject,
                                             options: [.sortedKeys])
    let reparsed = try ConfigurationParser.parse(encoded)
    #expect(reparsed.configuration == configuration)
    #expect(reparsed.configuration.showAppIcon)

    // The default writes no key, so the first-launch document is identical.
    #expect(DivotConfiguration.default.jsonObject["showAppIcon"] == nil)
}

@Test func appIconExampleRoundTrips() throws {
    let parsed = try ConfigurationParser.parse(try exampleData("app-icon.json"))
    #expect(parsed.configuration.showAppIcon)
    // Everything else stays at the first-launch shape.
    #expect(parsed.configuration.left == DivotConfiguration.defaultLeft)
}

@Test func appIconOptInChangesWhatTheRenderedBarNeeds() {
    // Toggling the icon must rebuild the left panel, so `rendersSameBar` has to
    // see the change; otherwise the setting would not apply live.
    var configuration = DivotConfiguration.default
    #expect(configuration.rendersSameBar(as: .default))
    configuration.showAppIcon = true
    #expect(!configuration.rendersSameBar(as: .default))
}

@Test func workspaceDotTogglesDefaultOnAndParseExplicitly() throws {
    // Absent keeps the first-launch look: both dots on.
    let without = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[]}"##)
    let defaults = try ConfigurationParser.parse(jsonObject: without).configuration
    #expect(defaults.showOccupiedDot)
    #expect(defaults.showEmptyDot)

    let withValue = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"showOccupiedDot":false,"showEmptyDot":true}"##)
    let parsed = try ConfigurationParser.parse(jsonObject: withValue).configuration
    #expect(!parsed.showOccupiedDot)
    #expect(parsed.showEmptyDot)

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"showEmptyDot":"yes"}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(failure?.path == "showEmptyDot")
    #expect(failure?.message == "expected boolean")
}

@Test func workspaceDotTogglesRoundTripThroughTheCanonicalJSON() throws {
    var configuration = DivotConfiguration.default
    configuration.showOccupiedDot = false
    configuration.showEmptyDot = false
    let encoded = try JSONSerialization.data(withJSONObject: configuration.jsonObject,
                                             options: [.sortedKeys])
    let reparsed = try ConfigurationParser.parse(encoded)
    #expect(reparsed.configuration == configuration)
    #expect(!reparsed.configuration.showOccupiedDot)
    #expect(!reparsed.configuration.showEmptyDot)

    // Both on (the default) writes no key, so the first-launch document is
    // identical.
    #expect(DivotConfiguration.default.jsonObject["showOccupiedDot"] == nil)
    #expect(DivotConfiguration.default.jsonObject["showEmptyDot"] == nil)
}

@Test func workspaceDotTogglesChangeWhatTheRenderedBarNeeds() {
    // Hiding a marker must rebuild the panel so the setting applies live;
    // `rendersSameBar` therefore has to see the change.
    var configuration = DivotConfiguration.default
    #expect(configuration.rendersSameBar(as: .default))
    configuration.showOccupiedDot = false
    #expect(!configuration.rendersSameBar(as: .default))
    configuration.showEmptyDot = false
    #expect(!DivotConfiguration.default.rendersSameBar(as: configuration))
}

@Test func bottomShadowOptInDefaultsOffAndParsesExplicitly() throws {
    // Absent keeps the first-launch bar unshadowed.
    let without = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[]}"##)
    #expect(try ConfigurationParser.parse(jsonObject: without).configuration.bottomShadow == false)

    let withValue = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"bottomShadow":true}"##)
    #expect(try ConfigurationParser.parse(jsonObject: withValue).configuration.bottomShadow)

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"bottomShadow":"yes"}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(failure?.path == "bottomShadow")
    #expect(failure?.message == "expected boolean")
}

@Test func bottomShadowOptInRoundTripsThroughTheCanonicalJSON() throws {
    var configuration = DivotConfiguration.default
    configuration.bottomShadow = true
    let encoded = try JSONSerialization.data(withJSONObject: configuration.jsonObject,
                                             options: [.sortedKeys])
    let reparsed = try ConfigurationParser.parse(encoded)
    #expect(reparsed.configuration == configuration)
    #expect(reparsed.configuration.bottomShadow)

    // The default writes no key, so the first-launch document is identical.
    #expect(DivotConfiguration.default.jsonObject["bottomShadow"] == nil)
}

@Test func bottomShadowOptInChangesWhatTheRenderedBarNeeds() {
    // The shadow is panel chrome, so toggling it must rebuild the panel and
    // apply live; `rendersSameBar` therefore has to see the change.
    var configuration = DivotConfiguration.default
    #expect(configuration.rendersSameBar(as: .default))
    configuration.bottomShadow = true
    #expect(!configuration.rendersSameBar(as: .default))
}

@Test func chipStyleOptInDefaultsOffAndParsesExplicitly() throws {
    // Absent keeps items blended.
    let without = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[]}"##)
    #expect(try ConfigurationParser.parse(jsonObject: without).configuration.chipStyle == false)

    let withValue = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"chipStyle":true}"##)
    #expect(try ConfigurationParser.parse(jsonObject: withValue).configuration.chipStyle)

    let wrongType = try json(##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":[],"chipStyle":"yes"}"##)
    let failure = error { try ConfigurationParser.parse(jsonObject: wrongType) }
    #expect(failure?.path == "chipStyle")
}

@Test func chipStyleOptInRoundTripsThroughTheCanonicalJSON() throws {
    var configuration = DivotConfiguration.default
    configuration.chipStyle = true
    let encoded = try JSONSerialization.data(withJSONObject: configuration.jsonObject,
                                             options: [.sortedKeys])
    let reparsed = try ConfigurationParser.parse(encoded)
    #expect(reparsed.configuration == configuration)
    #expect(reparsed.configuration.chipStyle)

    // The default writes no key, so the first-launch document is identical.
    #expect(DivotConfiguration.default.jsonObject["chipStyle"] == nil)
}

@Test func chipStyleChangesMakesTheBarsRenderDifferently() {
    // Chip style changes item layout and drawing, so toggling it must rebuild
    // the panels; `rendersSameBar` therefore has to see the change.
    var configuration = DivotConfiguration.default
    #expect(configuration.rendersSameBar(as: .default))
    configuration.chipStyle = true
    #expect(!configuration.rendersSameBar(as: .default))
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
