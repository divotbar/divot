import Foundation
import Testing
@testable import DivotCore

// MARK: - Fixtures

/// One temporary config file shared by the `items`, `theme`, and `config`
/// commands, so a test observes exactly what the helpers wrote.
private func makeStore() throws -> (store: ConfigurationStore, url: URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("config.json")
    return (ConfigurationStore(configURL: url), url)
}

private func jsonObject(_ outcome: CLIOutcome) throws -> [String: Any] {
    let data = try #require(outcome.output.data(using: .utf8))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

// MARK: - Items

@Suite struct ItemsCommandTests {
    @Test func listReportsBothGroupsInTextAndJSON() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        let text = command.run(["list"])
        #expect(text.exitCode == 0)
        #expect(text.output.contains("left: workspaces, front-app"))
        #expect(text.output.contains("right: battery, time, network, volume"))

        let object = try jsonObject(command.run(["list", "--json"]))
        #expect(object["left"] as? [String] == ["workspaces", "front-app"])
        #expect(object["right"] as? [String] == ["battery", "time", "network", "volume"])
    }

    @Test func addAppendsToTheRightAndPersists() throws {
        let (store, url) = try makeStore()
        let command = ItemsCommand(store: store)

        let result = command.run(["add", "date"])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("added date to right"))

        let reloaded = ConfigurationStore(configURL: url)
        #expect(reloaded.load() == .loaded)
        #expect(reloaded.current.right == [.battery, .time, .network, .volume, .date])
        #expect(reloaded.current.left == [.workspaces, .frontApp])
    }

    @Test func addHonorsSideAndIndex() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        #expect(command.run(["add", "date", "--side", "left", "--at", "0"]).exitCode == 0)
        #expect(store.current.left == [.date, .workspaces, .frontApp])

        #expect(command.run(["add", "appearance", "--side=left", "--at=1"]).exitCode == 0)
        #expect(store.current.left == [.date, .appearance, .workspaces, .frontApp])
    }

    @Test func unknownAndLegacyItemsAreRejected() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        let unknown = command.run(["add", "nope"])
        #expect(unknown.exitCode == 1)
        #expect(unknown.output.contains("unknown item 'nope'"))
        #expect(unknown.output.contains("workspaces | front-app"))

        let clock = command.run(["add", "clock"])
        #expect(clock.exitCode == 1)
        #expect(clock.output.contains("unknown item 'clock'"))
    }

    @Test func addingAPlacedItemIsRefused() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        let result = command.run(["add", "workspaces"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("already placed"))
    }

    @Test func anOutOfRangeIndexIsRefused() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        let tooHigh = command.run(["add", "date", "--at", "99"])
        #expect(tooHigh.exitCode == 1)
        #expect(tooHigh.output.contains("expected --at 0–4"))

        let negative = command.run(["add", "date", "--at", "-1"])
        #expect(negative.exitCode == 2)
        #expect(negative.output.contains("non-negative"))
    }

    @Test func removeClearsItemOptionsAndStaysValid() throws {
        let (store, url) = try makeStore()
        let command = ConfigurationCommand(store: store)
        let items = ItemsCommand(store: store)

        // Workspaces options are only valid while the item is placed, so the
        // remove must clear them to keep the document loadable.
        #expect(command.run(["set", "widgets.workspaces.showEmpty", "false"]).exitCode == 0)

        let removed = items.run(["remove", "workspaces"])
        #expect(removed.exitCode == 0)
        #expect(removed.output.contains("removed workspaces"))

        let reloaded = ConfigurationStore(configURL: url)
        #expect(reloaded.load() == .loaded)
        #expect(reloaded.current.left == [.frontApp])
        #expect(reloaded.current.widgets.workspaces == .default)
    }

    @Test func removeAndMoveRejectUnplacedItems() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        let removed = command.run(["remove", "date"])
        #expect(removed.exitCode == 1)
        #expect(removed.output.contains("'date' is not placed"))

        let moved = command.run(["move", "date"])
        #expect(moved.exitCode == 1)
        #expect(moved.output.contains("use `divot items add`"))
    }

    @Test func moveChangesSideAndReorders() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        // The default side is kept when --side is omitted, so a bare move to an
        // index is a reorder within the current group.
        #expect(command.run(["move", "front-app", "--at", "0"]).exitCode == 0)
        #expect(store.current.left == [.frontApp, .workspaces])

        #expect(command.run(["move", "front-app", "--side", "right", "--at", "0"]).exitCode == 0)
        #expect(store.current.left == [.workspaces])
        #expect(store.current.right == [.frontApp, .battery, .time, .network, .volume])
    }

    @Test func moveKeepsTheSideTheFileAssigns() throws {
        let (store, url) = try makeStore()
        // The file puts front-app on the right, unlike the first-launch default,
        // so a move without --side must read the file before choosing a side.
        let document = ##"{"version":2,"appearance":{"family":"native","mode":"system","accent":"#D6F58A","material":"native"},"layout":{"height":32,"padding":12},"left":["workspaces"],"right":["front-app","battery"]}"##
        try Data(document.utf8).write(to: url)
        let command = ItemsCommand(store: store)

        #expect(command.run(["move", "front-app", "--at", "1"]).exitCode == 0)
        #expect(store.current.left == [.workspaces])
        #expect(store.current.right == [.battery, .frontApp])
    }

    @Test func jsonReportsTheNewGroups() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        let object = try jsonObject(command.run(["add", "date", "--json"]))
        #expect(object["action"] as? String == "added date to right")
        #expect(object["right"] as? [String] == ["battery", "time", "network", "volume", "date"])
        #expect(object["path"] is String)
    }

    @Test func usageErrorsCarryExitCodeTwo() throws {
        let (store, _) = try makeStore()
        let command = ItemsCommand(store: store)

        #expect(command.run([]).exitCode == 2)
        #expect(command.run(["bogus"]).exitCode == 2)
        #expect(command.run(["add"]).exitCode == 2)
        #expect(command.run(["add", "date", "--side", "middle"]).exitCode == 2)
        #expect(command.run(["list", "extra"]).exitCode == 2)
    }
}

