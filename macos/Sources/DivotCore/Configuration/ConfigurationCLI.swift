import Foundation

// MARK: - Outcome

/// The result of one `divot config` invocation: text to print and the process
/// exit code. Keeping the command pure (no printing, no `exit`) makes the
/// round-trip and rejection tests deterministic.
public struct ConfigurationCommandOutcome: Equatable, Sendable {
    public let output: String
    public let exitCode: Int32

    public init(output: String, exitCode: Int32 = 0) {
        self.output = output
        self.exitCode = exitCode
    }
}

// MARK: - Command

/// The `divot config` subcommand.
///
/// Reads and writes go through `ConfigurationStore`, so validation is the same
/// `ConfigurationParser` the loader uses, writes are Foundation-atomic, and the
/// schema comes from `ConfigurationSchema` (the same model the Settings window
/// edits). Exit codes are stable: `0` success, `1` invalid value or file, `2`
/// usage error.
public struct ConfigurationCommand {
    public let store: ConfigurationStore
    private let fileManager: FileManager

    public init(store: ConfigurationStore = ConfigurationStore(),
                fileManager: FileManager = .default) {
        self.store = store
        self.fileManager = fileManager
    }

    public static let helpText = """
    divot config — inspect and edit the versioned configuration

    usage:
      divot config schema [--json]
      divot config show [--json]
      divot config get <key> [--json]
      divot config set <key> <value> [--dry-run] [--diff] [--json]
      divot config unset <key> [--json]
      divot config validate [--file <path>] [--json]

    keys are dotted JSON paths (e.g. widgets.time.seconds); run
    `divot config schema` for every key, type, range, and default.
    exit codes: 0 ok · 1 invalid value or file · 2 usage error
    """

