import Foundation

// MARK: - Argument parsing

/// A parsed command line for the focused `items` and `theme` helpers: bare
/// positionals plus the boolean flags and the `--flag value` / `--flag=value`
/// options each command accepts.
///
/// It is deliberately small: these helpers take a couple of options, and the
/// shared plumbing keeps the two commands consistent.
struct HelperArguments {
    var positionals: [String] = []
    var flags: Set<String> = []
    var options: [String: String] = [:]

    /// Parse `arguments`, treating each name in `valueFlags` as an option that
    /// consumes the next token. Every other `--name` is a boolean flag.
    static func parse(_ arguments: [String], valueFlags: Set<String>) throws -> HelperArguments {
        var result = HelperArguments()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--" {
                result.positionals.append(contentsOf: arguments[(index + 1)...])
                break
            }
            guard argument.hasPrefix("--") else {
                result.positionals.append(argument)
                index += 1
                continue
            }
            let body = String(argument.dropFirst(2))
            if let equals = body.firstIndex(of: "=") {
                let name = String(body[..<equals])
                result.options[name] = String(body[body.index(after: equals)...])
            } else if valueFlags.contains(body) {
                index += 1
                guard index < arguments.count else { throw HelperError("--\(body) needs a value") }
                result.options[body] = arguments[index]
            } else {
                result.flags.insert(body)
            }
            index += 1
        }
        return result
    }

    /// The value of `--side`, or `fallback` when it is absent.
    func side(default fallback: BarSide) throws -> BarSide {
        guard let raw = options["side"] else { return fallback }
        guard let side = BarSide(rawValue: raw) else { throw HelperError("expected --side left | right") }
        return side
    }

    /// The value of `--at`, or `nil` when it is absent. A negative or non-numeric
    /// index is refused rather than silently clamped.
    func index() throws -> Int? {
        guard let raw = options["at"] else { return nil }
        guard let value = Int(raw), value >= 0 else { throw HelperError("expected --at <non-negative index>") }
        return value
    }
}

/// A usage-level problem (`exit 2`): an unknown argument or a malformed option.
struct HelperError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

// MARK: - Shared support

/// The read/write plumbing `ItemsCommand` and `ThemeCommand` share. Both go
/// through `ConfigurationStore`, so a value the helper accepts loads natively
/// and an invalid edit leaves the last good file in place.
enum ConfigurationHelperSupport {
    /// Load the store for a read or edit. A present-but-invalid file is
    /// reported rather than silently overwritten with defaults.
    static func loadForUse(_ store: ConfigurationStore) -> ConfigurationError? {
        switch store.load() {
        case .defaults, .loaded, .migrated: return nil
        case .invalid(let error): return error
        }
    }

    static func failure(_ error: ConfigurationError) -> CLIOutcome {
        CLIOutcome(output: "error: \(error.description)", exitCode: 1)
    }

    static func usage(_ message: String, help: String) -> CLIOutcome {
        CLIOutcome(output: "error: \(message)\n\n\(help)", exitCode: 2)
    }

    static func json(_ object: Any, exitCode: Int32 = 0) -> CLIOutcome {
        guard let data = try? JSONSerialization.data(withJSONObject: object,
                                                     options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let string = String(data: data, encoding: .utf8) else {
            return CLIOutcome(output: "error: could not encode JSON", exitCode: 1)
        }
        return CLIOutcome(output: string, exitCode: exitCode)
    }

    /// One side's items, or `(none)` for an empty group.
    static func list(_ items: [BarItemID]) -> String {
        items.isEmpty ? "(none)" : items.map(\.rawValue).joined(separator: ", ")
    }

    /// The placeable item spellings, for an actionable rejection.
    static var placeableList: String { ConfigurationSchema.placeableItemValues.joined(separator: " | ") }
}

// MARK: - Items

/// The `divot items` subcommand: the common ordering edits an agent asks for.
///
/// It edits the same `left` and `right` arrays `divot config` writes, through
/// the same validation, so an item the helper accepts loads natively and an
/// invalid edit leaves the last good file in place. Only the eight placeable
/// items are accepted; the legacy combined `clock` is refused like any other
/// unknown spelling.
public struct ItemsCommand {
    public let store: ConfigurationStore

    public init(store: ConfigurationStore = ConfigurationStore()) {
        self.store = store
    }

