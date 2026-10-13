import Foundation
import CoreGraphics

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