    public func run(_ arguments: [String]) -> ConfigurationCommandOutcome {
        guard let subcommand = arguments.first else {
            return usage("missing subcommand")
        }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "schema": return runSchema(rest)
        case "show": return runShow(rest)
        case "get": return runGet(rest)
        case "set": return runSet(rest)
        case "unset": return runUnset(rest)
        case "validate": return runValidate(rest)
        case "help", "--help", "-h": return ConfigurationCommandOutcome(output: Self.helpText)
        default: return usage("unknown subcommand '\(subcommand)'")
        }
    }

    // MARK: schema

    private func runSchema(_ arguments: [String]) -> ConfigurationCommandOutcome {
        if arguments.contains("--json") {
            return json(ConfigurationSchema.jsonObject())
        }
        let lines = ConfigurationSchema.entries.map { entry -> String in
            var line = "\(entry.key)  [\(entry.type.rawValue)]"
            if let range = entry.rangeDescription { line += " \(range)" }
            if !entry.values.isEmpty { line += " (\(entry.values.joined(separator: " | ")))" }
            line += "  default: \(entry.defaultValue.displayString)"
            if !entry.writable { line += "  [read-only]" }
            line += "\n    \(entry.summary)"
            return line
        }
        return ConfigurationCommandOutcome(output: lines.joined(separator: "\n"))
    }

    // MARK: show

    private func runShow(_ arguments: [String]) -> ConfigurationCommandOutcome {
        if let error = loadForUse() { return failure(error) }
        let configuration = store.current
        if arguments.contains("--json") {
            return json(configuration.jsonObject)
        }
        let lines = ConfigurationSchema.entries.map { entry in
            "\(entry.key) = \(entry.read(configuration).displayString)"
        }
        return ConfigurationCommandOutcome(output: lines.joined(separator: "\n"))
    }

    // MARK: get

    private func runGet(_ arguments: [String]) -> ConfigurationCommandOutcome {
        let keys = positionals(arguments)
        guard keys.count == 1 else {
            return usage("usage: divot config get <key> [--json]")
        }
        let key = keys[0]
        guard let setting = ConfigurationSchema.entry(for: key) else { return failure(unknownSetting(key)) }
        if let error = loadForUse() { return failure(error) }
        let value = setting.read(store.current)
        if arguments.contains("--json") {
            return json(["key": key, "type": setting.type.rawValue, "value": value.jsonObject])
        }
        return ConfigurationCommandOutcome(output: value.displayString)
    }

    // MARK: set

    private func runSet(_ arguments: [String]) -> ConfigurationCommandOutcome {
        let values = positionals(arguments)
        guard values.count == 2 else {
            return usage("usage: divot config set <key> <value> [--dry-run] [--diff] [--json]")
        }
        let key = values[0]
        let raw = values[1]
        let dryRun = arguments.contains("--dry-run")
        let showDiff = arguments.contains("--diff")
        let wantsJSON = arguments.contains("--json")

        guard let setting = ConfigurationSchema.entry(for: key) else { return failure(unknownSetting(key)) }
        guard setting.writable else { return failure(ConfigurationError(path: key, message: "read-only setting")) }

        let parsed: ConfigurationValue
        do {
            parsed = try ConfigurationSchema.parse(raw, as: setting)
        } catch let error as ConfigurationError {
            return failure(error)
        } catch {
            return failure(ConfigurationError(path: key, message: "\(error)"))
        }

        if let error = loadForUse() { return failure(error) }

        let before = store.current
        let beforeLines = prettyLines(try? store.data(for: before))
        var next = before
        do {
            try ConfigurationSchema.apply(parsed, to: setting, in: &next)
            if dryRun {
                _ = try store.data(for: next) // the loader's validation, without writing
            } else {
                try store.save(next)
            }
        } catch let error as ConfigurationError {
            return failure(error)
        } catch {
            return failure(ConfigurationError(path: key, message: "\(error)"))
        }

        let afterLines = prettyLines(try? store.data(for: next))
        let diff = showDiff ? lineDiff(before: beforeLines, after: afterLines) : nil

        if wantsJSON {
            var object: [String: Any] = [
                "key": key,
                "value": parsed.jsonObject,
                "dryRun": dryRun,
                "path": store.configURL.path
            ]
            if let diff { object["diff"] = diff }
            return json(object)
        }
        var lines: [String] = []
        if let diff {
            lines.append(diff)
            lines.append("")
        }
        lines.append("\(key) = \(parsed.displayString)")
        lines.append(dryRun ? "validated (dry run; not written)" : "wrote \(store.configURL.path)")
        return ConfigurationCommandOutcome(output: lines.joined(separator: "\n"))
    }

    // MARK: unset

    private func runUnset(_ arguments: [String]) -> ConfigurationCommandOutcome {
        let keys = positionals(arguments)
        guard keys.count == 1 else {
            return usage("usage: divot config unset <key> [--json]")
        }
        let key = keys[0]
        guard let setting = ConfigurationSchema.entry(for: key) else { return failure(unknownSetting(key)) }
        guard setting.writable else { return failure(ConfigurationError(path: key, message: "read-only setting")) }
        if let error = loadForUse() { return failure(error) }

        var next = store.current
        do {
            try ConfigurationSchema.apply(setting.defaultValue, to: setting, in: &next)
            try store.save(next)
        } catch let error as ConfigurationError {
            return failure(error)
        } catch {
            return failure(ConfigurationError(path: key, message: "\(error)"))
        }

        if arguments.contains("--json") {
            return json([
                "key": key,
                "default": setting.defaultValue.jsonObject,
                "path": store.configURL.path,
                "written": true
            ])
        }
        return ConfigurationCommandOutcome(
            output: "\(key) = \(setting.defaultValue.displayString)\nwrote \(store.configURL.path)")
    }

    // MARK: validate

    private func runValidate(_ arguments: [String]) -> ConfigurationCommandOutcome {
        var wantsJSON = false
        var explicitFile = false
        var path = store.configURL.path
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json":
                wantsJSON = true
            case "--file":
                index += 1
                guard index < arguments.count else { return usage("--file needs a path") }
                path = arguments[index]
                explicitFile = true
            default:
                if argument.hasPrefix("--file=") {
                    path = String(argument.dropFirst("--file=".count))
                    explicitFile = true
                } else {
                    return usage("unknown argument '\(argument)'")
                }
            }
            index += 1
        }

        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: url.path) else {
            // A missing default file is the valid first-launch state; a missing
            // file the caller named explicitly is an error.
            if !explicitFile {
                return wantsJSON
                    ? json(["valid": true, "path": path, "source": "defaults"])
                    : ConfigurationCommandOutcome(output: "valid (defaults; no file at \(path))")
            }
            let error = ConfigurationError(path: "root", message: "no file at \(path)")
            return wantsJSON
                ? json(["valid": false, "path": path, "error": error.description], exitCode: 1)
                : failure(error)
        }
        do {
            let parsed = try ConfigurationParser.parse(Data(contentsOf: url))
            if wantsJSON {
                var object: [String: Any] = ["valid": true, "path": path]
                if let migrated = parsed.migratedFromVersion {
                    object["migratedFromVersion"] = migrated
                }
                return json(object)
            }
            let migration = parsed.migratedFromVersion
                .map { " (migrates version \($0) to \(DivotConfiguration.currentVersion))" } ?? ""
            return ConfigurationCommandOutcome(output: "valid\(migration): \(path)")
        } catch let error as ConfigurationError {
            return wantsJSON
                ? json(["valid": false, "path": path, "error": error.description], exitCode: 1)
                : failure(error)
        } catch {
            return failure(ConfigurationError(path: "root", message: "\(error)"))
        }
    }

    // MARK: Shared

    /// Load the store for a read or edit. A present-but-invalid file is
    /// reported rather than silently overwritten with defaults.
    private func loadForUse() -> ConfigurationError? {
        switch store.load() {
        case .defaults, .loaded, .migrated:
            return nil
        case .invalid(let error):
            return error
        }
    }

    private func positionals(_ arguments: [String]) -> [String] {
        arguments.filter { !$0.hasPrefix("--") }
    }

    private func usage(_ message: String) -> ConfigurationCommandOutcome {
        ConfigurationCommandOutcome(output: "error: \(message)\n\n\(Self.helpText)", exitCode: 2)
    }

    private func failure(_ error: ConfigurationError) -> ConfigurationCommandOutcome {
        ConfigurationCommandOutcome(output: "error: \(error.description)", exitCode: 1)
    }

    private func unknownSetting(_ key: String) -> ConfigurationError {
        ConfigurationError(path: key, message: "unknown setting; run `divot config schema` for the full list")
    }

    private func json(_ object: Any, exitCode: Int32 = 0) -> ConfigurationCommandOutcome {
        guard let data = try? JSONSerialization.data(withJSONObject: object,
                                                     options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let string = String(data: data, encoding: .utf8) else {
            return ConfigurationCommandOutcome(output: "error: could not encode JSON", exitCode: 1)
        }
        return ConfigurationCommandOutcome(output: string, exitCode: exitCode)
    }

    private func prettyLines(_ data: Data?) -> [String] {
        guard let data, let string = String(data: data, encoding: .utf8) else { return [] }
        return string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// A minimal unified diff over the sorted-key JSON: the common prefix and
    /// suffix are elided and the changed middle is marked. It is stable and
    /// good enough to show a one-setting edit without pulling in a diff engine.
    private func lineDiff(before: [String], after: [String]) -> String {
        var prefix = 0
        while prefix < before.count, prefix < after.count, before[prefix] == after[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < before.count - prefix, suffix < after.count - prefix,
              before[before.count - 1 - suffix] == after[after.count - 1 - suffix] {
            suffix += 1
        }
        var lines = ["--- current", "+++ next"]
        for line in before[prefix..<(before.count - suffix)] { lines.append("- \(line)") }
        for line in after[prefix..<(after.count - suffix)] { lines.append("+ \(line)") }
        return lines.joined(separator: "\n")
    }
}