    public static let helpText = """
    divot items — list and reorder the bar's items

    usage:
      divot items list [--json]
      divot items add <item> [--side left|right] [--at <index>] [--json]
      divot items remove <item> [--json]
      divot items move <item> [--side left|right] [--at <index>] [--json]

    items: \(ConfigurationHelperSupport.placeableList)
    add appends to the right group unless --side says otherwise; --at inserts
    at a zero-based index (0 is the first slot). move keeps the item's current
    side unless --side is given. Removing an item also clears its per-item
    options, so the document stays valid. Exit codes: 0 ok · 1 invalid item or
    file · 2 usage error.
    """

    public func run(_ arguments: [String]) -> CLIOutcome {
        guard let subcommand = arguments.first else {
            return usage("missing subcommand")
        }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list": return runList(rest)
        case "add": return runAdd(rest)
        case "remove": return runRemove(rest)
        case "move": return runMove(rest)
        case "help", "--help", "-h": return CLIOutcome(output: Self.helpText)
        default: return usage("unknown subcommand '\(subcommand)'")
        }
    }

    // MARK: list

    private func runList(_ arguments: [String]) -> CLIOutcome {
        let parsed: HelperArguments
        do { parsed = try HelperArguments.parse(arguments, valueFlags: []) }
        catch let error as HelperError { return usage(error.description) }
        catch { return usage("\(error)") }
        guard parsed.positionals.isEmpty else {
            return usage("unexpected argument '\(parsed.positionals[0])'")
        }
        if let error = ConfigurationHelperSupport.loadForUse(store) { return failure(error) }
        let configuration = store.current
        if parsed.flags.contains("json") {
            return json(["left": configuration.left.map(\.rawValue),
                         "right": configuration.right.map(\.rawValue)])
        }
        return CLIOutcome(output: "left: \(ConfigurationHelperSupport.list(configuration.left))\n"
                                + "right: \(ConfigurationHelperSupport.list(configuration.right))")
    }

    // MARK: add

    private func runAdd(_ arguments: [String]) -> CLIOutcome {
        parse(arguments, keepingCurrentSide: false) { parsed, id, side, index in
            if store.current.isPlaced(id) {
                return failure(ConfigurationError(
                    path: "items",
                    message: "'\(id.rawValue)' is already placed; use `divot items move` to reposition it"))
            }
            var next = store.current
            next.move(id, to: side, at: index)
            return commit(next, action: "added \(id.rawValue) to \(side.rawValue)",
                          wantsJSON: parsed.flags.contains("json"))
        }
    }

    // MARK: remove

    private func runRemove(_ arguments: [String]) -> CLIOutcome {
        let parsed: HelperArguments
        do { parsed = try HelperArguments.parse(arguments, valueFlags: []) }
        catch let error as HelperError { return usage(error.description) }
        catch { return usage("\(error)") }
        guard parsed.positionals.count == 1 else {
            return usage("usage: divot items remove <item> [--json]")
        }
        guard let id = placeable(parsed.positionals[0]) else { return unknownItem(parsed.positionals[0]) }
        if let error = ConfigurationHelperSupport.loadForUse(store) { return failure(error) }
        guard store.current.isPlaced(id) else {
            return failure(ConfigurationError(path: "items", message: "'\(id.rawValue)' is not placed"))
        }
        var next = store.current
        next.remove(id)
        clearOptions(for: id, in: &next)
        return commit(next, action: "removed \(id.rawValue)", wantsJSON: parsed.flags.contains("json"))
    }

    // MARK: move

    private func runMove(_ arguments: [String]) -> CLIOutcome {
        parse(arguments, keepingCurrentSide: true) { parsed, id, side, index in
            guard store.current.isPlaced(id) else {
                return failure(ConfigurationError(
                    path: "items", message: "'\(id.rawValue)' is not placed; use `divot items add` first"))
            }
            var next = store.current
            next.move(id, to: side, at: index)
            return commit(next, action: "moved \(id.rawValue) to \(side.rawValue)",
                          wantsJSON: parsed.flags.contains("json"))
        }
    }

    // MARK: Shared

