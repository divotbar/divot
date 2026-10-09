import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

private func writeConfig(_ json: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("config.json")
    try json.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@Test func optionsLoadFromTheDocumentedConfigFile() throws {
    let url = try writeConfig(#"{"widgets":{"workspaces":{"showEmpty":false,"showAppIcons":true,"showDetails":false,"maxAppIconsPerWorkspace":2}}}"#)
    let options = WorkspaceOptionsStore.load(configURL: url, environment: [:])
    #expect(options == WorkspaceDisplayOptions(showEmpty: false,
                                               showAppIcons: true,
                                               maxAppIconsPerWorkspace: 2,
                                               showDetails: false))
}

@Test func environmentOverridesWinOverTheFile() throws {
    let url = try writeConfig(#"{"widgets":{"workspaces":{"showAppIcons":false,"showDetails":true}}}"#)
    let options = WorkspaceOptionsStore.load(configURL: url,
                                             environment: ["DIVOT_WORKSPACES_SHOW_ICONS": "true",
                                                           "DIVOT_WORKSPACES_SHOW_DETAILS": "off"])
    #expect(options.showAppIcons)
    #expect(!options.showDetails)
}

@Test func missingOrInvalidConfigFallsBackToDefaults() {
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("config.json")
    #expect(WorkspaceOptionsStore.load(configURL: missing, environment: [:]) == .default)

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    #expect(WorkspaceOptionsStore.load(configURL: directory, environment: [:]) == .default)
}

@Test func defaultConfigURLHonorsXDGConfigHome() {
    let xdg = WorkspaceOptionsStore.defaultConfigURL(homeDirectory: "/Users/x",
                                                     environment: ["XDG_CONFIG_HOME": "/tmp/cfg"])
    #expect(xdg.path == "/tmp/cfg/divot/config.json")

    let fallback = WorkspaceOptionsStore.defaultConfigURL(homeDirectory: "/Users/x", environment: [:])
    #expect(fallback.path == "/Users/x/.config/divot/config.json")
}
