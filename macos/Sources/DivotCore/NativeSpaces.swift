import CoreGraphics
import Foundation

// MARK: - Native macOS Spaces research model
//
// Task 0013 asks one question: how much of a native macOS Spaces adapter can be
// built from *public* APIs? This file is the answer as a tested, platform-free
// model. It is deliberately **not** wired into `WorkspaceAdapting`,
// `WorkspaceManagerKind`, or the workspace feed: there is no native Spaces
// adapter to ship, and adding a manager kind or a private API to claim parity
// would contradict the story ("an honest unavailable state, not fake native
// Spaces support").
//
// `DivotSpacesProbe` fills `NativeSpaceObservation` from public AppKit/Core
// Graphics reads; the capability tables below are the primary-source summary.

// MARK: - Operations

/// The four capabilities a native Spaces adapter would need, plus the two that
/// *are* achievable and are the honest substitute.
public enum NativeSpacesOperation: String, CaseIterable, Sendable {
    /// Enumerate every Space with an identity, name, and order.
    case listSpaces
    /// Activate a specific Space.
    case switchToSpace
    /// Group windows/apps under the Space they belong to.
    case mapAppsToSpaces
    /// Know which Space is showing on each display.
    case perDisplaySpaces
    /// Learn that the active Space changed at all (no identity).
    case observeActiveSpaceChange
    /// Enumerate displays. **Achievable** with public `NSScreen`.
    case listDisplays
    /// Group windows/apps under the display they currently occupy.
    /// **Achievable** with public `NSScreen` + `CGWindowListCopyWindowInfo`.
    case mapAppsToDisplays

    public var title: String {
        switch self {
        case .listSpaces: return "list Spaces"
        case .switchToSpace: return "switch Space"
        case .mapAppsToSpaces: return "map apps to Spaces"
        case .perDisplaySpaces: return "per-display Spaces"
        case .observeActiveSpaceChange: return "observe Space change"
        case .listDisplays: return "list displays"
        case .mapAppsToDisplays: return "map apps to displays"
        }
    }
}

/// How far a public-API implementation can get. Every case is a claim the
/// project can defend from primary sources.
public enum NativeSpacesSupport: Equatable, Sendable {
    /// Fully available through documented, supported APIs.
    case publicAPI
    /// The documented API exists, but reports only *that* something changed —
    /// not which Space, and not an identifier to act on.
    case publicAPIWithoutSpaceIdentity
    /// Only reachable through a user-granted system permission, and even then
    /// only indirectly.
    case permissionGated(permission: String)
    /// No public API. Only private (undocumented, unsupported) symbols reach
    /// it; shipping them is out of scope.
    case privateAPIOnly(reason: String)
    /// Not available through any supported path.
    case unavailable

    /// Short machine-readable label for the probe's report line.
    public var label: String {
        switch self {
        case .publicAPI: return "public"
        case .publicAPIWithoutSpaceIdentity: return "public-no-identity"
        case .permissionGated(let permission): return "permission(\(permission))"
        case .privateAPIOnly: return "private-only"
        case .unavailable: return "unavailable"
        }
    }

    /// Whether the behavior can be implemented without private APIs.
    public var isPubliclyAchievable: Bool {
        switch self {
        case .publicAPI, .publicAPIWithoutSpaceIdentity, .permissionGated:
            return true
        case .privateAPIOnly, .unavailable:
            return false
        }
    }
}

/// One finding: an operation, how far public APIs reach, why, and the source.
public struct NativeSpacesCapability: Equatable, Sendable {
    public let operation: NativeSpacesOperation
    public let support: NativeSpacesSupport
    public let detail: String
    /// Primary source, short form; the evidence doc carries the links.
    public let source: String

    public init(operation: NativeSpacesOperation,
                support: NativeSpacesSupport,
                detail: String,
                source: String) {
        self.operation = operation
        self.support = support
        self.detail = detail
        self.source = source
    }
}

