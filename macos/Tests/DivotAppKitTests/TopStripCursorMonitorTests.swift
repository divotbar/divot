import CoreGraphics
import Testing
import DivotCore
@testable import DivotAppKit

/// A stub geometry provider so the monitor's tracking loop is exercised without
/// a window server.
@MainActor
private struct ScreenStub: ScreenGeometryProviding {
    let readings: [ScreenGeometryReading]
    func screens() -> [ScreenGeometryReading] { readings }
}

private func display(id: UInt32, frame: CGRect) -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(id),
                          geometry: ScreenGeometry(frame: frame, visibleFrame: frame, safeAreaTop: 0))
}

/// Drives the monitor with a mutable pointer position and no real event
/// monitors, proving the enter/leave loop reports only on a boundary crossing.
@MainActor
@Test func monitorReportsWhenThePointerCrossesIntoTheTopStrip() {
    let screen = display(id: 1, frame: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    var location = CGPoint(x: 100, y: 500)
    let monitor = TopStripCursorMonitor(provider: ScreenStub(readings: [screen]),
                                        stripHeight: 4,
                                        pointerLocation: { location },
                                        installsEventMonitors: false)
    var changes: [Set<DisplayBarID>] = []
    monitor.onChange = { changes.append($0) }

    monitor.start()
    // The pointer started away from the strip: one empty initial report.
    #expect(changes == [[]])
    #expect(monitor.isRunning)
    #expect(!monitor.globalMonitorInstalled)

    // Move into the strip: one engaged report.
    location = CGPoint(x: 100, y: 999)
    monitor.samplePointer()
    #expect(changes.last == [DisplayBarID(1)])

    // Movement that stays inside the strip must not report again.
    location = CGPoint(x: 120, y: 1000)
    monitor.samplePointer()
    #expect(changes.count == 2)

    // Leave: one empty report.
    location = CGPoint(x: 100, y: 500)
    monitor.samplePointer()
    #expect(changes.last == [])
    #expect(changes.count == 3)

    monitor.stop()
    #expect(!monitor.isRunning)
}

/// The initial report reflects the pointer's position at start, so a launch with
/// the pointer already at the top edge engages immediately.
@MainActor
@Test func monitorReportsAnInitialEngagementWhenThePointerStartsInTheStrip() {
    let screen = display(id: 1, frame: CGRect(x: 0, y: 0, width: 1600, height: 1000))
    let monitor = TopStripCursorMonitor(provider: ScreenStub(readings: [screen]),
                                        stripHeight: 4,
                                        pointerLocation: { CGPoint(x: 100, y: 1000) },
                                        installsEventMonitors: false)
    var changes: [Set<DisplayBarID>] = []
    monitor.onChange = { changes.append($0) }

    monitor.start()
    #expect(changes == [[DisplayBarID(1)]])
    monitor.stop()
}
