import Foundation

// MARK: - Value

/// A typed configuration value read from or written to `DivotConfiguration`.
///
/// The schema and the `divot config` CLI use this type so a setting's declared
/// type, its default, and the value the model actually holds cannot drift
/// apart: every entry reads and writes the model through a key path.
public enum ConfigurationValue: Equatable, Sendable {
    /// No value: an optional setting that is unset (removed from the document).
    case null
    case boolean(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case hex(String)
    case items([BarItemID])
    case stringArray([String])

    /// The JSON representation (NSNull for `.null`), for `schema --json`,
    /// `show --json`, and `get --json`.
    public var jsonObject: Any {
        switch self {
        case .null: return NSNull()
        case .boolean(let value): return value
        case .integer(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .hex(let value): return value
        case .items(let value): return value.map(\.rawValue)
        case .stringArray(let value): return value
        }
    }

    /// A one-line human representation used by the plain-text CLI output.
    public var displayString: String {
        switch self {
        case .null: return "(unset)"
        case .boolean(let value): return value ? "true" : "false"
        case .integer(let value): return String(value)
        case .number(let value):
            return value == value.rounded() && value.magnitude < 1e15
                ? String(Int(value)) : String(value)
        case .string(let value), .hex(let value): return value
        case .items(let value): return value.map(\.rawValue).joined(separator: ",")
        case .stringArray(let value): return value.joined(separator: ",")
        }
    }
}

// MARK: - Setting type

/// The value class of a setting, mirroring the JSON contract.
public enum ConfigurationSettingType: String, Sendable {
    case boolean
    case integer
    case number
    case string
    case hex
    case options
    case items
    case stringArray = "string-array"
}

// MARK: - Setting

/// One discoverable configuration setting.
///
/// The `read`/`write` closures are the single source of truth: they touch the
/// exact `DivotConfiguration` fields the loader, the store, and the Settings
/// window use, so `divot config schema --json` and the get/set handlers can
/// never describe a model that does not exist. `ConfigurationSchemaTests`
/// fails if the model serializes a field with no matching entry here.
public struct ConfigurationSetting: @unchecked Sendable {
    public typealias Reader = (DivotConfiguration) -> ConfigurationValue
    public typealias Writer = (inout DivotConfiguration, ConfigurationValue) throws -> Void

    /// Dotted JSON key, e.g. `widgets.clock.seconds`.
    public let key: String
    public let type: ConfigurationSettingType
    public let defaultValue: ConfigurationValue
    /// Numeric bounds for `.number`/`.integer`, matching the parser's range.
    public let range: ClosedRange<Double>?
    /// Allowed spellings for `.options`/`.items`.
    public let values: [String]
    /// One-line human description.
    public let summary: String
    /// `false` for `version`, which the loader owns and the CLI must not rewrite.
    public let writable: Bool
    public let read: Reader
    public let write: Writer?

    init(key: String,
         type: ConfigurationSettingType,
         defaultValue: ConfigurationValue,
         range: ClosedRange<Double>? = nil,
         values: [String] = [],
         summary: String,
         writable: Bool = true,
         read: @escaping Reader,
         write: Writer? = nil) {
        self.key = key
        self.type = type
        self.defaultValue = defaultValue
        self.range = range
        self.values = values
        self.summary = summary
        self.writable = writable
        self.read = read
        self.write = write
    }

    /// `"24–40"` for a bounded number, else `nil`.
    public var rangeDescription: String? {
        guard let range else { return nil }
        return "\(describe(range.lowerBound))–\(describe(range.upperBound))"
    }

    /// The schema entry as JSON, used by `divot config schema --json`.
    public var jsonObject: [String: Any] {
        var object: [String: Any] = [
            "key": key,
            "type": type.rawValue,
            "default": defaultValue.jsonObject,
            "description": summary,
            "writable": writable
        ]
        if let range {
            object["range"] = ["min": range.lowerBound, "max": range.upperBound]
        }
        if !values.isEmpty { object["values"] = values }
        return object
    }

    private func describe(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

// MARK: - Schema

/// The generated schema for the versioned configuration contract.
///
/// This is the single source for the `divot config schema` output, for the
/// get/set/unset lookup, and for the range/enum metadata the CLI quotes back on
/// an invalid edit. Every entry is wired to a `DivotConfiguration` key path,
/// and the completeness test compares the entry keys against the document the
/// model serializes, so a new setting cannot be added without a schema entry.
public enum ConfigurationSchema {
    // MARK: Public API

    /// Every setting, in document order.
    public static let entries: [ConfigurationSetting] = [
        versionSetting,

        // Appearance
        options("appearance.family", "Theme family; `native` follows macOS.",
                default: .native, \.appearance.family),
        options("appearance.mode", "Light, dark, or follow the system appearance.",
                default: .system, \.appearance.mode),
        hexColor("appearance.accent", "Root accent color as six-digit hex; a family signature color applies while this stays at its default.",
                 default: AppearanceConfiguration.defaultAccent, \.appearance.accent),
        options("appearance.material", "Bar fill material token.",
                default: .native, \.appearance.material),
        palette(.foreground, "Palette override for the foreground text color."),
        palette(.background, "Palette override for the bar background color."),
        palette(.accent, "Palette override for the accent color; wins over appearance.accent."),
        palette(.selected, "Palette override for the selected/occupied workspace color."),
        palette(.occupied, "Palette override for the occupied workspace marker."),
        palette(.error, "Palette override for error and warning text."),

        // Layout
        number("layout.height", "Panel height in points.",
               default: Double(BarMetrics.default.height), range: LayoutConfiguration.heightRange, \.layout.height),
        number("layout.padding", "Padding inside each panel in points.",
               default: Double(BarMetrics.default.rowInset), range: LayoutConfiguration.paddingRange, \.layout.padding),
        number("layout.rightItemSpacing", "Gap between adjacent items in the right group.",
               default: LayoutConfiguration.defaultRightItemSpacing, range: LayoutConfiguration.itemSpacingRange, \.layout.rightItemSpacing),
        number("layout.leftItemSpacing", "Gap between adjacent items in the left group.",
               default: LayoutConfiguration.defaultLeftItemSpacing, range: LayoutConfiguration.itemSpacingRange, \.layout.leftItemSpacing),

        // Text
        number("text.size", "Bar text size in points; icon and chip sizes follow it.",
               default: Double(BarMetrics.defaultTextSize), range: TextConfiguration.sizeRange, \.text.size),
        text("text.font", "Installed font family name, or an empty string for the system font.",
             default: "", \.text.font),

        // Item placement
        items("left", "Ordered items on the left, comma-separated.",
              default: DivotConfiguration.defaultLeft, \.left),
        items("right", "Ordered items on the right, comma-separated.",
              default: DivotConfiguration.defaultRight, \.right),

        // Widget options
        options("widgets.workspaces.adapter", "Window-manager adapter override.",
                default: .aerospace, \.widgets.workspaces.adapter),
        boolean("widgets.workspaces.showEmpty", "Show workspaces with no windows.",
                default: true, \.widgets.workspaces.showEmpty),
        boolean("widgets.workspaces.showAppIcons", "Show per-workspace app icons.",
                default: false, \.widgets.workspaces.showAppIcons),
        boolean("widgets.workspaces.showDetails", "Show workspace app count and active program.",
                default: true, \.widgets.workspaces.showDetails),
        optionalInteger("widgets.workspaces.maxAppIconsPerWorkspace",
                        "Cap app icons per workspace; unset shows all.",
                        range: WorkspacesConfiguration.maxAppIconsRange,
                        \.widgets.workspaces.maxAppIconsPerWorkspace),
        boolean("widgets.front-app.showIcon", "Show the front application icon.",
                default: true, \.widgets.frontApp.showIcon),
        boolean("widgets.front-app.showName", "Show the front application name.",
                default: true, \.widgets.frontApp.showName),
        boolean("widgets.battery.showPercentage", "Show the battery percentage next to the icon.",
                default: true, \.widgets.battery.showPercentage),
        boolean("widgets.date.weekday", "Include the day of week in the date.",
                default: true, \.widgets.date.weekday),
        boolean("widgets.date.year", "Include the year in the date.",
                default: false, \.widgets.date.year),
        boolean("widgets.date.dayFirst", "Show the day before the month.",
                default: false, \.widgets.date.dayFirst),
        text("widgets.date.separator", "Separator between date components.",
             default: " ", \.widgets.date.separator),
        optionalText("widgets.date.customPattern", "Custom date format pattern; invalid patterns fall back to the generated one.",
                     \.widgets.date.customPattern),
        boolean("widgets.time.seconds", "Show seconds in the time.",
                default: false, \.widgets.time.seconds),
        options("widgets.time.timeFormat", "Time format: 24-hour, AM/PM, or a custom pattern.",
                default: .ampm, \.widgets.time.timeFormat),
        optionalText("widgets.time.customPattern", "Custom time format pattern for timeFormat=custom.",
                     \.widgets.time.customPattern),
        timezoneArray("widgets.time.timezones",
                      "User's added world timezones (IANA identifiers). An absent key resolves to the three defaults (San Francisco, London and Singapore, minus the local zone); an explicitly empty list stays empty.",
                      \.widgets.time.timezones),
        boolean("widgets.network.showWifiName", "Show the connected Wi-Fi network name (asks for Location permission).",
                default: false, \.widgets.network.showWifiName),
        boolean("widgets.volume.showVolumePercent", "Show the volume percentage.",
                default: true, \.widgets.volume.showVolumePercent),
        boolean("widgets.volume.showVolumeMuted", "Show the muted indicator.",
                default: true, \.widgets.volume.showVolumeMuted),

        // Root preferences
        boolean("keepAwake.remember", "Persist the keep-awake state across launches.",
                default: false, \.keepAwake.remember),
        boolean("keepAwake.isActive", "Remembered keep-awake state; only written while remember is on.",
                default: false, \.keepAwake.isActive),
        boolean("menuBar.trustAccessibilityProbe", "Trust the Accessibility menu-bar observation on notched hardware.",
                default: false, \.menuBar.trustAccessibilityProbe),
        boolean("menuBar.moveBelowOnCursorReveal", "Follow an auto-hidden menu bar's reveal from the pointer at the top strip.",
                default: true, \.menuBar.moveBelowOnCursorReveal),
        boolean("menuBar.alwaysBelow", "Always sit below the native menu bar.",
                default: false, \.menuBar.alwaysBelow),
        boolean("showAppIcon", "Show the Divot mark before the workspaces.",
                default: false, \.showAppIcon),
        boolean("showOccupiedDot", "Draw the filled occupied-workspace marker.",
                default: true, \.showOccupiedDot),
        boolean("showEmptyDot", "Draw the hollow empty-workspace marker.",
                default: true, \.showEmptyDot),
        boolean("bottomShadow", "Draw a drop shadow along the bar's bottom edge.",
                default: false, \.bottomShadow),
        boolean("chipStyle", "Draw each item in its own rounded chip.",
                default: false, \.chipStyle),
        integer("chipOpacity", "Chip background opacity; 100 matches the bar background.",
                default: 0, range: DivotConfiguration.chipOpacityRange, \.chipOpacity),
        number("appIconSize", "Point size of the app icons drawn on the left.",
               default: Double(BarMetrics.default.iconSize), range: DivotConfiguration.appIconSizeRange, \.appIconSize)
    ]

    private static let byKey: [String: ConfigurationSetting] =
        Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0) })

    /// The setting with `key`, or `nil` when the key is unknown.
    public static func entry(for key: String) -> ConfigurationSetting? { byKey[key] }

    /// Read the current value of `key` from a document.
    public static func value(for key: String, in configuration: DivotConfiguration) -> ConfigurationValue? {
        entry(for: key)?.read(configuration)
    }

    /// Write `value` into `configuration` at `key`, or throw a field error.
    public static func apply(_ value: ConfigurationValue,
                             to key: String,
                             in configuration: inout DivotConfiguration) throws {
        guard let setting = entry(for: key) else {
            throw ConfigurationError(path: key, message: "unknown setting; run `divot config schema` for the full list")
        }
        try apply(value, to: setting, in: &configuration)
    }

    /// Write `value` using an already-resolved setting (avoids a second lookup).
    public static func apply(_ value: ConfigurationValue,
                             to setting: ConfigurationSetting,
                             in configuration: inout DivotConfiguration) throws {
        guard let write = setting.write else {
            throw ConfigurationError(path: setting.key, message: "read-only setting")
        }
        try write(&configuration, value)
    }

    /// Parse a command-line value against the setting's declared type. Range
    /// and cross-field checks still run through the parser before any write.
    public static func parse(_ raw: String, as setting: ConfigurationSetting) throws -> ConfigurationValue {
        switch setting.type {
        case .boolean:
            switch raw.lowercased() {
            case "true", "yes", "1": return .boolean(true)
            case "false", "no", "0": return .boolean(false)
            default:
                throw ConfigurationError(path: setting.key, message: "expected true | false")
            }
        case .integer:
            guard let value = Int(raw) else {
                throw ConfigurationError(path: setting.key, message: "expected integer")
            }
            return .integer(value)
        case .number:
            guard let value = Double(raw), value.isFinite else {
                throw ConfigurationError(path: setting.key, message: "expected number")
            }
            return .number(value)
        case .string:
            return .string(raw)
        case .hex:
            guard isHex(raw) else {
                throw ConfigurationError(path: setting.key, message: "expected six-digit hex")
            }
            return .hex(raw)
        case .options:
            guard setting.values.contains(raw) else {
                throw ConfigurationError(path: setting.key,
                                         message: "expected \(setting.values.joined(separator: " | "))")
            }
            return .string(raw)
        case .items:
            let parts = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            var items: [BarItemID] = []
            for part in parts {
                guard let id = BarItemID(rawValue: part), id != .clock else {
                    throw ConfigurationError(path: setting.key,
                                             message: "expected \(setting.values.joined(separator: " | "))")
                }
                items.append(id)
            }
            guard Set(items).count == items.count else {
                throw ConfigurationError(path: setting.key, message: "expected unique items")
            }
            return .items(items)
        case .stringArray:
            let parts = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return .stringArray(Array(parts))
        }
    }

    /// The schema as a JSON array, used by `divot config schema --json`.
    public static func jsonObject() -> [[String: Any]] {
        entries.map(\.jsonObject)
    }

    /// The placeable item spellings, used for `left`/`right` validation.
    public static var placeableItemValues: [String] { BarItemID.placeableItems.map(\.rawValue) }

    // MARK: Builders

    private static var versionSetting: ConfigurationSetting {
        ConfigurationSetting(
            key: "version",
            type: .integer,
            defaultValue: .integer(DivotConfiguration.currentVersion),
            summary: "Configuration contract version; always \(DivotConfiguration.currentVersion).",
            writable: false,
            read: { .integer($0.version) })
    }

    private static func boolean(_ key: String, _ summary: String,
                                default value: Bool,
                                _ keyPath: WritableKeyPath<DivotConfiguration, Bool>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .boolean, defaultValue: .boolean(value), summary: summary,
            read: { .boolean($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                guard case .boolean(let flag) = newValue else {
                    throw ConfigurationError(path: key, message: "expected boolean")
                }
                configuration[keyPath: keyPath] = flag
            })
    }

    private static func integer(_ key: String, _ summary: String,
                                default value: Int, range bounds: ClosedRange<Int>,
                                _ keyPath: WritableKeyPath<DivotConfiguration, Int>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .integer, defaultValue: .integer(value),
            range: Double(bounds.lowerBound)...Double(bounds.upperBound), summary: summary,
            read: { .integer($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                guard case .integer(let number) = newValue, bounds.contains(number) else {
                    throw ConfigurationError(path: key,
                                             message: "expected \(bounds.lowerBound)–\(bounds.upperBound)")
                }
                configuration[keyPath: keyPath] = number
            })
    }

    private static func number(_ key: String, _ summary: String,
                               default value: Double, range bounds: ClosedRange<Double>,
                               _ keyPath: WritableKeyPath<DivotConfiguration, Double>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .number, defaultValue: .number(value), range: bounds, summary: summary,
            read: { .number($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                let result = try numeric(newValue, bounds: bounds, path: key)
                configuration[keyPath: keyPath] = result
            })
    }

    private static func text(_ key: String, _ summary: String,
                             default value: String,
                             _ keyPath: WritableKeyPath<DivotConfiguration, String>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .string, defaultValue: .string(value), summary: summary,
            read: { .string($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                guard case .string(let string) = newValue else {
                    throw ConfigurationError(path: key, message: "expected string")
                }
                configuration[keyPath: keyPath] = string
            })
    }

    private static func hexColor(_ key: String, _ summary: String,
                                 default value: String,
                                 _ keyPath: WritableKeyPath<DivotConfiguration, String>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .hex, defaultValue: .hex(value), summary: summary,
            read: { .hex($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                guard case .hex(let string) = newValue, isHex(string) else {
                    throw ConfigurationError(path: key, message: "expected six-digit hex")
                }
                configuration[keyPath: keyPath] = string
            })
    }

    private static func options<T: RawRepresentable & CaseIterable & Sendable>(
        _ key: String, _ summary: String,
        default value: T,
        _ keyPath: WritableKeyPath<DivotConfiguration, T>) -> ConfigurationSetting
    where T.RawValue == String, T.AllCases: Collection {
        let spellings = T.allCases.map(\.rawValue)
        return ConfigurationSetting(
            key: key, type: .options, defaultValue: .string(value.rawValue), values: spellings,
            summary: summary,
            read: { .string($0[keyPath: keyPath].rawValue) },
            write: { configuration, newValue in
                guard case .string(let raw) = newValue, let typed = T(rawValue: raw) else {
                    throw ConfigurationError(path: key,
                                             message: "expected \(spellings.joined(separator: " | "))")
                }
                configuration[keyPath: keyPath] = typed
            })
    }

    private static func items(_ key: String, _ summary: String,
                              default value: [BarItemID],
                              _ keyPath: WritableKeyPath<DivotConfiguration, [BarItemID]>) -> ConfigurationSetting {
        let spellings = placeableItemValues
        return ConfigurationSetting(
            key: key, type: .items, defaultValue: .items(value), values: spellings,
            summary: summary,
            read: { .items($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                guard case .items(let ids) = newValue else {
                    throw ConfigurationError(path: key,
                                             message: "expected \(spellings.joined(separator: " | "))")
                }
                configuration[keyPath: keyPath] = ids
            })
    }

    private static func optionalInteger(_ key: String, _ summary: String,
                                        range bounds: ClosedRange<Int>,
                                        _ keyPath: WritableKeyPath<DivotConfiguration, Int?>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .integer, defaultValue: .null,
            range: Double(bounds.lowerBound)...Double(bounds.upperBound), summary: summary,
            read: { configuration in configuration[keyPath: keyPath].map { .integer($0) } ?? .null },
            write: { configuration, newValue in
                switch newValue {
                case .null:
                    configuration[keyPath: keyPath] = nil
                case .integer(let number) where bounds.contains(number):
                    configuration[keyPath: keyPath] = number
                default:
                    throw ConfigurationError(path: key,
                                             message: "expected \(bounds.lowerBound)–\(bounds.upperBound) or unset")
                }
            })
    }

    private static func optionalText(_ key: String, _ summary: String,
                                     _ keyPath: WritableKeyPath<DivotConfiguration, String?>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .string, defaultValue: .null, summary: summary,
            read: { configuration in configuration[keyPath: keyPath].map { .string($0) } ?? .null },
            write: { configuration, newValue in
                switch newValue {
                case .null:
                    configuration[keyPath: keyPath] = nil
                case .string(let string):
                    configuration[keyPath: keyPath] = string
                default:
                    throw ConfigurationError(path: key, message: "expected string or unset")
                }
            })
    }

