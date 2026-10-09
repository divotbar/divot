import CoreFoundation
import Foundation

/// The result of parsing a configuration document.
///
/// `migratedFromVersion` is non-nil when the document was a supported older
/// version that was migrated in memory. The store uses it to back up the
/// original file before it is rewritten as version 2.
public struct ParsedConfiguration: Equatable, Sendable {
    public let configuration: DivotConfiguration
    public let migratedFromVersion: Int?

    public init(configuration: DivotConfiguration, migratedFromVersion: Int? = nil) {
        self.configuration = configuration
        self.migratedFromVersion = migratedFromVersion
    }
}

/// Parses and validates the versioned configuration document.
///
/// It mirrors the website starter checker (`scripts/config-schema.ts`) field for
/// field, so a file the website validates also loads natively and vice versa.
/// Errors carry the dotted JSON path plus an actionable message.
public enum ConfigurationParser {
    /// Parse UTF-8 JSON data.
    public static func parse(_ data: Data) throws -> ParsedConfiguration {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw ConfigurationError(path: "root", message: "invalid JSON: \(error.localizedDescription)")
        }
        return try parse(jsonObject: object)
    }

    /// Parse an already-decoded JSON object (a `[String: Any]` tree).
    public static func parse(jsonObject: Any) throws -> ParsedConfiguration {
        guard (jsonObject as? [String: Any]) != nil else {
            throw ConfigurationError(path: "root", message: "expected object")
        }
        let version = try integer((jsonObject as? [String: Any])?["version"], path: "version")
        switch version {
        case DivotConfiguration.currentVersion:
            return ParsedConfiguration(configuration: try validateV2(jsonObject))
        case 1:
            return ParsedConfiguration(configuration: try migrateV1(jsonObject), migratedFromVersion: 1)
        default:
            throw ConfigurationError(path: "version",
                                     message: "unsupported version \(version); expected \(DivotConfiguration.currentVersion)")
        }
    }

    // MARK: - Version 2

    private static func validateV2(_ value: Any) throws -> DivotConfiguration {
        let root = try shape(value, required: ["version", "appearance", "layout", "left", "right"],
                             optional: ["widgets"], path: "root")
        let appearance = try appearance(root["appearance"], path: "appearance")
        let layout = try layout(root["layout"], path: "layout")
        let left = try itemGroup(root["left"], path: "left")
        let right = try itemGroup(root["right"], path: "right")
        try requireUniquePlacement(left: left, right: right)
        let widgets = try widgetOptions(root["widgets"], placed: Set(left + right))
        return DivotConfiguration(version: DivotConfiguration.currentVersion,
                                  appearance: appearance,
                                  layout: layout,
                                  left: left,
                                  right: right,
                                  widgets: widgets)
    }

    private static func appearance(_ value: Any?, path: String) throws -> AppearanceConfiguration {
        let object = try shape(value, required: ["family", "mode", "accent", "material"],
                               optional: ["palette"], path: path)
        let family = try enumValue(object["family"], AppearanceConfiguration.Family.self,
                                   path: "\(path).family")
        let mode = try enumValue(object["mode"], AppearanceConfiguration.Mode.self, path: "\(path).mode")
        let material = try enumValue(object["material"], AppearanceConfiguration.Material.self,
                                     path: "\(path).material")
        let accent = try hex(object["accent"], path: "\(path).accent")
        var palette: [AppearanceConfiguration.PaletteToken: String] = [:]
        if let rawPalette = object["palette"] {
            let tokens = AppearanceConfiguration.PaletteToken.allCases.map(\.rawValue)
            let paletteObject = try shape(rawPalette, required: [], optional: tokens,
                                          path: "\(path).palette")
            for (key, tokenValue) in paletteObject {
                guard let token = AppearanceConfiguration.PaletteToken(rawValue: key) else { continue }
                palette[token] = try hex(tokenValue, path: "\(path).palette.\(key)")
            }
        }
        return AppearanceConfiguration(family: family, mode: mode, accent: accent,
                                       material: material, palette: palette)
    }

    private static func layout(_ value: Any?, path: String) throws -> LayoutConfiguration {
        let object = try shape(value, required: ["height", "padding", "notchGap"], optional: [], path: path)
        let height = try range(object["height"], LayoutConfiguration.heightRange, path: "\(path).height")
        let padding = try range(object["padding"], LayoutConfiguration.paddingRange, path: "\(path).padding")
        let notchGap = try range(object["notchGap"], LayoutConfiguration.notchGapRange, path: "\(path).notchGap")
        return LayoutConfiguration(height: height, padding: padding, notchGap: notchGap)
    }

    private static func widgetOptions(_ value: Any?, placed: Set<BarItemID>) throws -> WidgetOptions {
        guard let value else { return .default }
        guard let object = value as? [String: Any] else {
            throw ConfigurationError(path: "widgets", message: "expected object")
        }
        for key in object.keys {
            guard let id = BarItemID(rawValue: key) else {
                throw ConfigurationError(path: "widgets", message: "unknown field \(key)")
            }
            guard placed.contains(id) else {
                throw ConfigurationError(path: "widgets.\(key)", message: "not placed on left or right")
            }
        }
        var options = WidgetOptions.default
        if let raw = object[BarItemID.workspaces.rawValue] {
            options.workspaces = try workspacesOptions(raw, path: "widgets.workspaces")
        }
        if let raw = object[BarItemID.frontApp.rawValue] {
            options.frontApp = try frontAppOptions(raw, path: "widgets.front-app")
        }
        if let raw = object[BarItemID.clock.rawValue] {
            options.clock = try clockOptions(raw, path: "widgets.clock")
        }
        // battery, network, and volume accept an empty object only.
        for id in BarItemID.allCases where !WidgetOptions.acceptsOptions(for: id) {
            if let raw = object[id.rawValue] {
                try shape(raw, required: [], optional: [], path: "widgets.\(id.rawValue)")
            }
        }
        return options
    }

    private static func workspacesOptions(_ value: Any?, path: String) throws -> WorkspacesConfiguration {
        let object = try shape(value,
                               required: [],
                               optional: ["adapter", "showEmpty", "showAppIcons", "showDetails",
                                          "maxAppIconsPerWorkspace"],
                               path: path)
        var configuration = WorkspacesConfiguration.default
        if let rawAdapter = object["adapter"] {
            let raw = try oneOf(rawAdapter, WorkspacesConfiguration.supportedAdapters.map(\.rawValue),
                                path: "\(path).adapter")
            configuration.adapter = WorkspaceManagerKind(rawValue: raw) ?? .aerospace
        }
        if let raw = object["showEmpty"] { configuration.showEmpty = try boolean(raw, path: "\(path).showEmpty") }
        if let raw = object["showAppIcons"] { configuration.showAppIcons = try boolean(raw, path: "\(path).showAppIcons") }
        if let raw = object["showDetails"] { configuration.showDetails = try boolean(raw, path: "\(path).showDetails") }
        if let raw = object["maxAppIconsPerWorkspace"] {
            configuration.maxAppIconsPerWorkspace = try intRange(raw, WorkspacesConfiguration.maxAppIconsRange,
                                                                 path: "\(path).maxAppIconsPerWorkspace")
        }
        return configuration
    }

    private static func frontAppOptions(_ value: Any?, path: String) throws -> FrontAppConfiguration {
        let object = try shape(value, required: [], optional: ["showIcon", "showName"], path: path)
        var configuration = FrontAppConfiguration.default
        if let raw = object["showIcon"] { configuration.showIcon = try boolean(raw, path: "\(path).showIcon") }
        if let raw = object["showName"] { configuration.showName = try boolean(raw, path: "\(path).showName") }
        return configuration
    }

    private static func clockOptions(_ value: Any?, path: String) throws -> ClockConfiguration {
        let object = try shape(value, required: [], optional: ["weekday", "date", "seconds"], path: path)
        var configuration = ClockConfiguration.default
        if let raw = object["weekday"] { configuration.weekday = try boolean(raw, path: "\(path).weekday") }
        if let raw = object["date"] { configuration.date = try boolean(raw, path: "\(path).date") }
        if let raw = object["seconds"] { configuration.seconds = try boolean(raw, path: "\(path).seconds") }
        return configuration
    }

    // MARK: - Version 1 migration

    /// Version 1 hard-coded workspaces on the left and a status-only right array.
    /// Migration moves `workspaces` into `left`, its options into
    /// `widgets.workspaces`, and each `status` identifier into `right`. It never
    /// silently reinterprets a field.
    private static func migrateV1(_ value: Any) throws -> DivotConfiguration {
        let root = try shape(value, required: ["version", "status"],
                             optional: ["appearance", "layout", "workspaces"], path: "root")
        let appearanceConfig = try root["appearance"].map { try appearance($0, path: "appearance") } ?? .default
        let layoutConfig = try root["layout"].map { try layout($0, path: "layout") } ?? .default
        let status = try itemGroup(root["status"], path: "status")
        var widgets = WidgetOptions.default
        if let raw = root["workspaces"] {
            widgets.workspaces = try workspacesOptions(raw, path: "workspaces")
        }
        let left: [BarItemID] = [.workspaces]
        try requireUniquePlacement(left: left, right: status)
        return DivotConfiguration(version: DivotConfiguration.currentVersion,
                                  appearance: appearanceConfig,
                                  layout: layoutConfig,
                                  left: left,
                                  right: status,
                                  widgets: widgets)
    }

    private static func requireUniquePlacement(left: [BarItemID], right: [BarItemID]) throws {
        let placed = left + right
        guard Set(placed).count == placed.count else {
            throw ConfigurationError(path: "left/right", message: "an item may appear in only one group")
        }
    }

    // MARK: - Field helpers

    @discardableResult
    private static func shape(_ value: Any?, required: [String], optional: [String],
                              path: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw ConfigurationError(path: path, message: "expected object")
        }
        let allowed = Set(required + optional)
        for key in object.keys where !allowed.contains(key) {
            throw ConfigurationError(path: path, message: "unknown field \(key)")
        }
        for key in required where object[key] == nil {
            throw ConfigurationError(path: path, message: "expected \(key)")
        }
        return object
    }

    private static func oneOf(_ value: Any?, _ choices: [String], path: String) throws -> String {
        guard let string = value as? String, choices.contains(string) else {
            throw ConfigurationError(path: path, message: "expected \(choices.joined(separator: " | "))")
        }
        return string
    }

    private static func enumValue<T: RawRepresentable & CaseIterable>(
        _ value: Any?, _ type: T.Type, path: String
    ) throws -> T where T.RawValue == String {
        let raw = try oneOf(value, T.allCases.map(\.rawValue), path: path)
        // `oneOf` guarantees membership; the fallback is unreachable.
        return T(rawValue: raw) ?? T.allCases.first!
    }

    private static func hex(_ value: Any?, path: String) throws -> String {
        guard let string = value as? String,
              string.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else {
            throw ConfigurationError(path: path, message: "expected six-digit hex")
        }
        return string
    }

    private static func boolean(_ value: Any?, path: String) throws -> Bool {
        guard let number = value as? NSNumber, isBoolean(number) else {
            throw ConfigurationError(path: path, message: "expected boolean")
        }
        return number.boolValue
    }

    private static func double(_ value: Any?, path: String) throws -> Double {
        guard let number = value as? NSNumber, !isBoolean(number) else {
            throw ConfigurationError(path: path, message: "expected number")
        }
        let result = number.doubleValue
        guard result.isFinite else {
            throw ConfigurationError(path: path, message: "expected finite number")
        }
        return result
    }

    private static func integer(_ value: Any?, path: String) throws -> Int {
        let result = try double(value, path: path)
        guard result == result.rounded(), result >= Double(Int.min), result <= Double(Int.max) else {
            throw ConfigurationError(path: path, message: "expected integer")
        }
        return Int(result)
    }

    private static func range(_ value: Any?, _ bounds: ClosedRange<Double>, path: String) throws -> Double {
        let result = try double(value, path: path)
        guard bounds.contains(result) else {
            throw ConfigurationError(path: path, message: "expected \(describe(bounds))")
        }
        return result
    }

    private static func intRange(_ value: Any?, _ bounds: ClosedRange<Int>, path: String) throws -> Int {
        let result = try integer(value, path: path)
        guard bounds.contains(result) else {
            throw ConfigurationError(path: path,
                                     message: "expected \(bounds.lowerBound)–\(bounds.upperBound)")
        }
        return result
    }

    private static func itemGroup(_ value: Any?, path: String) throws -> [BarItemID] {
        guard let array = value as? [Any] else {
            throw ConfigurationError(path: path, message: "expected array")
        }
        let rawValues = BarItemID.allCases.map(\.rawValue)
        var ids: [BarItemID] = []
        for (index, element) in array.enumerated() {
            let raw = try oneOf(element, rawValues, path: "\(path)[\(index)]")
            guard let id = BarItemID(rawValue: raw) else {
                throw ConfigurationError(path: "\(path)[\(index)]", message: "unknown item")
            }
            ids.append(id)
        }
        guard Set(ids).count == ids.count else {
            throw ConfigurationError(path: path, message: "expected unique items")
        }
        return ids
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func describe(_ bounds: ClosedRange<Double>) -> String {
        "\(number(bounds.lowerBound))–\(number(bounds.upperBound))"
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
