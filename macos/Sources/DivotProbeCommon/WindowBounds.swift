import Foundation
import CoreGraphics
import AppKit

public struct ProbeConfig {
    public let watchMode: Bool
    public let watchDuration: TimeInterval

    public init(watchMode: Bool = false, watchDuration: TimeInterval = 15) {
        self.watchMode = watchMode
        self.watchDuration = watchDuration
    }
}

/// Parse command-line arguments for the notification banner probe.
/// Recognizes: --watch [seconds] to enable watch mode with optional duration (default 15 seconds)
public func parseProbeArguments(_ arguments: [String]) -> ProbeConfig {
    var watchMode = false
    var watchDuration: TimeInterval = 15

    if arguments.count > 1 {
        for i in 1..<arguments.count {
            if arguments[i] == "--watch" {
                watchMode = true
                if i + 1 < arguments.count, let duration = TimeInterval(arguments[i + 1]) {
                    watchDuration = duration
                }
                break
            }
        }
    }

    return ProbeConfig(watchMode: watchMode, watchDuration: watchDuration)
}

/// Parse window layer from CGWindowListCopyWindowInfo dictionary.
/// The dictionary contains the layer as NSNumber under kCGWindowLayer.
public func parseWindowLayerFromDict(_ dict: [String: Any]) -> Int {
    return (dict["kCGWindowLayer"] as? NSNumber)?.intValue ?? 0
}

/// Parse CGRect from CGWindowListCopyWindowInfo bounds dictionary.
/// The dictionary contains X/Y/Width/Height as NSNumber values.
public func parseBoundsFromWindowDict(_ dict: [String: Any]) -> CGRect {
    if let boundsDict = dict["kCGWindowBounds"] as? NSDictionary {
        let x = (boundsDict["X"] as? NSNumber)?.doubleValue ?? 0
        let y = (boundsDict["Y"] as? NSNumber)?.doubleValue ?? 0
        let width = (boundsDict["Width"] as? NSNumber)?.doubleValue ?? 0
        let height = (boundsDict["Height"] as? NSNumber)?.doubleValue ?? 0
        return CGRect(x: x, y: y, width: width, height: height)
    }
    return .zero
}

/// Convert Core Graphics coordinates (origin at top-left of primary display)
/// to AppKit coordinates (origin at bottom-left of primary display).
public func flipBoundsToAppKit(_ cgBounds: CGRect, screenHeight: CGFloat) -> CGRect {
    return CGRect(
        x: cgBounds.minX,
        y: screenHeight - cgBounds.maxY,
        width: cgBounds.width,
        height: cgBounds.height
    )
}

/// Identifies the type of window based on owner name and bundle ID.
public enum WindowType {
    case notificationBanner
    case controlCenter
    case divot
    case other
}

/// Determine window type based on owner name (case-insensitive, with space normalization)
/// and bundle ID via PID lookup.
public func classifyWindow(_ windowDict: [String: Any]) -> WindowType {
    let owner = (windowDict["kCGWindowOwnerName"] as? String ?? "").lowercased()
    let normalizedOwner = owner.replacingOccurrences(of: " ", with: "")

    if normalizedOwner.contains("divot") {
        return .divot
    }

    if normalizedOwner.contains("notificationcenter") {
        return .notificationBanner
    }

    if normalizedOwner.contains("controlcenter") {
        return .controlCenter
    }

    if let pid = (windowDict["kCGWindowOwnerPID"] as? NSNumber)?.intValue {
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            if let bundleID = app.bundleIdentifier {
                if bundleID == "com.apple.notificationcenterui" {
                    return .notificationBanner
                }
                if bundleID == "com.apple.controlcenter" {
                    return .controlCenter
                }
            }
        }
    }

    return .other
}

/// A snapshot of a single window's key properties for diffing.
public struct WindowSnapshot: Hashable {
    public let windowID: CGWindowID
    public let layer: Int
    public let bounds: CGRect

    public init(windowID: CGWindowID, layer: Int, bounds: CGRect) {
        self.windowID = windowID
        self.layer = layer
        self.bounds = bounds
    }

    /// Create a snapshot from a window dictionary.
    public static func from(_ windowDict: [String: Any]) -> WindowSnapshot? {
        guard let windowID = (windowDict["kCGWindowNumber"] as? NSNumber)?.uint32Value else {
            return nil
        }
        let layer = parseWindowLayerFromDict(windowDict)
        let bounds = parseBoundsFromWindowDict(windowDict)
        return WindowSnapshot(windowID: CGWindowID(windowID), layer: layer, bounds: bounds)
    }
}

/// Track windows that changed between two snapshots.
public struct WindowChanges {
    public let new: [CGWindowID]
    public let boundsChanged: [CGWindowID]
    public let layerChanged: [CGWindowID]

    public init(new: [CGWindowID] = [], boundsChanged: [CGWindowID] = [], layerChanged: [CGWindowID] = []) {
        self.new = new
        self.boundsChanged = boundsChanged
        self.layerChanged = layerChanged
    }
}

/// Diff two window snapshots and return windows that are new or changed.
public func diffWindowSnapshots(previous: [WindowSnapshot], current: [WindowSnapshot]) -> WindowChanges {
    let previousMap = Dictionary(uniqueKeysWithValues: previous.map { ($0.windowID, $0) })

    var newWindows: [CGWindowID] = []
    var boundsChanged: [CGWindowID] = []
    var layerChanged: [CGWindowID] = []

    for currentWindow in current {
        if let previousWindow = previousMap[currentWindow.windowID] {
            if previousWindow.bounds != currentWindow.bounds {
                boundsChanged.append(currentWindow.windowID)
            }
            if previousWindow.layer != currentWindow.layer {
                layerChanged.append(currentWindow.windowID)
            }
        } else {
            newWindows.append(currentWindow.windowID)
        }
    }

    return WindowChanges(new: newWindows, boundsChanged: boundsChanged, layerChanged: layerChanged)
}

/// Find the Divot bar panel window(s) in the window list.
/// Returns the window with bounds at the top edge and owner containing 'Divot'.
/// Heuristic: Divot panel should have minY < 50 (allowing for typical bar height ~33 points).
/// Note: On secondary displays or unusual bar placements, this heuristic may miss Divot;
/// adjust the threshold if needed for your configuration.
public func findDivotPanelWindow(_ windowList: [[String: Any]]) -> [String: Any]? {
    return windowList.first { window in
        let owner = (window["kCGWindowOwnerName"] as? String ?? "").lowercased()
        guard owner.contains("divot") else { return false }

        let bounds = parseBoundsFromWindowDict(window)
        return bounds.minY < 50
    }
}