    private static func stringArray(_ key: String, _ summary: String,
                                   default value: [String],
                                   _ keyPath: WritableKeyPath<DivotConfiguration, [String]>) -> ConfigurationSetting {
        ConfigurationSetting(
            key: key, type: .stringArray, defaultValue: .stringArray(value), summary: summary,
            read: { .stringArray($0[keyPath: keyPath]) },
            write: { configuration, newValue in
                guard case .stringArray(let array) = newValue else {
                    throw ConfigurationError(path: key, message: "expected string array")
                }
                configuration[keyPath: keyPath] = array
            })
    }

    private static func timezoneArray(_ key: String, _ summary: String,
                                      _ keyPath: WritableKeyPath<DivotConfiguration, [String]?>) -> ConfigurationSetting {
        let knownTimezones = Set(TimeZone.knownTimeZoneIdentifiers)
        return ConfigurationSetting(
            key: key, type: .stringArray, defaultValue: .null, summary: summary,
            read: { configuration in configuration[keyPath: keyPath].map { .stringArray($0) } ?? .null },
            write: { configuration, newValue in
                switch newValue {
                case .null:
                    configuration[keyPath: keyPath] = nil
                case .stringArray(let array):
                    for timezone in array {
                        if !knownTimezones.contains(timezone) {
                            throw ConfigurationError(path: key, message: "unknown timezone: \(timezone)")
                        }
                    }
                    configuration[keyPath: keyPath] = array
                default:
                    throw ConfigurationError(path: key, message: "expected string array or unset")
                }
            })
    }

