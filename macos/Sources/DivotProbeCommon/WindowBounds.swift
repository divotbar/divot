import Foundation
import CoreGraphics

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
