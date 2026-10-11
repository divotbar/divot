import Foundation

// MARK: - Appearance

/// The appearance half of the configuration.
///
/// `family` and `mode` are deliberately independent: changing the System/Light/
/// Dark variant keeps the chosen family. The four families resolve to semantic
/// tokens in `DivotCore.ThemeResolver` (see `ThemePalette`); `palette` overrides
/// individual semantic tokens over the selected family and variant.
public struct AppearanceConfiguration: Equatable, Sendable {
    public enum Family: String, CaseIterable, Codable, Sendable {
        case native
        case gruvbox
        case ayu
        case dracula
        case tokyoNight = "tokyo-night"

        public var displayName: String {
            switch self {
            case .native: return "Native"
            case .gruvbox: return "Gruvbox"
            case .ayu: return "Ayu"
            case .dracula: return "Dracula"
            case .tokyoNight: return "Tokyo Night"
            }
        }
    }

    public enum Mode: String, CaseIterable, Codable, Sendable {
        case system
        case dark
        case light

        public var displayName: String {
            switch self {
            case .system: return "System"
            case .dark: return "Dark"
            case .light: return "Light"
            }
        }
    }

    public enum Material: String, CaseIterable, Codable, Sendable {
        case native
        case opaque
    }

    /// Semantic color roles a custom palette may override, merged over the
    /// selected family and variant.
    public enum PaletteToken: String, CaseIterable, Codable, Sendable {
        case foreground
        case background
        case accent
        case selected
        case occupied
        case error
    }

    public var family: Family
    public var mode: Mode
    /// Six-digit hex color, e.g. `#B7CEFF`.
    public var accent: String
    public var material: Material
    /// Optional token overrides. Empty means "use the family as-is".
    public var palette: [PaletteToken: String]

    public init(family: Family = .native,
                mode: Mode = .system,
                accent: String = AppearanceConfiguration.defaultAccent,
                material: Material = .native,
                palette: [PaletteToken: String] = [:]) {
        self.family = family
        self.mode = mode
        self.accent = accent
        self.material = material
        self.palette = palette
    }

    public static let defaultAccent = "#D6F58A"
    public static let `default` = AppearanceConfiguration()

    /// The accent after applying only the palette override: a `palette.accent`
    /// wins over the root accent. Family-aware resolution (the family signature
    /// accent when the root accent is left at its default) lives in
    /// `ThemeResolver.resolve`.
    public var effectiveAccent: String { palette[.accent] ?? accent }
}

// MARK: - Layout

/// Panel geometry. Values are logical points and are validated against the
/// documented ranges so an out-of-range file is rejected instead of silently
/// clamped.
public struct LayoutConfiguration: Equatable, Sendable {
    public static let heightRange: ClosedRange<Double> = 24...40
    public static let paddingRange: ClosedRange<Double> = 0...24

    public var height: Double
    public var padding: Double

    public init(height: Double = Double(BarMetrics.default.height),
                padding: Double = Double(BarMetrics.default.rowInset)) {
        self.height = height
        self.padding = padding
    }

    public static let `default` = LayoutConfiguration()

    /// The panel content policy the display coordinator positions panels with.
    public var contentPolicy: BarContentPolicy {
        BarContentPolicy(height: CGFloat(height), clearance: 0, edgeMargin: 0)
    }
}

// MARK: - Text

/// `text`: the bar's text size and font.
///
/// `size` is the single knob: icon and chip sizes are derived from it in
/// `BarMetrics.scaled`, so the row stays in proportion as the text grows.
/// `font` is an installed font family name; an empty string means the system
/// font, and a name that is not installed falls back to the system font when
/// the bar resolves it (`BarFontResolver`). The parser validates the size range
/// but never rejects a font name — the fallback is at render time, not load
/// time.
public struct TextConfiguration: Equatable, Sendable {
    public static let sizeRange: ClosedRange<Double> = 10...20

    /// Text size in points. Defaults to `BarMetrics.defaultTextSize`, larger
    /// than the originally fixed 12 pt.
    public var size: Double
    /// Font family name, or `""` for the system font.
    public var font: String

    public init(size: Double = Double(BarMetrics.defaultTextSize), font: String = "") {
        self.size = size
        self.font = font
    }

    public static let `default` = TextConfiguration()

    /// The font family to draw with, or `nil` for the system font.
    public var fontFamily: String? { font.isEmpty ? nil : font }
}

// MARK: - Per-widget options

