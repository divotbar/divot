import Foundation
import CoreGraphics

/// Geometry only. NSScreen reads and panel mutations belong to the AppKit adapter.
///
/// Two placements are produced:
/// - **Top edge** (`nativeMenuBarInset == 0`): the bar hugs the screen top and,
///   on notched displays, splits around the camera housing using the auxiliary
///   top areas so no hit region crosses the notch.
/// - **Below the native bar** (`nativeMenuBarInset > 0`): the bar moves down by
///   the inset and spans the width minus `edgeMargin`. The notch gap is
///   deliberately *not* carried into the inset row, because the housing is now
///   above the bar and a middle gap there would be an unusable hole. `edgeMargin`
///   is the explicit window-manager gap policy knob for that row.
public struct BarGeometry: Equatable, Sendable {
    public let left: CGRect
    public let right: CGRect
    /// True only when the two segments are split around a camera housing: the
    /// bar hugs the display's auxiliary top areas with a real hole between them.
    ///
    /// The panels read this to extend the bar colour a few points into the
    /// housing so its rounded corners are covered (#0028). It is decided here,
    /// from the same auxiliary regions that produced the split, and never
    /// inferred later from "the segments happen to have a gap" — a notch-free
    /// top-edge layout with a centre seam must not be treated as a notch.
    public let hasNotch: Bool

    public init(screen: CGRect, topLeft: CGRect? = nil, topRight: CGRect? = nil,
                height: CGFloat = BarMetrics.default.height, gap: CGFloat = 0,
                nativeMenuBarInset: CGFloat = 0, edgeMargin: CGFloat = 0) {
        let fallbackHeight = BarMetrics.default.height
        let requestedHeight = max(0, height.isFinite ? height : fallbackHeight)
        let clearance = max(0, gap.isFinite ? gap : 0)
        let requestedInset = max(0, nativeMenuBarInset.isFinite ? nativeMenuBarInset : 0)
        let requestedMargin = max(0, edgeMargin.isFinite ? edgeMargin : 0)
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
            // A real housing means the two auxiliary regions are separated by a
            // hole, not merely adjacent. A degenerate split with no hole is not
            // a notch and must not extend the bar.
            hasNotch = l.maxX < r.minX
        } else {
            let width = max(0, screen.width)
            // `edgeMargin` is the explicit window-manager gap policy knob for the
            // below-bar row: zero overlays edge to edge, a positive value insets
            // both segments from the physical screen edges. It never applies to
            // the notch-aware top-edge split, which hugs the auxiliary regions.
            let margin = min(requestedMargin, width / 2)
            let usableWidth = max(0, width - margin * 2)
            let middleGap = min(clearance * 2, usableWidth)
            let half = (usableWidth - middleGap) / 2
            left = CGRect(x: screen.minX + margin, y: top - h, width: half, height: h)
            right = CGRect(x: screen.maxX - margin - half, y: top - h, width: half, height: h)
            // The fallback row (notch-free top edge, or any below-bar row) never
            // runs alongside a camera housing, so it never extends.
            hasNotch = false
        }
    }
}
