import AppKit
import DivotCore

/// `NSRunningApplication`-backed bundle-id lookup for an adapter whose CLI
/// reports only an app name and pid (yabai).
///
/// It returns `nil` rather than guessing when the process is unknown or has no
/// bundle id, so the identity falls back to the app name and simply shows no
/// icon.
public struct RunningApplicationIdentityResolver: WorkspaceProcessIdentityResolving {
    public init() {}

    public func bundleIdentifier(forProcessID pid: Int) -> String? {
        guard pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier
    }
}

/// Maps a manager display id (a `CGDirectDisplayID`, as yabai reports) to
/// Divot's 1-based `NSScreen.screens` index.
///
/// The screen list is captured on the main actor in `live()` and handed to the
/// adapter as an immutable snapshot, because `NSScreen` must not be read off the
/// main thread while the adapter runs on background work.
public struct ScreenDisplayIndexResolver: WorkspaceDisplayIndexResolving {
    private let indexByDisplayID: [Int: Int]

    /// `displayIDs` is in `NSScreen.screens` order; `nil` entries are skipped.
    public init(displayIDs: [Int?]) {
        var map: [Int: Int] = [:]
        for (position, displayID) in displayIDs.enumerated() {
            guard let displayID else { continue }
            map[displayID] = position + 1
        }
        self.indexByDisplayID = map
    }

    public func screenIndex(forDisplayIdentifier identifier: Int) -> Int? {
        indexByDisplayID[identifier]
    }

    /// Capture the current displays. Must run on the main actor.
    @MainActor
    public static func live() -> ScreenDisplayIndexResolver {
        ScreenDisplayIndexResolver(displayIDs: NSScreen.screens.map { screen in
            NSScreenGeometryProvider.displayID(of: screen).map { Int($0.rawValue) }
        })
    }
}