/// `widgets.workspaces`: the workspace row's display options plus the adapter.
public struct WorkspacesConfiguration: Equatable, Sendable {
    /// Window-manager adapter. AeroSpace and yabai ship; the parser rejects any
    /// other value.
    public var adapter: WorkspaceManagerKind
    public var showEmpty: Bool
    public var showAppIcons: Bool
    public var showDetails: Bool
    /// Optional cap on app icons per workspace; `nil` shows all.
    public var maxAppIconsPerWorkspace: Int?

    public init(adapter: WorkspaceManagerKind = .aerospace,
                showEmpty: Bool = true,
                showAppIcons: Bool = false,
                showDetails: Bool = true,
                maxAppIconsPerWorkspace: Int? = nil) {
        self.adapter = adapter
        self.showEmpty = showEmpty
        self.showAppIcons = showAppIcons
        self.showDetails = showDetails
        self.maxAppIconsPerWorkspace = maxAppIconsPerWorkspace
    }

    /// Adapters the current contract accepts.
    public static let supportedAdapters: [WorkspaceManagerKind] = [.aerospace, .yabai]
    public static let maxAppIconsRange: ClosedRange<Int> = 0...32

    public static let `default` = WorkspacesConfiguration()

    /// The renderer's display options, so the row keeps one model.
    public var displayOptions: WorkspaceDisplayOptions {
        WorkspaceDisplayOptions(showEmpty: showEmpty,
                                showAppIcons: showAppIcons,
                                maxAppIconsPerWorkspace: maxAppIconsPerWorkspace,
                                showDetails: showDetails)
    }
}

/// `widgets.front-app`.
public struct FrontAppConfiguration: Equatable, Sendable {
    public var showIcon: Bool
    public var showName: Bool

    public init(showIcon: Bool = true, showName: Bool = true) {
        self.showIcon = showIcon
        self.showName = showName
    }

    public static let `default` = FrontAppConfiguration()

    public var formatOptions: FrontAppFormatOptions {
        FrontAppFormatOptions(showIcon: showIcon, showName: showName)
    }
}

/// `widgets.battery`.
public struct BatteryConfiguration: Equatable, Sendable {
    public var showPercentage: Bool

    public init(showPercentage: Bool = true) {
        self.showPercentage = showPercentage
    }

    public static let `default` = BatteryConfiguration()
}

/// `widgets.clock`.
public struct ClockConfiguration: Equatable, Sendable {
    public var weekday: Bool
    public var date: Bool
    public var seconds: Bool

    public init(weekday: Bool = true, date: Bool = true, seconds: Bool = false) {
        self.weekday = weekday
        self.date = date
        self.seconds = seconds
    }

    public static let `default` = ClockConfiguration()

    public var formatOptions: ClockFormatOptions {
        ClockFormatOptions(weekday: weekday, date: date, seconds: seconds)
    }
}

/// `widgets.date`.
public struct DateConfiguration: Equatable, Sendable {
    /// Whether to show the weekday (e.g. "Sun").
    public var weekday: Bool
    /// Whether to show the year.
    public var year: Bool
    /// Whether to show day before month (e.g. "11 Oct" vs "Oct 11").
    public var dayFirst: Bool
    /// The separator between date components (e.g. " ", "-", "/").
    public var separator: String
    /// Optional custom pattern for advanced users. Falls back to generated pattern if invalid.
    public var customPattern: String?

    public init(weekday: Bool = true,
                year: Bool = false,
                dayFirst: Bool = false,
                separator: String = " ",
                customPattern: String? = nil) {
        self.weekday = weekday
        self.year = year
        self.dayFirst = dayFirst
        self.separator = separator
        self.customPattern = customPattern
    }

    public static let `default` = DateConfiguration()

    public var formatOptions: ClockFormatOptions {
        ClockFormatOptions(weekday: weekday, date: true, seconds: false)
    }

    /// Generate the date format pattern from the configuration options.
    /// Default order is: weekday, day, month (e.g., "Sun 11 Oct")
    public var pattern: String {
        var components: [String] = []

        if weekday { components.append("EEE") }

        // Default (dayFirst=false): day before month → "d MMM" → "11 Oct"
        // dayFirst=true: month before day → "MMM d" → "Oct 11"
        if dayFirst {
            components.append("MMM")
            components.append("d")
        } else {
            components.append("d")
            components.append("MMM")
        }

        if year { components.append("yyyy") }

        return components.joined(separator: separator)
    }
}

/// `widgets.time`.
public struct TimeConfiguration: Equatable, Sendable {
    public enum Format: String, CaseIterable, Codable, Sendable {
        case twentyFourHour = "24-hour"
        case ampm = "AM/PM"
        case custom

        public var displayName: String {
            switch self {
            case .twentyFourHour: return "24-hour"
            case .ampm: return "AM/PM"
            case .custom: return "Custom"
            }
        }
    }