/// The full public-API capability answer.
public enum NativeSpacesCapabilities {
    /// Findings from task 0013, in report order.
    public static let publicAPIOnly: [NativeSpacesCapability] = [
        NativeSpacesCapability(
            operation: .listSpaces,
            support: .privateAPIOnly(reason: "no public API enumerates Spaces"),
            detail: "No supported API returns the set of Spaces or their identities. "
                + "The pre-10.11 window key kCGWindowWorkspace is deprecated and "
                + "no longer populated; enumerating Spaces uses the private "
                + "SkyLight call CGSCopyManagedDisplaySpaces.",
            source: "Apple kCGWindowWorkspace (Deprecated); AltTab issue #14"),
        NativeSpacesCapability(
            operation: .switchToSpace,
            support: .privateAPIOnly(reason: "no public API activates a Space"),
            detail: "No public call activates a Space. Synthesizing the Mission Control "
                + "keyboard shortcut with CGEvent is indirect, needs Accessibility/Input "
                + "Monitoring trust, only works when the user enabled that shortcut, and "
                + "cannot target a Space identity. Direct activation is private "
                + "(CGSSetActiveSpace) and, in yabai, requires System Integrity "
                + "Protection to be disabled.",
            source: "Apple CGEvent; yabai wiki (Disabling System Integrity Protection)"),
        NativeSpacesCapability(
            operation: .mapAppsToSpaces,
            support: .privateAPIOnly(reason: "window lists do not carry a Space identity"),
            detail: "CGWindowListCopyWindowInfo with the on-screen option returns only the "
                + "active Space's windows, with no Space id; kCGWindowWorkspace is "
                + "deprecated. Attribution to a named Space is private "
                + "(CGSCopyWindowsWithOptionsAndTags / CGSCopySpacesForWindows).",
            source: "Apple CGWindowListCopyWindowInfo; AltTab issue #14"),
        NativeSpacesCapability(
            operation: .perDisplaySpaces,
            support: .privateAPIOnly(reason: "per-display Space attribution is private"),
            detail: "NSScreen reports displays, not the Space shown on each. Which Space is "
                + "on which display comes from the private "
                + "CGSCopyManagedDisplaySpaces ledger.",
            source: "Apple NSScreen; AltTab issue #14"),
        NativeSpacesCapability(
            operation: .observeActiveSpaceChange,
            support: .publicAPIWithoutSpaceIdentity,
            detail: "NSWorkspace.activeSpaceDidChangeNotification is public and fires on a "
                + "Spaces change, but the notification carries no Space identity, index, or "
                + "name — it can only trigger a re-read, and there is nothing supported to "
                + "re-read.",
            source: "Apple NSWorkspace.activeSpaceDidChangeNotification"),
        NativeSpacesCapability(
            operation: .listDisplays,
            support: .publicAPI,
            detail: "NSScreen.screens exposes each display's frame, visibleFrame, backing "
                + "scale, and stable CGDirectDisplayID through deviceDescription.",
            source: "Apple NSScreen; NSDeviceDescriptionKey"),
        NativeSpacesCapability(
            operation: .mapAppsToDisplays,
            support: .publicAPI,
            detail: "Every on-screen window reports owner PID and bounds. Joining bounds to "
                + "NSScreen frames (after flipping Core Graphics' top-left origin) maps an "
                + "app to the display it currently occupies — a display, not a Space.",
            source: "Apple CGWindowListCopyWindowInfo")
    ]

    /// Operations that a public-API-only adapter could actually perform.
    public static var publiclyAchievable: [NativeSpacesCapability] {
        publicAPIOnly.filter { $0.support.isPubliclyAchievable }
    }

    /// Operations that require private APIs or are otherwise unavailable.
    public static var notPubliclyAchievable: [NativeSpacesCapability] {
        publicAPIOnly.filter { !$0.support.isPubliclyAchievable }
    }

    public static func capability(for operation: NativeSpacesOperation) -> NativeSpacesCapability {
        // Every operation has exactly one entry; force is safe and documented.
        publicAPIOnly.first { $0.operation == operation }!
    }
}

// MARK: - Observable model (public APIs only)

/// A display as public `NSScreen` reports it, in AppKit global coordinates.
public struct NativeSpaceDisplay: Hashable, Sendable, Identifiable {
    /// Stable `CGDirectDisplayID` from `NSScreen.deviceDescription`.
    public let id: UInt32
    public let name: String
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let backingScaleFactor: Double
    public let isMain: Bool

    public init(id: UInt32,
                name: String = "",
                frame: CGRect,
                visibleFrame: CGRect,
                backingScaleFactor: Double = 1,
                isMain: Bool = false) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.backingScaleFactor = backingScaleFactor
        self.isMain = isMain
    }

    public var displayName: String { name.isEmpty ? "Display \(id)" : name }
}

