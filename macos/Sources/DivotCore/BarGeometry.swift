import Foundation
import CoreGraphics

/// Geometry only. NSScreen reads and panel mutations belong to the AppKit adapter.
public struct BarGeometry: Equatable, Sendable {
    public let left: CGRect
    public let right: CGRect

    public init(screen: CGRect, topLeft: CGRect? = nil, topRight: CGRect? = nil,
                height: CGFloat = 32, gap: CGFloat = 10) {
        let requestedHeight = max(0, height.isFinite ? height : 32)
        let clearance = max(0, gap.isFinite ? gap : 10)
        let h = min(requestedHeight, max(0, screen.height))
        // Both auxiliary regions must exist and intersect the screen. A single
        // missing region is treated as a notch-free fallback, never half a bar.
        if let tl = topLeft, let tr = topRight,
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
            left = CGRect(x: screen.minX, y: screen.maxY - h, width: half, height: h)
            right = CGRect(x: screen.maxX - half, y: screen.maxY - h, width: half, height: h)
        }
    }
}
