import Foundation
import CoreGraphics

/// Geometry only. NSScreen reads and panel mutations belong to the AppKit adapter.
///
/// Two placements are produced:
/// - **Top edge** (`nativeMenuBarInset == 0`): the bar hugs the screen top and,
///   on notched displays, splits around the camera housing using the auxiliary
///   top areas so no hit region crosses the notch.
/// - **Below the native bar** (`nativeMenuBarInset > 0`): the bar moves down by
///   the inset and spans the full width. The notch gap is deliberately *not*
///   carried into the inset row, because the housing is now above the bar and a
///   middle gap there would be an unusable hole.
public struct BarGeometry: Equatable, Sendable {
    public let left: CGRect
    public let right: CGRect

    public init(screen: CGRect, topLeft: CGRect? = nil, topRight: CGRect? = nil,
                height: CGFloat = 32, gap: CGFloat = 10, nativeMenuBarInset: CGFloat = 0) {
        let requestedHeight = max(0, height.isFinite ? height : 32)
        let clearance = max(0, gap.isFinite ? gap : 10)
        let requestedInset = max(0, nativeMenuBarInset.isFinite ? nativeMenuBarInset : 0)
        // Never push the bar off the bottom of the display.
        let inset = min(requestedInset, max(0, screen.height))
        let h = min(requestedHeight, max(0, screen.height - inset))
        let top = screen.maxY - inset

        // Both auxiliary regions must exist and intersect the screen. A single
        // missing region is treated as a notch-free fallback, never half a bar.
        // Below-bar placement ignores them so the notch gap does not leak in.
        if inset == 0,
           let tl = topLeft, let tr = topRight,
           !tl.intersection(screen).isEmpty, !tr.intersection(screen).isEmpty,
           tl.maxX <= tr.minX {
            let l = tl.intersection(screen)
            let r = tr.intersection(screen)
            let lh = min(h, l.height)
            let rh = min(h, r.height)
            left = CGRect(x: l.minX, y: l.maxY - lh,
                          width: max(0, l.width - clearance), height: lh)
            let rg = min(clearance, r.width)
            right = CGRect(x: r.minX + rg, y: r.maxY - rh,
                           width: max(0, r.width - rg), height: rh)
        } else {
            let width = max(0, screen.width)
            let middleGap = min(clearance * 2, width)
            let half = (width - middleGap) / 2
            left = CGRect(x: screen.minX, y: top - h, width: half, height: h)
            right = CGRect(x: screen.maxX - half, y: top - h, width: half, height: h)
        }
    }
}
