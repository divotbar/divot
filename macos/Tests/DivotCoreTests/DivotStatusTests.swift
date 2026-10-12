import Foundation
import Testing
@testable import DivotCore

// MARK: - Fixtures

private let validConfig = ##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["time"],"right":["battery"]}"##

private let invalidConfig = ##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":900,"padding":12},"left":[],"right":[]}"##

/// A fully injected `divot status` environment. Every fact is a parameter so a
/// test never reads the real machine, prompts for a permission, or touches a
/// live window manager.
private func makeEnvironment(version: String = "0.1.0-preview.1",
                             running: Bool = true,
                             accessibility: Bool = true,
                             location: StatusPermissionState = .granted,
                             installed: [WorkspaceManagerKind] = [.aerospace, .yabai],
                             environment: [String: String] = [:],
                             config: String? = nil) throws -> DivotStatusEnvironment {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("config.json")
    if let config { try Data(config.utf8).write(to: url, options: .atomic) }
    return DivotStatusEnvironment(
        version: { version },
        isRunning: { running },
        accessibilityGranted: { accessibility },
        locationState: { location },
        installedManagers: { installed },
        store: ConfigurationStore(configURL: url),
        environment: environment)
}

private func jsonObject(_ outcome: CLIOutcome) throws -> [String: Any] {
    let data = try #require(outcome.output.data(using: .utf8))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

// MARK: - Report

@Suite struct DivotStatusTests {
    @Test func jsonReportsEveryDocumentedField() throws {
        let command = StatusCommand(environment: try makeEnvironment(config: validConfig))
        let object = try jsonObject(command.run(["--json"]))

        #expect(object["version"] as? String == "0.1.0-preview.1")
        #expect(object["running"] as? Bool == true)

        let accessibility = try #require(object["accessibility"] as? [String: Any])
        #expect(accessibility["granted"] as? Bool == true)

        let location = try #require(object["location"] as? [String: Any])
        #expect(location["granted"] as? Bool == true)

        let adapter = try #require(object["workspaceAdapter"] as? [String: Any])
        #expect(adapter["selected"] as? String == "aerospace")
        #expect(adapter["detected"] as? Bool == true)
        #expect(adapter["installed"] as? [String] == ["aerospace", "yabai"])
        #expect(adapter["source"] as? String == "config")

        let config = try #require(object["config"] as? [String: Any])
        #expect(config["valid"] as? Bool == true)
        #expect(config["source"] as? String == "file")
        #expect(config["path"] as? String == command.environment.store.configURL.path)
    }

    @Test func permissionGapsNameTheSystemSettingsPane() throws {
        let command = StatusCommand(environment: try makeEnvironment(accessibility: false,
                                                                     location: .denied))
        let report = command.makeReport()
        #expect(report.accessibility.isGranted == false)
        #expect(report.location.isGranted == false)

        let permissionProblems = report.problems.filter { $0.kind == "permission" }
        #expect(permissionProblems.count == 2)
        #expect(permissionProblems.allSatisfy { $0.settingsURL?.isEmpty == false })
        #expect(permissionProblems.allSatisfy { $0.settingsPane?.isEmpty == false })

        let object = try jsonObject(command.run(["--json"]))
        let problems = try #require(object["problems"] as? [[String: Any]])
        #expect(problems.contains { ($0["settingsURL"] as? String)?.contains("Privacy_Accessibility") == true })
        #expect(problems.contains { ($0["settingsURL"] as? String)?.contains("Privacy_LocationServices") == true })

        // The human-readable form points a person at the pane, and the CLI made
        // no attempt to grant anything.
        let text = command.run([]).output
        #expect(text.contains("System Settings › Privacy & Security › Accessibility"))
        #expect(text.contains("System Settings › Privacy & Security › Location Services"))
    }

    @Test func invalidFileIsReportedWhileTheRunningAppKeepsTheLastGoodConfig() throws {
        let command = StatusCommand(environment: try makeEnvironment(config: invalidConfig))
        let report = command.makeReport()

        #expect(report.config.valid == false)
        #expect(report.config.source == .file)
        #expect(report.config.error?.contains("layout.height") == true)
        #expect(report.problems.contains { $0.kind == "config" })
        #expect(command.run([]).output.contains("invalid"))
    }

    @Test func missingFileUsesTheValidDefaults() throws {
        let command = StatusCommand(environment: try makeEnvironment())

        let report = command.makeReport()
        #expect(report.config.valid == true)
        #expect(report.config.source == .defaults)

        let object = try jsonObject(command.run(["--json"]))
        let config = try #require(object["config"] as? [String: Any])
        #expect(config["source"] as? String == "defaults")
    }

    @Test func environmentOverrideWinsForTheWorkspaceAdapter() throws {
        let command = StatusCommand(environment: try makeEnvironment(
            installed: [.aerospace, .yabai],
            environment: ["DIVOT_WORKSPACES_ADAPTER": "yabai"]))
        let report = command.makeReport()
        #expect(report.workspaceAdapter.selected == .yabai)
        #expect(report.workspaceAdapter.source == "environment")
    }

    @Test func noInstalledManagerIsAnHonestProblem() throws {
        let command = StatusCommand(environment: try makeEnvironment(installed: []))
        let report = command.makeReport()
        #expect(report.workspaceAdapter.detected == false)
        #expect(report.workspaceAdapter.source == "none")
        #expect(report.problems.contains { $0.kind == "workspace" })
    }

    @Test func runningStateAndVersionComeFromTheEnvironment() throws {
        let command = StatusCommand(environment: try makeEnvironment(version: "9.9.9", running: false))
        let object = try jsonObject(command.run(["--json"]))
        #expect(object["version"] as? String == "9.9.9")
        #expect(object["running"] as? Bool == false)
    }

    @Test func usageErrorsExitTwoAndHelpNamesTheCommand() throws {
        let command = StatusCommand(environment: try makeEnvironment())
        #expect(command.run(["--nope"]).exitCode == 2)
        #expect(command.run(["unexpected"]).exitCode == 2)
        #expect(command.run(["--help"]).output.contains("divot status"))
    }
}