/// One window as public `CGWindowListCopyWindowInfo` reports it. `bounds` is
/// normalized to AppKit screen coordinates so it can be compared to
/// `NativeSpaceDisplay.frame` without either side guessing a convention.
public struct NativeSpaceWindow: Hashable, Sendable {
    public let windowNumber: Int
    public let ownerName: String
    public let bundleID: String
    public let pid: Int
    public let bounds: CGRect
    public let isOnScreen: Bool
    public let layer: Int

    public init(windowNumber: Int,
                ownerName: String = "",
                bundleID: String = "",
                pid: Int = 0,
                bounds: CGRect = .zero,
                isOnScreen: Bool = true,
                layer: Int = 0) {
        self.windowNumber = windowNumber
        self.ownerName = ownerName
        self.bundleID = bundleID
        self.pid = pid
        self.bounds = bounds
        self.isOnScreen = isOnScreen
        self.layer = layer
    }

    /// App identity for dedup, matching the shared workspace model: bundle id
    /// when present, otherwise the owner name.
    public var identity: WorkspaceAppIdentity {
        WorkspaceAppIdentity(bundleID: bundleID, name: ownerName)
    }
}

/// One public-API observation pass. It can never contain Spaces: `spaceListing`
/// is always `.unavailable`, which is the point of the task.
public struct NativeSpaceObservation: Equatable, Sendable {
    public let displays: [NativeSpaceDisplay]
    /// Windows that public APIs can currently see (the active Space only).
    public let windows: [NativeSpaceWindow]

    public init(displays: [NativeSpaceDisplay], windows: [NativeSpaceWindow]) {
        self.displays = displays
        self.windows = windows
    }

    /// Public APIs cannot enumerate Spaces, so this is always unavailable. It is
    /// modeled explicitly rather than represented by an empty array, so a caller
    /// cannot mistake "not supported" for "no Spaces".
    public var spaceListing: NativeSpaceListing { .unavailable(reason: NativeSpacesCapabilities
        .capability(for: .listSpaces).detail) }

    public var isMultiDisplay: Bool { displays.count > 1 }

    /// The display containing a point, if any. Uses `frame`, not
    /// `visibleFrame`: a window may sit under the menu bar or Dock.
    public func display(containing point: CGPoint) -> NativeSpaceDisplay? {
        displays.first { $0.frame.contains(point) }
    }

    /// Windows assigned to a display by the center of their bounds. Windows
    /// whose center lands on no display (mid-animation, off-screen) are
    /// excluded rather than guessed at.
    public func windows(on display: NativeSpaceDisplay) -> [NativeSpaceWindow] {
        windows.filter { window in
            self.display(containing: CGPoint(x: window.bounds.midX, y: window.bounds.midY))?.id == display.id
        }
    }

    /// Deduplicated apps occupying a display, in stable first-seen order.
    public func apps(on display: NativeSpaceDisplay) -> [WorkspaceAppIdentity] {
        var seen = Set<String>()
        var result: [WorkspaceAppIdentity] = []
        for window in windows(on: display) where seen.insert(window.identity.dedupKey).inserted {
            result.append(window.identity)
        }
        return result
    }

    /// Deduplicated apps across every currently visible window.
    public var allApps: [WorkspaceAppIdentity] {
        var seen = Set<String>()
        var result: [WorkspaceAppIdentity] = []
        for window in windows where seen.insert(window.identity.dedupKey).inserted {
            result.append(window.identity)
        }
        return result
    }
}

/// The honest result of trying to enumerate Spaces with public APIs.
public enum NativeSpaceListing: Equatable, Sendable {
    case unavailable(reason: String)
    case listed([NativeSpaceReference])

    public var spaces: [NativeSpaceReference] {
        if case .listed(let spaces) = self { return spaces }
        return []
    }

    public var isAvailable: Bool {
        if case .listed = self { return true }
        return false
    }
}

/// A Space identity. Only private APIs could populate this; the type exists so a
/// future supported path can be modeled without changing call sites.
public struct NativeSpaceReference: Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let displayID: UInt32?

    public init(id: Int, name: String = "", displayID: UInt32? = nil) {
        self.id = id
        self.name = name
        self.displayID = displayID
    }
}