    public var seconds: Bool
    public var timeFormat: Format
    /// Custom time pattern for Format.custom; only meaningful when timeFormat is .custom.
    public var customPattern: String?

    public init(seconds: Bool = false, timeFormat: Format = .ampm, customPattern: String? = nil) {
        self.seconds = seconds
        self.timeFormat = timeFormat
        // Only keep customPattern if timeFormat is custom
        self.customPattern = timeFormat == .custom ? customPattern : nil
    }

    public static let `default` = TimeConfiguration()

    public var formatOptions: ClockFormatOptions {
        ClockFormatOptions(weekday: false, date: false, seconds: seconds)
    }
}

/// `widgets.network`.
public struct NetworkConfiguration: Equatable, Sendable {
    public var showWifiName: Bool

    public init(showWifiName: Bool = false) {
        self.showWifiName = showWifiName
    }

    public static let `default` = NetworkConfiguration()

    public var formatOptions: NetworkFormatOptions {
        NetworkFormatOptions(showWifiName: showWifiName)
    }
}

public struct VolumeConfiguration: Equatable, Sendable {
    public var showVolumePercent: Bool
    public var showVolumeMuted: Bool

    public init(showVolumePercent: Bool = true, showVolumeMuted: Bool = true) {
        self.showVolumePercent = showVolumePercent
        self.showVolumeMuted = showVolumeMuted
    }

    public static let `default` = VolumeConfiguration()

    public var formatOptions: VolumeFormatOptions {
        VolumeFormatOptions(showPercent: showVolumePercent, showMuted: showVolumeMuted)
    }
}

/// The document-level menu-bar detection preference.
///
/// On notched hardware the camera housing masks the same top band whether the
/// native bar is hidden or revealed, so public geometry cannot decide it. Two
/// observations can: the permission-gated Accessibility frame of the bar, and
/// the pointer reaching the top strip, which is when macOS reveals an
/// auto-hidden bar. The cursor observation is direct and on by default
/// (`moveBelowOnCursorReveal`); the Accessibility heuristic is hardware-
/// sensitive and opt-in. On a notch-free display `visibleFrame` alone decides
/// and cross-checks the cursor reading, so both observations are ignored there
/// (#0021, #0023).
public struct MenuBarConfiguration: Equatable, Sendable {
    /// Trust the Accessibility on-screen observation to decide reveal/hide.
    /// Default `false`: the shipping-safe choice.
    public var trustAccessibilityProbe: Bool
    /// Move below the native bar while the pointer is in the top strip, and
    /// return to the top edge when it leaves. Default `true`: the direct
    /// observation makes an auto-hidden bar's reveal followable without the
    /// Accessibility opt-in. When off, Divot keeps its current placement and
    /// only the geometry/Accessibility path decides.
    public var moveBelowOnCursorReveal: Bool
    /// Fallback for Macs where the cursor reveal does not line up: always sit
    /// below the native menu bar. Default `false`.
    public var alwaysBelow: Bool

    public init(trustAccessibilityProbe: Bool = false,
                moveBelowOnCursorReveal: Bool = true,
                alwaysBelow: Bool = false) {
        self.trustAccessibilityProbe = trustAccessibilityProbe
        self.moveBelowOnCursorReveal = moveBelowOnCursorReveal
        self.alwaysBelow = alwaysBelow
    }

    public static let `default` = MenuBarConfiguration()

    /// Whether the top-strip cursor reading can affect placement.
    ///
    /// The event-driven pointer monitor is only worth running while the cursor
    /// reveal is on and the always-below fallback is off: `alwaysBelow` is
    /// authoritative and short-circuits detection, so a cursor engagement could
    /// not change the placement. The app stops the monitor otherwise, so an
    /// install with both features off keeps no global mouse tap installed
    /// (#0023 review).
    public var usesCursorRevealMonitoring: Bool {
        moveBelowOnCursorReveal && !alwaysBelow
    }
}

/// The document-level keep-awake preference.
///
/// `remember` is the settings opt-in: at launch keep-awake is always off unless
/// the user chose to remember it. `isActive` is the remembered on/off state,
/// written only while `remember` is on, so a plain toggle in a session that does
/// not remember never touches the file. It is a root field rather than a
/// `widgets.battery` option because the toggle must keep validating even when
/// the battery item is not placed on either side.
public struct KeepAwakeConfiguration: Equatable, Sendable {
    /// Persist the state across launches. Default off.
    public var remember: Bool
    /// The remembered state. Only meaningful when `remember` is `true`.
    public var isActive: Bool

