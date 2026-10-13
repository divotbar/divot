import Foundation
import DivotCore

/// Owns the configuration store and publishes validated snapshots.
///
/// It is the single seam between the file and every consumer: the display
/// coordinator, the provider pipeline, the workspace feed, and the settings
/// window all read the same published configuration. A bad edit or a bad file
/// leaves the published snapshot untouched and exposes the field error instead.
@MainActor
public final class ConfigurationController {
    /// The active validated configuration, defaults included.
    public private(set) var configuration: DivotConfiguration
    /// The field error from the most recent failed load or save, or `nil`.
    public private(set) var lastError: ConfigurationError?
    /// The outcome of the most recent load.
    public private(set) var lastOutcome: ConfigurationStore.Outcome

    /// Called on the main actor when the published configuration changes.
    public var onChange: ((DivotConfiguration) -> Void)?
    /// Called on the main actor after every load attempt (valid or not).
    public var onOutcome: ((ConfigurationStore.Outcome) -> Void)?

    private var observers: [UUID: (DivotConfiguration) -> Void] = [:]
    private let store: ConfigurationStore
    private let watcher: ConfigurationFileWatcher

    public init(store: ConfigurationStore = ConfigurationStore()) {
        self.store = store
        self.configuration = store.current
        self.lastOutcome = store.lastOutcome
        self.lastError = nil
        self.watcher = ConfigurationFileWatcher(configURL: store.configURL)
    }

    /// Register additional observers, so the settings window and the app
    /// coordinator both track the same published snapshot.
    @discardableResult
    public func addObserver(_ observer: @escaping (DivotConfiguration) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    public func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    /// The resolved config file location, for diagnostics and the settings UI.
    public var configURL: URL { store.configURL }

    /// Start observing the file for external edits.
    public func startWatching() {
        watcher.start { [weak self] in
            Task { @MainActor in self?.reload() }
        }
    }

    public func stopWatching() {
        watcher.stop()
    }

    /// Load synchronously. Used at launch and by tests.
    @discardableResult
    public func reload() -> ConfigurationStore.Outcome {
        let outcome = store.load()
        handle(outcome)
        return outcome
    }

    /// Load away from the main thread, then publish on the main actor so the
    /// launch path never parses on the UI thread.
    public func reloadAsync() {
        let store = self.store
        Task.detached { [weak self] in
            let outcome = store.load()
            await MainActor.run { self?.handle(outcome) }
        }
    }

    /// Validate, persist, and publish a settings edit. An invalid edit is
    /// refused: the current configuration stays active and the error is
    /// surfaced, so the bar never picks up a broken document.
    @discardableResult
    public func save(_ candidate: DivotConfiguration) -> Result<DivotConfiguration, ConfigurationError> {
        do {
            try store.save(candidate)
        } catch let error as ConfigurationError {
            lastError = error
            return .failure(error)
        } catch {
            let wrapped = ConfigurationError(path: "root", message: "\(error)")
            lastError = wrapped
            return .failure(wrapped)
        }
        lastError = nil
        configuration = candidate
        lastOutcome = .loaded
        publish(candidate)
        return .success(candidate)
    }

    /// Convenience for settings: mutate the current snapshot and save it.
    @discardableResult
    public func update(_ mutate: (inout DivotConfiguration) -> Void)
        -> Result<DivotConfiguration, ConfigurationError> {
        var candidate = configuration
        mutate(&candidate)
        return save(candidate)
    }

    private func handle(_ outcome: ConfigurationStore.Outcome) {
        lastOutcome = outcome
        switch outcome {
        case .defaults, .loaded, .migrated:
            lastError = nil
            let newValue = store.current
            if newValue != configuration {
                configuration = newValue
                publish(newValue)
            }
        case .invalid(let error):
            // Keep the last good snapshot published; only report the error.
            lastError = error
        }
        onOutcome?(outcome)
    }

    private func publish(_ configuration: DivotConfiguration) {
        onChange?(configuration)
        for observer in observers.values { observer(configuration) }
    }
}

// MARK: - Appearance popover seam

/// The appearance popover reads and writes the same published configuration as
/// the Settings window, so the two never disagree. The write helpers mutate the
/// `appearance` block through `update`, which validates, persists atomically, and
/// publishes; the observer pair is the controller's existing one.
extension ConfigurationController: AppearanceSettingsControlling {
    public var appearance: AppearanceConfiguration { configuration.appearance }

    public func setAppearanceMode(_ mode: AppearanceConfiguration.Mode) {
        update { $0.appearance.mode = mode }
    }

    public func setAppearanceFamily(_ family: AppearanceConfiguration.Family) {
        update { $0.appearance.family = family }
    }
}
