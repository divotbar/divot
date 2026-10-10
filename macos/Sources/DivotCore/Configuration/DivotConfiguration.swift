import Foundation

// MARK: - Appearance

/// The appearance half of the configuration.
///
/// `family` and `mode` are deliberately independent: changing the System/Light/
/// Dark variant keeps the chosen family. Theme families themselves are delivered
/// by the separate theme milestone; this task persists and validates the choice
/// and applies the appearance variant. `palette` overrides individual semantic
/// tokens over the selected family.
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

    /// The effective accent: a palette override wins over the root accent.
    public var effectiveAccent: String { palette[.accent] ?? accent }
}

// MARK: - Layout

/// Panel geometry. Values are logical points and are validated against the
/// documented ranges so an out-of-range file is rejected instead of silently
/// clamped.
public struct LayoutConfiguration: Equatable, Sendable {
    public static let heightRange: ClosedRange<Double> = 24...40
    public static let paddingRange: ClosedRange<Double> = 0...24
    public static let notchGapRange: ClosedRange<Double> = 0...32

    public var height: Double
    public var padding: Double
    public var notchGap: Double

    public init(height: Double = Double(BarMetrics.default.height),
                padding: Double = Double(BarMetrics.default.rowInset),
                notchGap: Double = 10) {
        self.height = height
        self.padding = padding
        self.notchGap = notchGap
    }

    public static let `default` = LayoutConfiguration()

    /// The panel content policy the display coordinator positions panels with.
    public var contentPolicy: BarContentPolicy {
        BarContentPolicy(height: CGFloat(height), clearance: CGFloat(notchGap), edgeMargin: 0)
    }
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

/// Namespaced per-item options. `battery`, `network`, and `volume` accept none.
public struct WidgetOptions: Equatable, Sendable {
    public var workspaces: WorkspacesConfiguration
    public var frontApp: FrontAppConfiguration
    public var clock: ClockConfiguration

    public init(workspaces: WorkspacesConfiguration = .default,
                frontApp: FrontAppConfiguration = .default,
                clock: ClockConfiguration = .default) {
        self.workspaces = workspaces
        self.frontApp = frontApp
        self.clock = clock
    }

    public static let `default` = WidgetOptions()

    /// Whether the contract accepts an options object for this item at all.
    public static func acceptsOptions(for id: BarItemID) -> Bool {
        switch id {
        case .workspaces, .frontApp, .clock: return true
        case .battery, .network, .volume: return false
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

    public var version: Int
    public var appearance: AppearanceConfiguration
    public var layout: LayoutConfiguration
    public var left: [BarItemID]
    public var right: [BarItemID]
    public var widgets: WidgetOptions
    public var keepAwake: KeepAwakeConfiguration

    public init(version: Int = DivotConfiguration.currentVersion,
                appearance: AppearanceConfiguration = .default,
                layout: LayoutConfiguration = .default,
                left: [BarItemID] = DivotConfiguration.defaultLeft,
                right: [BarItemID] = DivotConfiguration.defaultRight,
                widgets: WidgetOptions = .default,
                keepAwake: KeepAwakeConfiguration = .default) {
        self.version = version
        self.appearance = appearance
        self.layout = layout
        self.left = left
        self.right = right
        self.widgets = widgets
        self.keepAwake = keepAwake
    }

    /// Default left is `workspaces`, `front-app`.
    public static let defaultLeft: [BarItemID] = [.workspaces, .frontApp]
    /// Default right is `battery`, `clock`, `network`, `volume`.
    public static let defaultRight: [BarItemID] = [.battery, .clock, .network, .volume]

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
            && widgets == other.widgets
            && appearance == other.appearance
    }

    public func side(of id: BarItemID) -> BarSide? { barLayout.side(of: id) }

    public func items(on side: BarSide) -> [BarItemID] { barLayout.items(on: side) }

    /// Clock and front-app formatting the renderer needs beyond snapshots.
    public var presentationOptions: WidgetPresentationOptions {
        WidgetPresentationOptions(clock: widgets.clock.formatOptions,
                                  frontApp: widgets.frontApp.formatOptions)
    }

    /// The compact render rhythm derived from the configured layout. Fonts,
    /// icon size, item spacing, and the row inset come from `BarMetrics`; only
    /// the height and padding are user-configurable here.
    public var barMetrics: BarMetrics {
        BarMetrics(height: CGFloat(layout.height), rowInset: CGFloat(layout.padding))
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
