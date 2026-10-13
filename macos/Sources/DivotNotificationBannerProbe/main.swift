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

    struct HighestLayerWindow: Hashable {
        let owner: String
        let name: String
        let layer: Int
    }

    static func watchForNotificationWindows(duration: TimeInterval) {
        print("# divot notification-banner probe --watch")
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("os=\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        print("Watching all windows for \(Int(duration)) seconds, polling twice per second...")
        print("")

        let startTime = Date()
        let pollInterval: TimeInterval = 0.5
        var previousSnapshots: [WindowSnapshot] = []
        var highestLayers: [HighestLayerWindow] = []
        var finalWindowList: [[String: Any]] = []
        var isFirstPoll = true

        while Date().timeIntervalSince(startTime) < duration {
            let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
            let screenHeight = NSScreen.screens.first?.frame.height ?? 0
            finalWindowList = windowList

            let currentSnapshots = windowList.compactMap { WindowSnapshot.from($0) }
            let changes = diffWindowSnapshots(previous: previousSnapshots, current: currentSnapshots)

            let divotPanel = findDivotPanelWindow(windowList)
            let divotLayer = divotPanel.map { parseWindowLayerFromDict($0) }
            let divotBounds = divotPanel.map { parseBoundsFromWindowDict($0) }

            let allChangedWindowIDs = Set(changes.new + changes.boundsChanged + changes.layerChanged)

            if !isFirstPoll {
                for windowID in allChangedWindowIDs.sorted() {
                if let windowDict = windowList.first(where: { (($0["kCGWindowNumber"] as? NSNumber)?.uint32Value).map { CGWindowID($0) } == windowID }) {
                    let timestamp = Date().formatted(date: .omitted, time: .standard)
                    let owner = windowDict["kCGWindowOwnerName"] as? String ?? "?"
                    let pid = (windowDict["kCGWindowOwnerPID"] as? NSNumber)?.intValue ?? 0
                    let name = windowDict["kCGWindowName"] as? String ?? "(no name)"
                    let layer = parseWindowLayerFromDict(windowDict)
                    let cgBounds = parseBoundsFromWindowDict(windowDict)
                    let appKitBounds = flipBoundsToAppKit(cgBounds, screenHeight: screenHeight)
                    let alpha = (windowDict["kCGWindowAlpha"] as? NSNumber)?.floatValue ?? 1.0
                    let isOnScreen = (windowDict["kCGWindowIsOnscreen"] as? NSNumber)?.boolValue ?? false

                    let windowType = classifyWindow(windowDict)
                    let typeLabel = windowType == .notificationBanner ? " [NotificationCenter banner]" :
                                    windowType == .controlCenter ? " [ControlCenter]" :
                                    windowType == .divot ? " [Divot panel]" : ""

                    print("[\(timestamp)] window-\(windowID)\(typeLabel)")
                    print("  owner=\(owner) pid=\(pid)")
                    print("  name=\(name)")
                    print("  layer=\(layer) CG-bounds=(\(Int(cgBounds.minX)), \(Int(cgBounds.minY)), \(Int(cgBounds.width)), \(Int(cgBounds.height)))")
                    print("  AppKit-bounds=(\(Int(appKitBounds.minX)), \(Int(appKitBounds.minY)), \(Int(appKitBounds.width)), \(Int(appKitBounds.height)))")
                    print("  alpha=\(String(format: "%.2f", alpha)) on-screen=\(isOnScreen)")

                    if let divotL = divotLayer, let divotB = divotBounds {
                        let divotTypeLabel = classifyWindow(divotPanel!) == .divot ? "Divot panel" : "reference"
                        if layer > divotL {
                            print("  ↑ Window layer \(layer) is ABOVE \(divotTypeLabel) layer \(divotL) at CG y=\(Int(divotB.minY))")
                        } else if layer < divotL {
                            print("  ↓ Window layer \(layer) is below \(divotTypeLabel) layer \(divotL) at CG y=\(Int(divotB.minY))")
                        } else {
                            print("  = Window layer \(layer) is AT \(divotTypeLabel) layer \(divotL) at CG y=\(Int(divotB.minY))")
                        }
                    } else if let divotL = divotLayer {
                        if layer > divotL {
                            print("  ↑ Window layer \(layer) is ABOVE Divot panel layer \(divotL)")
                        } else if layer < divotL {
                            print("  ↓ Window layer \(layer) is below Divot panel layer \(divotL)")
                        } else {
                            print("  = Window layer \(layer) is AT Divot panel layer \(divotL)")
                        }
                    }

                    if isOnScreen && layer > 0 {
                        highestLayers.append(HighestLayerWindow(owner: owner, name: name, layer: layer))
                        highestLayers.sort { $0.layer > $1.layer }
                        if highestLayers.count > 10 {
                            highestLayers.removeLast()
                        }
                    }

                    print("")
                }
                }
            }

            previousSnapshots = currentSnapshots
            isFirstPoll = false
            Thread.sleep(forTimeInterval: pollInterval)
        }

        print("## Summary")
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        if let divotPanel = findDivotPanelWindow(finalWindowList) {
            let divotL = parseWindowLayerFromDict(divotPanel)
            let divotB = parseBoundsFromWindowDict(divotPanel)
            let appKitDivotB = flipBoundsToAppKit(divotB, screenHeight: screenHeight)
            print("Divot panel layer (measured): \(divotL)")
            print("  CG-bounds: (\(Int(divotB.minX)), \(Int(divotB.minY)), \(Int(divotB.width)), \(Int(divotB.height)))")
            print("  AppKit-bounds: (\(Int(appKitDivotB.minX)), \(Int(appKitDivotB.minY)), \(Int(appKitDivotB.width)), \(Int(appKitDivotB.height)))")
        } else {
            print("Note: No Divot panel window found in this run")
        }

        if highestLayers.isEmpty {
            print("\nNo windows with property changes were detected during the watch period")
            print("(Static windows and initial poll are not printed; see banner or Control Center for reference overlays)")
        } else {
            print("\nHighest-layer windows that changed during the watch period:")
            var seenKeys: [(String, String)] = []
            var count = 0
            for window in highestLayers {
                let key = (window.owner, window.name)
                if !seenKeys.contains(where: { $0 == key }) {
                    count += 1
                    print("  \(count). \(window.owner) · \(window.name) (layer \(window.layer))")
                    seenKeys.append(key)
                    if count >= 5 {
                        break
                    }
                }
            }
        }
    }
}
