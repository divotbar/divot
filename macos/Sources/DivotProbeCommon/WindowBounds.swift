import Foundation
import CoreGraphics

/// Parse window level from CGWindowListCopyWindowInfo dictionary.
/// The dictionary contains the level as NSNumber.
public func parseWindowLevelFromDict(_ dict: [String: Any]) -> Int {
    return (dict["kCGWindowLevel"] as? NSNumber)?.intValue ?? 0
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
