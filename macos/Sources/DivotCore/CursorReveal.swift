import Foundation
import CoreGraphics

/// Pure geometry for the cursor reveal.
///
/// Moving the pointer into the top strip of a display is the direct observation
/// behind the "move below the menu bar when it appears" setting (#0023). This
/// type only maps a pointer position to the displays whose top strip it is in;
/// the platform event monitor lives in `DivotAppKit` and the visibility
/// decision lives in `NativeMenuBarDetector`, so the routing rule is testable
/// without a window server.
public enum CursorMenuBarReveal {
    /// Height of the reveal strip at the top of a display, in points. Native
    /// macOS reveals the menu bar when the pointer reaches the very top edge;
    /// a few points keeps that forgiving of rounding without treating a normal
    /// window title bar as the reveal zone.
    public static let defaultStripHeight: CGFloat = 4

    /// True when `mouseY` is within `stripHeight` of `screenFrame`'s top edge.
    ///
    /// Both the pointer and `NSScreen.frame` use the global, bottom-left-origin
    /// display space, so the top edge is `maxY`.
    public static func isInTopStrip(mouseY: CGFloat,
                                    screenFrame: CGRect,
                                    stripHeight: CGFloat = defaultStripHeight) -> Bool {
        guard mouseY.isFinite, screenFrame.height > 0 else { return false }
        let height = max(0, stripHeight.isFinite ? stripHeight : defaultStripHeight)
        return mouseY >= screenFrame.maxY - height && mouseY <= screenFrame.maxY
    }

    /// The displays whose top strip currently contains the pointer. Usually one
    /// or none; an overlapping window-server layout can never produce two,
    /// because display frames do not overlap.
    public static func engagedDisplayIDs(mouseLocation: CGPoint,
                                         displays: [ScreenGeometryReading],
                                         stripHeight: CGFloat = defaultStripHeight) -> Set<DisplayBarID> {
        guard mouseLocation.x.isFinite, mouseLocation.y.isFinite else { return [] }
        var engaged: Set<DisplayBarID> = []
        for display in displays {
            let frame = display.geometry.frame
            guard mouseLocation.x >= frame.minX, mouseLocation.x <= frame.maxX else { continue }
            if isInTopStrip(mouseY: mouseLocation.y, screenFrame: frame, stripHeight: stripHeight) {
                engaged.insert(display.id)
            }
        }
        return engaged
    }
}
