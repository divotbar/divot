import AppKit
import DivotCore

/// Reads the platform's current displays as pure geometry readings.
///
/// This is the only place that touches `NSScreen`; everything that decides
/// placement lives in `DivotCore` and is testable without a window server.
@MainActor
public protocol ScreenGeometryProviding {
    func screens() -> [ScreenGeometryReading]
}

/// Live `NSScreen` implementation.
///
/// Display identity comes from the `NSScreenNumber` device description, so it
/// is stable across reconfiguration rather than a transient array index.
@MainActor
public struct NSScreenGeometryProvider: ScreenGeometryProviding {
    public init() {}

    public func screens() -> [ScreenGeometryReading] {
        NSScreen.screens.compactMap { screen in
            guard let id = Self.displayID(of: screen) else { return nil }
            return ScreenGeometryReading(id: id, geometry: Self.geometry(of: screen))
        }
    }

    /// The display identity used by the coordinator. Exposed so tests and tools
    /// can build readings that match live screens.
    public static func displayID(of screen: NSScreen) -> DisplayBarID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return DisplayBarID(number.uint32Value)
    }

    /// A pure snapshot of one screen's public geometry.
    public static func geometry(of screen: NSScreen) -> ScreenGeometry {
        ScreenGeometry(frame: screen.frame,
                       visibleFrame: screen.visibleFrame,
                       safeAreaTop: screen.safeAreaInsets.top,
                       auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                       auxiliaryTopRight: screen.auxiliaryTopRightArea,
                       backingScaleFactor: screen.backingScaleFactor)
    }
}
