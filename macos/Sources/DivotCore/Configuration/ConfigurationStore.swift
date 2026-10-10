import Foundation

// MARK: - Location

/// Where the configuration file lives.
public enum DivotConfigLocation {
    /// `$XDG_CONFIG_HOME/divot/config.json` when set, else
    /// `~/.config/divot/config.json`.
    public static func defaultURL(homeDirectory: String = NSHomeDirectory(),
                                  environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg).appendingPathComponent("divot/config.json")
        }
        return URL(fileURLWithPath: homeDirectory).appendingPathComponent(".config/divot/config.json")
    }
}

// MARK: - Store

/// Owns the on-disk configuration document and its last-good in-memory copy.
///
/// Reads validate before applying: a missing file uses the native defaults, a
/// valid file becomes the current snapshot, and an invalid file reports its
/// field error while the last good snapshot keeps running. Writes are validated
/// and atomic (Foundation's atomic write stages a sibling temp file and renames
/// it), so a crash mid-write can never leave a half-written document.
///
/// Version 1 documents are migrated explicitly: the original is backed up next
/// to the file before the version 2 document replaces it.
public final class ConfigurationStore: @unchecked Sendable {
    /// What the most recent `load()` did.
    public enum Outcome: Equatable, Sendable {
        /// No file was present; the native defaults are active.
        case defaults
        /// A version 2 document loaded.
        case loaded
        /// A supported older document was migrated; `backupURL` holds the original.
        case migrated(fromVersion: Int, backupURL: URL)
        /// The document was rejected; the last good snapshot is still active.
        case invalid(ConfigurationError)
    }

    public let configURL: URL
    /// The active configuration: defaults, a loaded document, or the last good
    /// document when the newest read failed.
    public private(set) var current: DivotConfiguration
    public private(set) var lastOutcome: Outcome

    private let backupURL: URL
    private let fileManager: FileManager
    private let writeData: (Data, URL) throws -> Void
    private let lock = NSLock()

    public convenience init(configURL: URL = DivotConfigLocation.defaultURL(),
                            fileManager: FileManager = .default) {
        self.init(configURL: configURL,
                  fileManager: fileManager,
                  writeData: ConfigurationStore.atomicWrite)
    }

    /// Designated initializer. `writeData` is a seam so a test can force a disk
    /// failure deterministically; production passes the atomic writer.
    init(configURL: URL,
         fileManager: FileManager,
         writeData: @escaping (Data, URL) throws -> Void) {
        self.configURL = configURL
        self.fileManager = fileManager
        self.writeData = writeData
        self.current = .default
        self.lastOutcome = .defaults
        let base = configURL.deletingPathExtension().lastPathComponent
        let ext = configURL.pathExtension.isEmpty ? "json" : configURL.pathExtension
        self.backupURL = configURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-v1-backup.\(ext)")
    }

    /// Foundation's atomic write stages a sibling temp file and renames it, so a
    /// crash mid-write can never leave a half-written document.
    static func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    /// Read the file and update the active snapshot. Never throws: the outcome
    /// carries either the new snapshot or the field error to explain.
    ///
    /// `current` only advances once a document is accepted *and* any required
    /// migration has been durably written. A failed migration therefore leaves
    /// the previous last-good snapshot active, so a later settings save can
    /// never persist from a half-applied in-memory state.
    @discardableResult
    public func load() -> Outcome {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: configURL.path) else {
            current = .default
            lastOutcome = .defaults
            return lastOutcome
        }

        let parsed: ParsedConfiguration
        do {
            parsed = try ConfigurationParser.parse(Data(contentsOf: configURL))
        } catch let error as ConfigurationError {
            lastOutcome = .invalid(error)
            return lastOutcome
        } catch {
            lastOutcome = .invalid(ConfigurationError(path: "root", message: "\(error)"))
            return lastOutcome
        }

        if let fromVersion = parsed.migratedFromVersion {
            // Back up the original before it is overwritten, then write the
            // version 2 document. Only after both succeed does the migrated
            // configuration become current; a failure keeps the last good
            // snapshot and reports it.
            do {
                let backup = try backupOriginal()
                try write(parsed.configuration)
                current = parsed.configuration
                lastOutcome = .migrated(fromVersion: fromVersion, backupURL: backup)
            } catch {
                lastOutcome = .invalid(ConfigurationError(path: "root",
                                                          message: "migration could not be written: \(error)"))
            }
            return lastOutcome
        }