// MARK: - Theme

@Suite struct ThemeCommandTests {
    @Test func showReportsCurrentFamilyAndMode() throws {
        let (store, _) = try makeStore()
        let command = ThemeCommand(store: store)

        #expect(command.run(["show"]).output == "family: native\nmode: system")
        let object = try jsonObject(command.run(["show", "--json"]))
        #expect(object["family"] as? String == "native")
        #expect(object["mode"] as? String == "system")
    }

    @Test func setPersistsFamilyAndMode() throws {
        let (store, url) = try makeStore()
        let command = ThemeCommand(store: store)

        let result = command.run(["set", "gruvbox", "--mode", "dark"])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("family: gruvbox"))
        #expect(result.output.contains("mode: dark"))

        let reloaded = ConfigurationStore(configURL: url)
        #expect(reloaded.load() == .loaded)
        #expect(reloaded.current.appearance.family == .gruvbox)
        #expect(reloaded.current.appearance.mode == .dark)
        #expect(reloaded.current.appearance.accent == AppearanceConfiguration.defaultAccent)
    }

    @Test func setKeepsTheModeWhenOmitted() throws {
        let (store, _) = try makeStore()
        let command = ThemeCommand(store: store)

        #expect(command.run(["set", "tokyo-night", "--mode", "light"]).exitCode == 0)
        #expect(command.run(["set", "dracula"]).exitCode == 0)
        #expect(store.current.appearance.family == .dracula)
        #expect(store.current.appearance.mode == .light)
    }

    @Test func invalidFamilyAndModeAreRejected() throws {
        let (store, url) = try makeStore()
        let command = ThemeCommand(store: store)

        let family = command.run(["set", "blues"])
        #expect(family.exitCode == 1)
        #expect(family.output.contains("native | gruvbox | ayu | dracula | tokyo-night"))

        let mode = command.run(["set", "gruvbox", "--mode", "dusk"])
        #expect(mode.exitCode == 1)
        #expect(mode.output.contains("expected system | dark | light"))
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    @Test func jsonSetReportsTheWrittenValueAndPath() throws {
        let (store, _) = try makeStore()
        let command = ThemeCommand(store: store)

        let object = try jsonObject(command.run(["set", "ayu", "--mode", "light", "--json"]))
        #expect(object["family"] as? String == "ayu")
        #expect(object["mode"] as? String == "light")
        #expect(object["path"] is String)
    }

    @Test func usageErrorsCarryExitCodeTwo() throws {
        let (store, _) = try makeStore()
        let command = ThemeCommand(store: store)

        #expect(command.run([]).exitCode == 2)
        #expect(command.run(["bogus"]).exitCode == 2)
        #expect(command.run(["set"]).exitCode == 2)
        #expect(command.run(["set", "gruvbox", "--mode"]).exitCode == 2)
        #expect(command.run(["show", "extra"]).exitCode == 2)
    }
}
