import Foundation
import Testing
@testable import DivotCore

/// A fake appearance-settings seam that records writes and can replay a change
/// made elsewhere, so the popover model is tested without a real config file.
@MainActor
private final class FakeAppearanceSettings: AppearanceSettingsControlling {
    var appearance: AppearanceConfiguration
    private(set) var configuration: DivotConfiguration
    private var observers: [UUID: (DivotConfiguration) -> Void] = [:]

    private(set) var modeWrites: [AppearanceConfiguration.Mode] = []
    private(set) var familyWrites: [AppearanceConfiguration.Family] = []
    private(set) var removedObservers: [UUID] = []

    init(appearance: AppearanceConfiguration = .default) {
        var configuration = DivotConfiguration.default
        configuration.appearance = appearance
        self.appearance = appearance
        self.configuration = configuration
    }

    var observerCount: Int { observers.count }

    func setAppearanceMode(_ mode: AppearanceConfiguration.Mode) {
        modeWrites.append(mode)
        appearance.mode = mode
        configuration.appearance = appearance
    }

    func setAppearanceFamily(_ family: AppearanceConfiguration.Family) {
        familyWrites.append(family)
        appearance.family = family
        configuration.appearance = appearance
    }

    @discardableResult
    func addObserver(_ observer: @escaping (DivotConfiguration) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(_ id: UUID) {
        removedObservers.append(id)
        observers[id] = nil
    }

    /// Simulate a change made elsewhere (Settings window or file watcher).
    func changeElsewhere(to appearance: AppearanceConfiguration) {
        self.appearance = appearance
        configuration.appearance = appearance
        for observer in observers.values { observer(configuration) }
    }
}

@Suite("Appearance popover model")
@MainActor
struct AppearancePopoverModelTests {
    @Test func readsTheCurrentSelectionOnInit() {
        let settings = FakeAppearanceSettings(
            appearance: AppearanceConfiguration(family: .gruvbox, mode: .dark))
        let model = AppearancePopoverModel(settings: settings)

        #expect(model.family == .gruvbox)
        #expect(model.mode == .dark)
    }

    @Test func listsComeFromTheConfigurationEnums() {
        let model = AppearancePopoverModel(settings: FakeAppearanceSettings())

        #expect(model.families == AppearanceConfiguration.Family.allCases)
        #expect(model.modes == AppearanceConfiguration.Mode.allCases)
    }

    @Test func selectingAModeWritesAndReflectsTheSettledValue() {
        let settings = FakeAppearanceSettings()
        let model = AppearancePopoverModel(settings: settings)
        var changes = 0
        model.onChange = { changes += 1 }

        #expect(model.select(.light) == .light)
        #expect(settings.modeWrites == [.light])
        #expect(model.mode == .light)
        // A selection is the presenter's own write; it must not double-render.
        #expect(changes == 0)
    }

    @Test func selectingAFamilyWritesAndReflectsTheSettledValue() {
        let settings = FakeAppearanceSettings()
        let model = AppearancePopoverModel(settings: settings)

        #expect(model.select(.tokyoNight) == .tokyoNight)
        #expect(settings.familyWrites == [.tokyoNight])
        #expect(model.family == .tokyoNight)
    }

    @Test func followsAChangeMadeElsewhereWhileOpen() {
        let settings = FakeAppearanceSettings()
        let model = AppearancePopoverModel(settings: settings)
        var changes = 0
        model.onChange = { changes += 1 }
        model.startObserving()

        // The Settings window (or a file edit) picks a different family/mode.
        settings.changeElsewhere(to: AppearanceConfiguration(family: .dracula, mode: .dark))

        #expect(model.family == .dracula)
        #expect(model.mode == .dark)
        #expect(changes == 1)
    }

    @Test func refreshPicksUpAChangeMadeBeforeObserving() {
        let settings = FakeAppearanceSettings()
        let model = AppearancePopoverModel(settings: settings)

        settings.changeElsewhere(to: AppearanceConfiguration(family: .ayu, mode: .light))
        model.refresh()

        #expect(model.family == .ayu)
        #expect(model.mode == .light)
    }

    @Test func stoppingObservationRemovesTheObserverOnce() {
        let settings = FakeAppearanceSettings()
        let model = AppearancePopoverModel(settings: settings)

        model.startObserving()
        model.startObserving()
        #expect(settings.observerCount == 1)

        model.stopObserving()
        #expect(settings.observerCount == 0)
        #expect(settings.removedObservers.count == 1)

        // Observing again re-registers a fresh observer.
        model.startObserving()
        model.stopObserving()
        #expect(settings.removedObservers.count == 2)
    }

    @Test func aClosedPopoverDoesNotFollowLaterChanges() {
        let settings = FakeAppearanceSettings()
        let model = AppearancePopoverModel(settings: settings)
        model.startObserving()
        model.stopObserving()

        settings.changeElsewhere(to: AppearanceConfiguration(family: .gruvbox, mode: .dark))

        #expect(model.family == .native)
    }
}