    private static func palette(_ token: AppearanceConfiguration.PaletteToken,
                                _ summary: String) -> ConfigurationSetting {
        let key = "appearance.palette.\(token.rawValue)"
        return ConfigurationSetting(
            key: key, type: .hex, defaultValue: .null, summary: summary,
            read: { configuration in
                configuration.appearance.palette[token].map { .hex($0) } ?? .null
            },
            write: { configuration, newValue in
                switch newValue {
                case .null:
                    configuration.appearance.palette[token] = nil
                case .hex(let string) where isHex(string):
                    configuration.appearance.palette[token] = string
                default:
                    throw ConfigurationError(path: key, message: "expected six-digit hex or unset")
                }
            })
    }

    // MARK: Field helpers

    private static func numeric(_ value: ConfigurationValue,
                                bounds: ClosedRange<Double>,
                                path: String) throws -> Double {
        let result: Double
        switch value {
        case .number(let number): result = number
        case .integer(let number): result = Double(number)
        default:
            throw ConfigurationError(path: path, message: "expected \(rangeText(bounds))")
        }
        guard result.isFinite, bounds.contains(result) else {
            throw ConfigurationError(path: path, message: "expected \(rangeText(bounds))")
        }
        return result
    }

    private static func rangeText(_ bounds: ClosedRange<Double>) -> String {
        "\(numberText(bounds.lowerBound))–\(numberText(bounds.upperBound))"
    }

    private static func numberText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func isHex(_ value: String) -> Bool {
        value.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
    }
}