        current = parsed.configuration
        lastOutcome = .loaded
        return lastOutcome
    }

    /// Validate and atomically write `configuration`, then make it current.
    /// Throws a `ConfigurationError` when the document would be invalid, so an
    /// invalid settings edit is refused instead of persisted.
    public func save(_ configuration: DivotConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }
        try validate(configuration)
        try write(configuration)
        current = configuration
        lastOutcome = .loaded
    }

    /// The canonical UTF-8 JSON for a configuration, without writing it.
    public func data(for configuration: DivotConfiguration) throws -> Data {
        try validate(configuration)
        return try encode(configuration)
    }

    // MARK: - Private

    /// Round-trip the configuration through the parser so a save can never
    /// persist a document the loader would reject.
    private func validate(_ configuration: DivotConfiguration) throws {
        _ = try ConfigurationParser.parse(jsonObject: configuration.jsonObject)
    }

    private func write(_ configuration: DivotConfiguration) throws {
        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        let data = try encode(configuration)
        try writeData(data, configURL)
    }

    private func encode(_ configuration: DivotConfiguration) throws -> Data {
        try JSONSerialization.data(withJSONObject: configuration.jsonObject,
                                   options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Copy the current file to the backup path before it is overwritten. Throws
    /// when the original cannot be preserved, so a migration never destroys the
    /// only recoverable copy.
    private func backupOriginal() throws -> URL {
        try? fileManager.removeItem(at: backupURL)
        try fileManager.copyItem(at: configURL, to: backupURL)
        return backupURL
    }
}

// MARK: - Serialization

public extension DivotConfiguration {
    /// The canonical JSON object for this document, matching the website
    /// checker's shape. Deterministic key order comes from `.sortedKeys`.
    var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "version": version,
            "appearance": appearance.jsonObject,
            "layout": layout.jsonObject,
            "left": left.map(\.rawValue),
            "right": right.map(\.rawValue)
        ]
        let text = text.jsonObject
        if !text.isEmpty { object["text"] = text }
        let widgets = widgets.jsonObject
        if !widgets.isEmpty { object["widgets"] = widgets }
        let keepAwake = keepAwake.jsonObject
        if !keepAwake.isEmpty { object["keepAwake"] = keepAwake }
        let menuBar = menuBar.jsonObject
        if !menuBar.isEmpty { object["menuBar"] = menuBar }
        // Only the non-default opt-in is written, so a document that leaves the
        // icon off stays identical to the first-launch shape.
        if showAppIcon { object["showAppIcon"] = true }
        // The dots default on, so only a hidden marker is written; both on (the
        // default) leaves the first-launch document unchanged (#0026).
        if !showOccupiedDot { object["showOccupiedDot"] = false }
        if !showEmptyDot { object["showEmptyDot"] = false }
        // The shadow is off by default, so only the opt-in is written; the
        // first-launch document stays identical (#0025).
        if bottomShadow { object["bottomShadow"] = true }
        return object
    }
}

private extension MenuBarConfiguration {
    /// Only the non-default opt-in is written, so a document that leaves the
    /// Accessibility heuristic off stays identical to the first-launch shape.
    var jsonObject: [String: Any] {
        trustAccessibilityProbe ? ["trustAccessibilityProbe": true] : [:]
    }
}

private extension KeepAwakeConfiguration {
    /// Only non-default values are written, so the file stays as small as the
    /// defaults allow and a plain (unremembered) session never writes here.
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        if remember { object["remember"] = true }
        if isActive { object["isActive"] = true }
        return object
    }
}

private extension AppearanceConfiguration {
    var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "family": family.rawValue,
            "mode": mode.rawValue,
            "accent": accent,
            "material": material.rawValue
        ]
        if !palette.isEmpty {
            object["palette"] = Dictionary(uniqueKeysWithValues: palette.map { ($0.key.rawValue, $0.value) })
        }
        return object
    }
}

private extension LayoutConfiguration {
    var jsonObject: [String: Any] {
        ["height": height, "padding": padding, "notchGap": notchGap]
    }
}

private extension TextConfiguration {
    /// Only non-default values are written, so the first-launch document stays
    /// as small as the defaults allow.
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        let defaults = TextConfiguration.default
        if size != defaults.size { object["size"] = size }
        if font != defaults.font { object["font"] = font }
        return object
    }
}

private extension WidgetOptions {
    /// Only namespaces with non-default options are written, keeping a saved
    /// file as small as the defaults allow while staying valid.
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        let workspaces = workspaces.jsonObject
        if !workspaces.isEmpty { object[BarItemID.workspaces.rawValue] = workspaces }
        let frontApp = frontApp.jsonObject
        if !frontApp.isEmpty { object[BarItemID.frontApp.rawValue] = frontApp }
        let clock = clock.jsonObject
        if !clock.isEmpty { object[BarItemID.clock.rawValue] = clock }
        return object
    }
}

private extension WorkspacesConfiguration {
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        let defaults = WorkspacesConfiguration.default
        if adapter != defaults.adapter { object["adapter"] = adapter.rawValue }
        if showEmpty != defaults.showEmpty { object["showEmpty"] = showEmpty }
        if showAppIcons != defaults.showAppIcons { object["showAppIcons"] = showAppIcons }
        if showDetails != defaults.showDetails { object["showDetails"] = showDetails }
        if let cap = maxAppIconsPerWorkspace { object["maxAppIconsPerWorkspace"] = cap }
        return object
    }
}

private extension FrontAppConfiguration {
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        let defaults = FrontAppConfiguration.default
        if showIcon != defaults.showIcon { object["showIcon"] = showIcon }
        if showName != defaults.showName { object["showName"] = showName }
        return object
    }
}

private extension ClockConfiguration {
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        let defaults = ClockConfiguration.default
        if weekday != defaults.weekday { object["weekday"] = weekday }
        if date != defaults.date { object["date"] = date }
        if seconds != defaults.seconds { object["seconds"] = seconds }
        return object
    }
}