    /// Parse the `add`/`move` shape (`<item> [--side] [--at] [--json]`), resolve
    /// the item and the destination, then run `body`. The insertion index is
    /// checked against the destination group after the item is removed from its
    /// old side, so `--at` always means the final slot. `move` keeps the item's
    /// current side when `--side` is omitted; `add` defaults to the right group.
    private func parse(_ arguments: [String],
                       keepingCurrentSide: Bool,
                       _ body: (HelperArguments, BarItemID, BarSide, Int?) -> CLIOutcome) -> CLIOutcome {
        let parsed: HelperArguments
        do { parsed = try HelperArguments.parse(arguments, valueFlags: ["side", "at"]) }
        catch let error as HelperError { return usage(error.description) }
        catch { return usage("\(error)") }
        guard parsed.positionals.count == 1 else {
            return usage("usage: divot items <add|move> <item> [--side left|right] [--at <index>] [--json]")
        }
        guard let id = placeable(parsed.positionals[0]) else { return unknownItem(parsed.positionals[0]) }
        // Load before choosing the default side, so `move` keeps the side the
        // file actually assigns rather than the first-launch default.
        if let error = ConfigurationHelperSupport.loadForUse(store) { return failure(error) }
        let side: BarSide
        let index: Int?
        do {
            let fallback = keepingCurrentSide ? (store.current.side(of: id) ?? .right) : .right
            side = try parsed.side(default: fallback)
            index = try parsed.index()
        } catch let error as HelperError {
            return usage(error.description)
        } catch {
            return usage("\(error)")
        }
        if let index {
            let limit = insertionLimit(for: id, on: side)
            guard index <= limit else {
                return failure(ConfigurationError(path: side.rawValue, message: "expected --at 0–\(limit)"))
            }
        }
        return body(parsed, id, side, index)
    }

    /// The highest valid `--at` for putting `id` on `side`: the destination
    /// group's count, less the item itself when it already lives there.
    private func insertionLimit(for id: BarItemID, on side: BarSide) -> Int {
        var count = store.current.items(on: side).count
        if store.current.side(of: id) == side { count -= 1 }
        return count
    }

    private func placeable(_ raw: String) -> BarItemID? {
        guard let id = BarItemID(rawValue: raw), BarItemID.placeableItems.contains(id) else { return nil }
        return id
    }

    private func unknownItem(_ raw: String) -> CLIOutcome {
        failure(ConfigurationError(path: "items",
                                   message: "unknown item '\(raw)'; expected \(ConfigurationHelperSupport.placeableList)"))
    }

    /// Reset the per-item options so a document with an item removed stays
    /// valid: the parser rejects a `widgets` namespace for an unplaced item.
    private func clearOptions(for id: BarItemID, in configuration: inout DivotConfiguration) {
        switch id {
        case .workspaces: configuration.widgets.workspaces = .default
        case .frontApp: configuration.widgets.frontApp = .default
        case .battery: configuration.widgets.battery = .default
        case .date: configuration.widgets.date = .default
        case .time: configuration.widgets.time = .default
        case .network: configuration.widgets.network = .default
        case .volume: configuration.widgets.volume = .default
        case .clock, .appearance: break
        }
    }

    /// Validate and write `configuration`, then render the new groups.
    private func commit(_ configuration: DivotConfiguration, action: String, wantsJSON: Bool) -> CLIOutcome {
        do {
            try store.save(configuration)
        } catch let error as ConfigurationError {
            return failure(error)
        } catch {
            return failure(ConfigurationError(path: "items", message: "\(error)"))
        }
        if wantsJSON {
            return json(["action": action,
                         "left": configuration.left.map(\.rawValue),
                         "right": configuration.right.map(\.rawValue),
                         "path": store.configURL.path])
        }
        return CLIOutcome(output: "\(action)\n"
                                + "left: \(ConfigurationHelperSupport.list(configuration.left))\n"
                                + "right: \(ConfigurationHelperSupport.list(configuration.right))")
    }

    private func failure(_ error: ConfigurationError) -> CLIOutcome {
        ConfigurationHelperSupport.failure(error)
    }

    private func usage(_ message: String) -> CLIOutcome {
        ConfigurationHelperSupport.usage(message, help: Self.helpText)
    }

    private func json(_ object: Any, exitCode: Int32 = 0) -> CLIOutcome {
        ConfigurationHelperSupport.json(object, exitCode: exitCode)
    }
}

// MARK: - Theme

/// The `divot theme` subcommand: read the active family/mode and set them.
///
/// It validates through `ConfigurationSchema`, so the accepted families and
/// modes, the error text, and the written document are exactly what
/// `divot config set appearance.family`/`appearance.mode` produce.
public struct ThemeCommand {
    public let store: ConfigurationStore

