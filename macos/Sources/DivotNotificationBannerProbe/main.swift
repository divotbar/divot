import AppKit
import ApplicationServices
import CoreGraphics
import DivotProbeCommon

/// A read-only probe for task 0075: investigate macOS notification banner
/// window levels and ordering relative to the Divot bar.
///
/// Reports what public AppKit/CoreGraphics APIs reveal about:
/// - Window levels of all windows on screen
/// - Identification of NotificationCenter banner windows
/// - Comparison with current Divot panel configuration
/// - Position of banners relative to the menu bar height
///
/// Run with `swift build --package-path macos && macos/.build/debug/divot-notification-banner-probe`
@main
struct NotificationBannerProbe {
    static func main() {
        print("# divot notification-banner probe")
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("os=\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

        reportSystemState()
        reportAllWindows()
        reportFindings()
    }

    static func reportSystemState() {
        print("\n## System State")

        let screens = NSScreen.screens
        print("displays=\(screens.count)")
        for (i, screen) in screens.enumerated() {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let safeArea = screen.safeAreaInsets
            print("  display[\(i)] frame=(\(Int(frame.minX)), \(Int(frame.minY)), \(Int(frame.width)), \(Int(frame.height))) visible=(\(Int(visibleFrame.minX)), \(Int(visibleFrame.minY)), \(Int(visibleFrame.width)), \(Int(visibleFrame.height))) safeArea.top=\(Int(safeArea.top))")
        }

        if let screen = NSScreen.main {
            let topDelta = screen.frame.maxY - screen.visibleFrame.maxY
            print("menu_bar_estimated_height=\(Int(topDelta)) (frame.maxY - visibleFrame.maxY)")
        }
    }

    static func reportAllWindows() {
        print("\n## All Windows")

        let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []

        let interesting = windowList.filter { window in
            let level = window["kCGWindowLevel"] as? Int ?? 0
            let owner = window["kCGWindowOwnerName"] as? String ?? ""

            return owner.contains("NotificationCenter") ||
                   owner.contains("Divot") ||
                   owner.contains("Finder") ||
                   owner.contains("System") ||
                   level >= 20 ||
                   owner == "Dock"
        }

        let sorted = interesting.sorted { a, b in
            let levelA = a["kCGWindowLevel"] as? Int ?? 0
            let levelB = b["kCGWindowLevel"] as? Int ?? 0
            return levelA > levelB
        }

        print("Interesting windows (sorted by level, highest first):")
        for window in sorted {
            let level = window["kCGWindowLevel"] as? Int ?? 0
            let owner = window["kCGWindowOwnerName"] as? String ?? "?"
            let name = window["kCGWindowName"] as? String ?? "(no name)"
            let bounds = parseBoundsFromWindowDict(window)
            let y = Int(bounds.minY)
            let height = Int(bounds.height)

            print("  level=\(level) owner=\(owner) name=\(name) frame=(y=\(y), h=\(height))")
        }
    }

    static func reportFindings() {
        print("\n## Findings")

        let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []

        let notificationWindows = windowList.filter { window in
            let owner = window["kCGWindowOwnerName"] as? String ?? ""
            return owner.contains("NotificationCenter")
        }

        if notificationWindows.isEmpty {
            print("No NotificationCenter windows found (none are currently visible)")
            print("To see notification banner window levels:")
            print("  1. Trigger a notification (e.g., from Calendar, Mail, or use 'say' command)")
            print("  2. Re-run this probe while the banner is visible")
        } else {
            print("Found \(notificationWindows.count) NotificationCenter window(s)")

            var minLevel = Int.max
            var maxLevel = Int.min
            for window in notificationWindows {
                let level = window["kCGWindowLevel"] as? Int ?? 0
                minLevel = min(minLevel, level)
                maxLevel = max(maxLevel, level)

                let bounds = parseBoundsFromWindowDict(window)
                let name = window["kCGWindowName"] as? String ?? "(no name)"
                print("  level=\(level) name=\(name) frame=(\(Int(bounds.minX)), \(Int(bounds.minY)), \(Int(bounds.width)), \(Int(bounds.height)))")
            }

            print("\nBanner window level range: \(minLevel)...\(maxLevel)")

            print("\n## Comparison with Standard macOS Levels")
            print("  mainMenu (native menu bar) = \(Int(NSWindow.Level.mainMenu.rawValue))")
            print("  Divot bar current level = \(Int(NSWindow.Level.mainMenu.rawValue) - 1)")
            print("  status (status windows) = 25")
            print("  floating (floating panels) = 3")

            if minLevel > Int(NSWindow.Level.mainMenu.rawValue) {
                print("\nFinding: Notification banners are ABOVE the menu bar level (\(minLevel) > \(Int(NSWindow.Level.mainMenu.rawValue)))")
                print("  This means banners are above Divot's current level (\(Int(NSWindow.Level.mainMenu.rawValue) - 1))")
            } else if minLevel == Int(NSWindow.Level.mainMenu.rawValue) {
                print("\nFinding: Notification banners are AT the menu bar level (\(minLevel) == \(Int(NSWindow.Level.mainMenu.rawValue)))")
                print("  This means banners are above Divot's current level by 1 point")
            } else if minLevel == Int(NSWindow.Level.mainMenu.rawValue) - 1 {
                print("\nFinding: Notification banners are AT Divot's current level (\(minLevel) == \(Int(NSWindow.Level.mainMenu.rawValue) - 1))")
                print("  This explains the overlap issue")
            } else {
                print("\nFinding: Notification banners are below the menu bar level (\(minLevel) < \(Int(NSWindow.Level.mainMenu.rawValue)))")
            }
        }

        print("\n## Menu Bar State")
        if let screen = NSScreen.main {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let topDelta = frame.maxY - visibleFrame.maxY
            print("visible_frame_delta=\(Int(topDelta)) (suggests menu bar height when native bar is hidden)")
            if topDelta > 0 {
                print("  Native menu bar area is excluded from visibleFrame by \(Int(topDelta)) points")
                print("  On notched displays, this includes the camera housing")
            }
        }
    }
}
