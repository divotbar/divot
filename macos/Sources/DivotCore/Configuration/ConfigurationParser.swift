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
                             optional: ["text", "widgets", "keepAwake", "menuBar", "showAppIcon",
                                        "showOccupiedDot", "showEmptyDot", "bottomShadow", "chipStyle", "chipOpacity",
                                        "appIconSize"], path: "root")
        let appearance = try appearance(root["appearance"], path: "appearance")
        let layout = try layout(root["layout"], path: "layout")
        let text = try textOptions(root["text"])
        var left = try itemGroup(root["left"], path: "left")
        var right = try itemGroup(root["right"], path: "right")

        // Migrate the legacy combined clock to time (#0033). Every occurrence is
        // rewritten so a document that named clock on both sides is then caught
        // as the duplicate it was.
        left = left.map { $0 == .clock ? .time : $0 }
        right = right.map { $0 == .clock ? .time : $0 }

        try requireUniquePlacement(left: left, right: right)
        let widgets = try widgetOptions(root["widgets"], placed: Set(left + right))
        let keepAwake = try keepAwakeOptions(root["keepAwake"])
        let menuBar = try menuBarOptions(root["menuBar"])
        var showAppIcon = false
        if let raw = root["showAppIcon"] { showAppIcon = try boolean(raw, path: "showAppIcon") }
        // The workspace markers are on by default, so an omitted key keeps
        // today's look and only an explicit `false` hides one (#0026).
        var showOccupiedDot = true
        if let raw = root["showOccupiedDot"] { showOccupiedDot = try boolean(raw, path: "showOccupiedDot") }
        var showEmptyDot = true
        if let raw = root["showEmptyDot"] { showEmptyDot = try boolean(raw, path: "showEmptyDot") }
        // The bottom shadow is off by default, so an omitted key keeps the
        // first-launch look and only an explicit `true` turns it on (#0025).
        var bottomShadow = false
        if let raw = root["bottomShadow"] { bottomShadow = try boolean(raw, path: "bottomShadow") }
        // Chip style is off by default, so an omitted key keeps items blended
        // and only an explicit `true` draws them as distinct chips (#0030).
        var chipStyle = false
        if let raw = root["chipStyle"] { chipStyle = try boolean(raw, path: "chipStyle") }
        // Chip opacity is 0 by default, so an omitted key keeps the current
        // chip appearance; explicit values 0–100 control the background opacity
        // (#0047).
        var chipOpacity = 0
        if let raw = root["chipOpacity"] { chipOpacity = try intRange(raw, DivotConfiguration.chipOpacityRange, path: "chipOpacity") }
        // App icon size defaults to the status icon size, so the left app icons
        // match the right-side icons until it is overridden (#0052).
        var appIconSize = Double(BarMetrics.default.iconSize)
        if let raw = root["appIconSize"] { appIconSize = try range(raw, DivotConfiguration.appIconSizeRange, path: "appIconSize") }
        return DivotConfiguration(version: DivotConfiguration.currentVersion,
                                  appearance: appearance,
                                  layout: layout,
                                  text: text,
                                  left: left,
                                  right: right,
                                  widgets: widgets,
                                  keepAwake: keepAwake,
                                  menuBar: menuBar,
                                  showAppIcon: showAppIcon,
                                  showOccupiedDot: showOccupiedDot,
                                  showEmptyDot: showEmptyDot,
                                  bottomShadow: bottomShadow,
                                  chipStyle: chipStyle,
                                  chipOpacity: chipOpacity,
                                  appIconSize: appIconSize)
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
        let object = try shape(value, required: ["height", "padding"],
                               optional: ["notchGap", "rightItemSpacing", "leftItemSpacing"],
                               path: path)
        let height = try range(object["height"], LayoutConfiguration.heightRange, path: "\(path).height")
        let padding = try range(object["padding"], LayoutConfiguration.paddingRange, path: "\(path).padding")
        // Item spacing is omitted by documents written before #0054, so an
        // absent key keeps the restored uniform 8 pt default rather than
        // rejecting the file (#0060).
        var rightItemSpacing = LayoutConfiguration.defaultRightItemSpacing
        if let raw = object["rightItemSpacing"] {
            rightItemSpacing = try range(raw, LayoutConfiguration.itemSpacingRange, path: "\(path).rightItemSpacing")
        }
        var leftItemSpacing = LayoutConfiguration.defaultLeftItemSpacing
        if let raw = object["leftItemSpacing"] {
            leftItemSpacing = try range(raw, LayoutConfiguration.itemSpacingRange, path: "\(path).leftItemSpacing")
        }
        // Legacy notchGap is accepted but ignored; validate it matches the historical range
        if let notchGap = object["notchGap"] {
            _ = try range(notchGap, ClosedRange(uncheckedBounds: (0, 32)), path: "\(path).notchGap")
        }
        return LayoutConfiguration(height: height, padding: padding,
                                   rightItemSpacing: rightItemSpacing,
                                   leftItemSpacing: leftItemSpacing)
    }

    private static func widgetOptions(_ value: Any?, placed: Set<BarItemID>) throws -> WidgetOptions {
        guard let value else { return .default }
        guard var object = value as? [String: Any] else {
            throw ConfigurationError(path: "widgets", message: "expected object")
        }
        // Migrate the legacy combined-clock namespace to time/date before
        // validating, so a document that still carries `widgets.clock` is
        // accepted and rewritten rather than rejected as unplaced or left stale
        // (#0033). The key is removed so it can never be re-saved.
        if let clockRaw = object[BarItemID.clock.rawValue] {
            object[BarItemID.clock.rawValue] = nil
            if let clockObj = clockRaw as? [String: Any] {
                // If time is placed, migrate the seconds option.
                if placed.contains(.time) && object[BarItemID.time.rawValue] == nil {
                    var timeObj = [String: Any]()
                    if let seconds = clockObj["seconds"] { timeObj["seconds"] = seconds }
                    if !timeObj.isEmpty { object[BarItemID.time.rawValue] = timeObj }
                }
                // If date is placed, migrate the weekday option.
                if placed.contains(.date) && object[BarItemID.date.rawValue] == nil {
                    var dateObj = [String: Any]()
                    if let weekday = clockObj["weekday"] { dateObj["weekday"] = weekday }
                    if !dateObj.isEmpty { object[BarItemID.date.rawValue] = dateObj }
                }
            } else {
                // A malformed clock namespace still reports its own path.
                _ = try clockOptions(clockRaw, path: "widgets.clock")
            }
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
        if let raw = object[BarItemID.battery.rawValue] {
            options.battery = try batteryOptions(raw, path: "widgets.battery")
        }
        if let raw = object[BarItemID.date.rawValue] {
            options.date = try dateOptions(raw, path: "widgets.date")
        }
        if let raw = object[BarItemID.time.rawValue] {
            options.time = try timeOptions(raw, path: "widgets.time")
        }
        if let raw = object[BarItemID.network.rawValue] {
            options.network = try networkOptions(raw, path: "widgets.network")
        }
        if let raw = object[BarItemID.volume.rawValue] {
            options.volume = try volumeOptions(raw, path: "widgets.volume")
        }
        // Items without options accept an empty object only.
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

    private static func batteryOptions(_ value: Any?, path: String) throws -> BatteryConfiguration {
        let object = try shape(value, required: [], optional: ["showPercentage"], path: path)
        var configuration = BatteryConfiguration.default
        if let raw = object["showPercentage"] { configuration.showPercentage = try boolean(raw, path: "\(path).showPercentage") }
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

    private static func dateOptions(_ value: Any?, path: String) throws -> DateConfiguration {
        let object = try shape(value, required: [], optional: ["weekday", "year", "dayFirst", "separator", "customPattern"], path: path)
        var configuration = DateConfiguration.default
        if let raw = object["weekday"] { configuration.weekday = try boolean(raw, path: "\(path).weekday") }
        if let raw = object["year"] { configuration.year = try boolean(raw, path: "\(path).year") }
        if let raw = object["dayFirst"] { configuration.dayFirst = try boolean(raw, path: "\(path).dayFirst") }
        if let raw = object["separator"] {
            guard let sep = raw as? String else {
                throw ConfigurationError(path: "\(path).separator", message: "expected string")
            }
            configuration.separator = sep
        }
        if let raw = object["customPattern"] {
            guard let pattern = raw as? String else {
                throw ConfigurationError(path: "\(path).customPattern", message: "expected string")
            }
            // Validate the pattern but don't reject the document if invalid
            if ClockText.isValidPattern(pattern) {
                configuration.customPattern = pattern
            }
        }
        return configuration
    }

    private static func timeOptions(_ value: Any?, path: String) throws -> TimeConfiguration {
        let object = try shape(value, required: [], optional: ["seconds", "timeFormat", "customPattern"], path: path)
        var configuration = TimeConfiguration.default
        if let raw = object["seconds"] { configuration.seconds = try boolean(raw, path: "\(path).seconds") }
        if let raw = object["timeFormat"] {
            configuration.timeFormat = try enumValue(raw, TimeConfiguration.Format.self, path: "\(path).timeFormat")
        }
        if let raw = object["customPattern"] {
            guard let string = raw as? String else {
                throw ConfigurationError(path: "\(path).customPattern", message: "expected string")
            }
            configuration.customPattern = string.isEmpty ? nil : string
        }
        return configuration
    }

    private static func networkOptions(_ value: Any?, path: String) throws -> NetworkConfiguration {
        let object = try shape(value, required: [], optional: ["showWifiName"], path: path)
        var configuration = NetworkConfiguration.default
        if let raw = object["showWifiName"] { configuration.showWifiName = try boolean(raw, path: "\(path).showWifiName") }
        return configuration
    }

    private static func volumeOptions(_ value: Any?, path: String) throws -> VolumeConfiguration {
        let object = try shape(value, required: [], optional: ["showVolumePercent", "showVolumeMuted"], path: path)
        var configuration = VolumeConfiguration.default
        if let raw = object["showVolumePercent"] { configuration.showVolumePercent = try boolean(raw, path: "\(path).showVolumePercent") }
        if let raw = object["showVolumeMuted"] { configuration.showVolumeMuted = try boolean(raw, path: "\(path).showVolumeMuted") }
        return configuration
    }

    private static func textOptions(_ value: Any?) throws -> TextConfiguration {
        guard let value else { return .default }
        let object = try shape(value, required: [], optional: ["size", "font"], path: "text")
        var configuration = TextConfiguration.default
        if let raw = object["size"] {
            configuration.size = try range(raw, TextConfiguration.sizeRange, path: "text.size")
        }
        if let raw = object["font"] {
            guard let string = raw as? String else {
                throw ConfigurationError(path: "text.font", message: "expected string")
            }
            // Any name is accepted: an uninstalled font falls back to the system
            // font at render time rather than failing the whole document.
            configuration.font = string
        }
        return configuration
    }

    private static func keepAwakeOptions(_ value: Any?) throws -> KeepAwakeConfiguration {
        guard let value else { return .default }
        let object = try shape(value, required: [], optional: ["remember", "isActive"], path: "keepAwake")
        var configuration = KeepAwakeConfiguration.default
        if let raw = object["remember"] { configuration.remember = try boolean(raw, path: "keepAwake.remember") }
        if let raw = object["isActive"] { configuration.isActive = try boolean(raw, path: "keepAwake.isActive") }
        return configuration
    }

    private static func menuBarOptions(_ value: Any?) throws -> MenuBarConfiguration {
        guard let value else { return .default }
        let object = try shape(value, required: [],
                               optional: ["trustAccessibilityProbe", "moveBelowOnCursorReveal", "alwaysBelow"],
                               path: "menuBar")
        var configuration = MenuBarConfiguration.default
        if let raw = object["trustAccessibilityProbe"] {
            configuration.trustAccessibilityProbe = try boolean(raw, path: "menuBar.trustAccessibilityProbe")
        }
        if let raw = object["moveBelowOnCursorReveal"] {
            configuration.moveBelowOnCursorReveal = try boolean(raw, path: "menuBar.moveBelowOnCursorReveal")
        }
        if let raw = object["alwaysBelow"] {
            configuration.alwaysBelow = try boolean(raw, path: "menuBar.alwaysBelow")
        }
        return configuration
    }

    // MARK: - Version 1 migration

    /// Version 1 hard-coded workspaces on the left and a status-only right array.
    /// Migration moves `workspaces` into `left`, its options into
    /// `widgets.workspaces`, and each `status` identifier into `right`. It never
    /// silently reinterprets a field. Clock items are migrated to time (#0033).
    private static func migrateV1(_ value: Any) throws -> DivotConfiguration {
        let root = try shape(value, required: ["version", "status"],
                             optional: ["appearance", "layout", "workspaces"], path: "root")
        let appearanceConfig = try root["appearance"].map { try appearance($0, path: "appearance") } ?? .default
        let layoutConfig = try root["layout"].map { try layout($0, path: "layout") } ?? .default
        var status = try itemGroup(root["status"], path: "status")

        // Migrate the legacy combined clock to time (#0033).
        status = status.map { $0 == .clock ? .time : $0 }

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