    public init(remember: Bool = false, isActive: Bool = false) {
        self.remember = remember
        self.isActive = isActive
    }

    public static let `default` = KeepAwakeConfiguration()
}

/// Namespaced per-item options. `battery`, `appearance`, and items without options accept none.
public struct WidgetOptions: Equatable, Sendable {
    public var workspaces: WorkspacesConfiguration
    public var frontApp: FrontAppConfiguration
    public var battery: BatteryConfiguration
    public var clock: ClockConfiguration
    public var date: DateConfiguration
    public var time: TimeConfiguration
    public var network: NetworkConfiguration
    public var volume: VolumeConfiguration

    public init(workspaces: WorkspacesConfiguration = .default,
                frontApp: FrontAppConfiguration = .default,
                battery: BatteryConfiguration = .default,
                clock: ClockConfiguration = .default,
                date: DateConfiguration = .default,
                time: TimeConfiguration = .default,
                network: NetworkConfiguration = .default,
                volume: VolumeConfiguration = .default) {
        self.workspaces = workspaces
        self.frontApp = frontApp
        self.battery = battery
        self.clock = clock
        self.date = date
        self.time = time
        self.network = network
        self.volume = volume
    }

    public static let `default` = WidgetOptions()

    /// Whether the contract accepts an options object for this item at all.
    public static func acceptsOptions(for id: BarItemID) -> Bool {
        switch id {
        case .workspaces, .frontApp, .battery, .clock, .date, .time, .network, .volume: return true
        case .appearance: return false
        }
    }
}

// MARK: - The document

/// The validated versioned configuration document.
///
/// One model serves file reload and the settings surface: it expresses ordered
/// `left` and `right` item groups plus namespaced per-item options, and its
/// defaults fill the first-launch bar so customization never starts from blank.
public struct DivotConfiguration: Equatable, Sendable {
    /// The only version the native loader accepts. Older supported versions are
    /// migrated explicitly by the parser; unknown versions are rejected.
    public static let currentVersion = 2
    public static let chipOpacityRange: ClosedRange<Int> = 0...100

    public var version: Int
    public var appearance: AppearanceConfiguration
    public var layout: LayoutConfiguration
    public var text: TextConfiguration
    public var left: [BarItemID]
    public var right: [BarItemID]
    public var widgets: WidgetOptions
    public var keepAwake: KeepAwakeConfiguration
    public var menuBar: MenuBarConfiguration
    /// Show the Divot mark at the start of the left group, before the
    /// workspaces; clicking it opens the Divot settings window. Root-level
    /// because it decorates the bar's left group rather than a single item, and
    /// it is off by default so the first-launch bar is unchanged (#0024).
    public var showAppIcon: Bool
    /// Draw the filled dot on an occupied (non-focused) workspace chip. On by
    /// default so the first-launch bar keeps today's look; turning it off hides
    /// only that marker, leaving the name and focus highlight. Root-level
    /// because it changes only the marker drawing, not the workspace feed
    /// (#0026).
    public var showOccupiedDot: Bool
    /// Draw the hollow ring on an empty (non-focused) workspace chip. On by
    /// default; turning it off hides only that marker (#0026).
    public var showEmptyDot: Bool
    /// Draw a subtle drop shadow along the bottom edge of the bar. Off by
    /// default so the first-launch bar is unshadowed; when on, the panel extends
    /// a few points below the bar and a soft gradient fades downward, so the
    /// shadow runs along the bottom edge only and never rims the other edges.
    /// Root-level because it changes only the panel chrome, not any item
    /// (#0025).
    public var bottomShadow: Bool
    /// Draw each bar item in its own rounded chip with padding and theme
    /// background. Off by default so the first-launch bar has items blend
    /// together; when on, each item sits in its own chip with the same padding
    /// and theme colours (#0030).
    public var chipStyle: Bool
    /// The workspace chip background opacity, 0–100. 0 is the current chip
    /// appearance (matching `backgroundColor` color); 100 makes the chip
    /// background match the bar background, so chips are invisible and only
    /// the workspace content shows (#0047).
    public var chipOpacity: Int

