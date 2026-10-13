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
        let config = parseProbeArguments(CommandLine.arguments)

        if config.watchMode {
            watchForNotificationWindows(duration: config.watchDuration)
            return
        }

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
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0

        let interesting = windowList.filter { window in
            let layer = parseWindowLayerFromDict(window)
            let owner = window["kCGWindowOwnerName"] as? String ?? ""

            return owner.contains("NotificationCenter") ||
                   owner.contains("Divot") ||
                   owner.contains("Finder") ||
                   owner.contains("System") ||
                   layer >= 20 ||
                   owner == "Dock"
        }

        let sorted = interesting.sorted { a, b in
            let layerA = parseWindowLayerFromDict(a)
            let layerB = parseWindowLayerFromDict(b)
            return layerA > layerB
        }

        print("Interesting windows (sorted by layer, highest first):")
        for window in sorted {
            let layer = parseWindowLayerFromDict(window)
            let owner = window["kCGWindowOwnerName"] as? String ?? "?"
            let name = window["kCGWindowName"] as? String ?? "(no name)"
            let cgBounds = parseBoundsFromWindowDict(window)
            let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)
            let y = Int(appKitBounds.minY)
            let height = Int(appKitBounds.height)

            print("  layer=\(layer) owner=\(owner) name=\(name) frame=(appKit y=\(y), h=\(height))")
        }
    }

    static func reportFindings() {
        print("\n## Findings")

        let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let divotPanelLevel = Int(NSWindow.Level.mainMenu.rawValue) - 1

        let notificationWindows = windowList.filter { window in
            let owner = window["kCGWindowOwnerName"] as? String ?? ""
            return owner.contains("NotificationCenter")
        }

        if notificationWindows.isEmpty {
            print("No NotificationCenter windows found (none are currently visible)")
            print("To see notification banner window layers:")
            print("  1. Trigger a notification (e.g., from Calendar, Mail, or use 'say' command)")
            print("  2. Re-run this probe while the banner is visible")
        } else {
            print("Found \(notificationWindows.count) NotificationCenter window(s)")

            var minLayer = Int.max
            var maxLayer = Int.min
            for window in notificationWindows {
                let layer = parseWindowLayerFromDict(window)
                minLayer = min(minLayer, layer)
                maxLayer = max(maxLayer, layer)

                let cgBounds = parseBoundsFromWindowDict(window)
                let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)
                let name = window["kCGWindowName"] as? String ?? "(no name)"
                print("  layer=\(layer) name=\(name) frame (AppKit coords)=(\(Int(appKitBounds.minX)), \(Int(appKitBounds.minY)), \(Int(appKitBounds.width)), \(Int(appKitBounds.height)))")
            }

            print("\nBanner window layer range: \(minLayer)...\(maxLayer)")

            print("\n## Comparison with Standard macOS Layers")
            print("  mainMenu (native menu bar) = \(Int(NSWindow.Level.mainMenu.rawValue))")
            print("  Divot bar current layer = \(divotPanelLevel)")
            print("  status (status windows) = 25")
            print("  floating (floating panels) = 3")

            if minLayer > Int(NSWindow.Level.mainMenu.rawValue) {
                print("\nFinding: Notification banners are ABOVE the menu bar layer (\(minLayer) > \(Int(NSWindow.Level.mainMenu.rawValue)))")
                print("  This means banners are above Divot's current layer (\(divotPanelLevel))")
            } else if minLayer == Int(NSWindow.Level.mainMenu.rawValue) {
                print("\nFinding: Notification banners are AT the menu bar layer (\(minLayer) == \(Int(NSWindow.Level.mainMenu.rawValue)))")
                print("  This means banners are above Divot's current layer by 1 point")
            } else if minLayer == divotPanelLevel {
                print("\nFinding: Notification banners are AT Divot's current layer (\(minLayer) == \(divotPanelLevel))")
                print("  This explains the overlap issue")
            } else {
                print("\nFinding: Notification banners are below the menu bar layer (\(minLayer) < \(Int(NSWindow.Level.mainMenu.rawValue)))")
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

    static func watchForNotificationWindows(duration: TimeInterval) {
        print("# divot notification-banner probe --watch")
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("os=\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        print("Watching for NotificationCenter windows for \(Int(duration)) seconds...")

        let divotPanelLevel = Int(NSWindow.Level.mainMenu.rawValue) - 1
        print("Divot panel layer for comparison: \(divotPanelLevel)")
        print("")

        let startTime = Date()
        let pollInterval: TimeInterval = 0.5
        var lastNotificationCount = 0

        while Date().timeIntervalSince(startTime) < duration {
            let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
            let screenHeight = NSScreen.screens.first?.frame.height ?? 0

            let notificationWindows = windowList.filter { window in
                let owner = window["kCGWindowOwnerName"] as? String ?? ""
                return owner.contains("NotificationCenter")
            }

            if !notificationWindows.isEmpty && notificationWindows.count != lastNotificationCount {
                let timestamp = Date().formatted(date: .omitted, time: .standard)
                print("[\(timestamp)] Found \(notificationWindows.count) NotificationCenter window(s):")

                let sorted = notificationWindows.sorted { a, b in
                    let layerA = parseWindowLayerFromDict(a)
                    let layerB = parseWindowLayerFromDict(b)
                    return layerA > layerB
                }

                for window in sorted {
                    let layer = parseWindowLayerFromDict(window)
                    let name = window["kCGWindowName"] as? String ?? "(no name)"
                    let cgBounds = parseBoundsFromWindowDict(window)
                    let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)
                    let y = Int(appKitBounds.minY)
                    let height = Int(appKitBounds.height)
                    print("  layer=\(layer) (Divot is at \(divotPanelLevel)) name=\(name) frame=(appKit y=\(y), h=\(height))")
                }
                print("")

                lastNotificationCount = notificationWindows.count
            }

            Thread.sleep(forTimeInterval: pollInterval)
        }

        if lastNotificationCount == 0 {
            print("No NotificationCenter windows observed during watch period")
        } else {
            print("Watch period ended")
        }
    }
}