    public init(store: ConfigurationStore = ConfigurationStore()) {
        self.store = store
    }

    public static let helpText = """
    divot theme — read and set the theme family and mode

    usage:
      divot theme show [--json]
      divot theme set <family> [--mode system|dark|light] [--json]

    families: native | gruvbox | ayu | dracula | tokyo-night
    modes: system | dark | light (the mode is kept unless --mode is given)
    exit codes: 0 ok · 1 invalid family/mode or file · 2 usage error
    """

    public func run(_ arguments: [String]) -> CLIOutcome {
        guard let subcommand = arguments.first else {
            return usage("missing subcommand")
        }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "show": return runShow(rest)
        case "set": return runSet(rest)
        case "help", "--help", "-h": return CLIOutcome(output: Self.helpText)
        default: return usage("unknown subcommand '\(subcommand)'")
        }
    }

    // MARK: show

    private func runShow(_ arguments: [String]) -> CLIOutcome {
        let parsed: HelperArguments
        do { parsed = try HelperArguments.parse(arguments, valueFlags: []) }
        catch let error as HelperError { return usage(error.description) }
        catch { return usage("\(error)") }
        guard parsed.positionals.isEmpty else {
            return usage("unexpected argument '\(parsed.positionals[0])'")
        }
        if let error = ConfigurationHelperSupport.loadForUse(store) { return failure(error) }
        let appearance = store.current.appearance
        if parsed.flags.contains("json") {
            return json(["family": appearance.family.rawValue, "mode": appearance.mode.rawValue])
        }
        return CLIOutcome(output: "family: \(appearance.family.rawValue)\nmode: \(appearance.mode.rawValue)")
    }

    // MARK: set

    private func runSet(_ arguments: [String]) -> CLIOutcome {
        let parsed: HelperArguments
        do { parsed = try HelperArguments.parse(arguments, valueFlags: ["mode"]) }
        catch let error as HelperError { return usage(error.description) }
        catch { return usage("\(error)") }
        guard parsed.positionals.count == 1 else {
            return usage("usage: divot theme set <family> [--mode system|dark|light] [--json]")
        }
        guard let familySetting = ConfigurationSchema.entry(for: "appearance.family"),
              let modeSetting = ConfigurationSchema.entry(for: "appearance.mode") else {
            return failure(ConfigurationError(path: "appearance", message: "theme settings are not in the schema"))
        }

        let family: ConfigurationValue
        do { family = try ConfigurationSchema.parse(parsed.positionals[0], as: familySetting) }
        catch let error as ConfigurationError { return failure(error) }
        catch { return failure(ConfigurationError(path: familySetting.key, message: "\(error)")) }

        var mode: ConfigurationValue?
        if let raw = parsed.options["mode"] {
            do { mode = try ConfigurationSchema.parse(raw, as: modeSetting) }
            catch let error as ConfigurationError { return failure(error) }
            catch { return failure(ConfigurationError(path: modeSetting.key, message: "\(error)")) }
        }

        if let error = ConfigurationHelperSupport.loadForUse(store) { return failure(error) }
        var next = store.current
        do {
            try ConfigurationSchema.apply(family, to: familySetting, in: &next)
            if let mode { try ConfigurationSchema.apply(mode, to: modeSetting, in: &next) }
            try store.save(next)
        } catch let error as ConfigurationError {
            return failure(error)
        } catch {
            return failure(ConfigurationError(path: "appearance", message: "\(error)"))
        }

        let appearance = next.appearance
        if parsed.flags.contains("json") {
            return json(["family": appearance.family.rawValue,
                         "mode": appearance.mode.rawValue,
                         "path": store.configURL.path])
        }
        return CLIOutcome(output: "family: \(appearance.family.rawValue)\nmode: \(appearance.mode.rawValue)\n"
                                + "wrote \(store.configURL.path)")
    }

    private func failure(_ error: ConfigurationError) -> CLIOutcome {
        ConfigurationHelperSupport.failure(error)
    }

    private func usage(_ message: String) -> CLIOutcome {
        ConfigurationHelperSupport.usage(message, help: Self.helpText)
    }

    private func json(_ object: Any, exitCode: Int32 = 0) -> CLIOutcome {
        ConfigurationHelperSupport.json(object, exitCode: exitCode)
    }
}