    public init(version: Int = DivotConfiguration.currentVersion,
                appearance: AppearanceConfiguration = .default,
                layout: LayoutConfiguration = .default,
                text: TextConfiguration = .default,
                left: [BarItemID] = DivotConfiguration.defaultLeft,
                right: [BarItemID] = DivotConfiguration.defaultRight,
                widgets: WidgetOptions = .default,
                keepAwake: KeepAwakeConfiguration = .default,
                menuBar: MenuBarConfiguration = .default,
                showAppIcon: Bool = false,
                showOccupiedDot: Bool = true,
                showEmptyDot: Bool = true,
                bottomShadow: Bool = false,
                chipStyle: Bool = false,
                chipOpacity: Int = 0) {
        self.version = version
        self.appearance = appearance
        self.layout = layout
        self.text = text
        self.left = left
        self.right = right
        self.widgets = widgets
        self.keepAwake = keepAwake
        self.menuBar = menuBar
        self.showAppIcon = showAppIcon
        self.showOccupiedDot = showOccupiedDot
        self.showEmptyDot = showEmptyDot
        self.bottomShadow = bottomShadow
        self.chipStyle = chipStyle
        self.chipOpacity = max(0, min(chipOpacity, 100))
    }

    /// Default left is `workspaces`, `front-app`.
    public static let defaultLeft: [BarItemID] = [.workspaces, .frontApp]
    /// Default right is `battery`, `time`, `network`, `volume`.
    public static let defaultRight: [BarItemID] = [.battery, .time, .network, .volume]

    /// The first-launch bar: beautiful without any user input.
    public static let `default` = DivotConfiguration()

    // MARK: Derived

    /// The ordered groups the renderer uses.
    public var barLayout: BarLayout { BarLayout(left: left, right: right) }

    /// Every placed item, left-then-right.
    public var placedItems: [BarItemID] { left + right }

    public func isPlaced(_ id: BarItemID) -> Bool {
        left.contains(id) || right.contains(id)
    }

    /// Whether two documents describe the same rendered bar.
    ///
    /// Keep-awake persistence is a runtime preference, not bar content, so a
    /// toggle that only remembers the assertion state must not rebuild the
    /// panels. The display coordinator compares this instead of the whole
    /// document to avoid a flicker on every battery click.
    public func rendersSameBar(as other: DivotConfiguration) -> Bool {
        left == other.left
            && right == other.right
            && layout == other.layout
            && text == other.text
            && widgets == other.widgets
            && appearance == other.appearance
            && showAppIcon == other.showAppIcon
            && showOccupiedDot == other.showOccupiedDot
            && showEmptyDot == other.showEmptyDot
            && bottomShadow == other.bottomShadow
            && chipStyle == other.chipStyle
            && chipOpacity == other.chipOpacity
    }

    public func side(of id: BarItemID) -> BarSide? { barLayout.side(of: id) }

    public func items(on side: BarSide) -> [BarItemID] { barLayout.items(on: side) }

    /// Clock, date, time, battery, network, volume, and front-app formatting the
    /// renderer needs beyond snapshots.
    public var presentationOptions: WidgetPresentationOptions {
        let dateFormatPattern: String? = {
            if let customPattern = widgets.date.customPattern,
               ClockText.isValidPattern(customPattern) {
                return customPattern
            }
            return widgets.date.pattern
        }()
        return WidgetPresentationOptions(clock: widgets.clock.formatOptions,
                                  date: widgets.date.formatOptions,
                                  dateFormatPattern: dateFormatPattern,
                                  time: widgets.time.formatOptions,
                                  timeFormat: widgets.time.timeFormat,
                                  customTimePattern: widgets.time.customPattern,
                                  frontApp: widgets.frontApp.formatOptions,
                                  battery: BatteryFormatOptions(showPercentage: widgets.battery.showPercentage),
                                  network: widgets.network.formatOptions,
                                  volume: widgets.volume.formatOptions)
    }

    /// The compact render rhythm derived from the configured layout and text.
    /// Item spacing and the icon/text gap come from `BarMetrics`; the height,
    /// padding, text size, and font are user-configurable here, and the icon and
    /// chip sizes follow the text size so the row stays in proportion.
    public var barMetrics: BarMetrics {
        BarMetrics.scaled(textSize: CGFloat(text.size),
                          height: CGFloat(layout.height),
                          rowInset: CGFloat(layout.padding),
                          fontFamily: text.fontFamily)
    }

    // MARK: Editing

    /// Remove an item from whichever group holds it. Idempotent.
    public mutating func remove(_ id: BarItemID) {
        left.removeAll { $0 == id }
        right.removeAll { $0 == id }
    }

    /// Move an item to `side`, inserting at `index` (clamped). Moving an item
    /// that already lives on the other side removes it from there first, so an
    /// item is never duplicated.
    public mutating func move(_ id: BarItemID, to side: BarSide, at index: Int? = nil) {
        remove(id)
        switch side {
        case .left:
            left.insert(id, at: max(0, min(index ?? left.count, left.count)))
        case .right:
            right.insert(id, at: max(0, min(index ?? right.count, right.count)))
        }
    }
}
