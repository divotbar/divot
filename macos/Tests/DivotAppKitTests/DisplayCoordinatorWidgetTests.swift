import CoreGraphics
import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

/// A surface that records what the coordinator forwards to it.
@MainActor
private final class RecordingSurface: BarDisplaySurface {
    private(set) var changes: [WidgetChange] = []
    private(set) var updates: [DisplayBarUpdate] = []
    private(set) var didClose = false

    func apply(_ update: DisplayBarUpdate, reduceMotion: Bool) { updates.append(update) }
    func apply(widgetChanges: [WidgetChange]) { changes.append(contentsOf: widgetChanges) }
    func close() { didClose = true }
}

@MainActor
private struct ScreenStub: ScreenGeometryProviding {
    let readings: [ScreenGeometryReading]
    func screens() -> [ScreenGeometryReading] { readings }
}

private struct ProbeStub: SystemMenuBarProbing {
    func sample() -> SystemMenuBarState { .notTrusted }
}

/// Permission granted, but the sample is only provisional, so it carries no
/// decisive visibility. This models any transfer that has not been marked
/// `validated`; the coordinator must still place the panels.
private struct ProvisionalProbeStub: SystemMenuBarProbing {
    func sample() -> SystemMenuBarState { .provisional(visible: true, description: "notch fixture") }
}

/// A built-in notched display: the camera housing masks the whole top band.
private func notchedReading() -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(1),
                          geometry: ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                                                   visibleFrame: CGRect(x: 60, y: 0, width: 1650, height: 1074),
                                                   safeAreaTop: 33,
                                                   auxiliaryTopLeft: CGRect(x: 0, y: 1074, width: 763, height: 33),
                                                   auxiliaryTopRight: CGRect(x: 948, y: 1074, width: 762, height: 33)))
}

private func flatReading() -> ScreenGeometryReading {
    ScreenGeometryReading(id: DisplayBarID(1),
                          geometry: ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                                   visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                                   safeAreaTop: 0))
}

@MainActor
@Test func coordinatorForwardsWidgetRemovalSoTheBarClearsTheItem() {
    let adapter = MenuBarObservationAdapter(provider: ScreenStub(readings: [flatReading()]),
                                            probe: ProbeStub())
    let surface = RecordingSurface()
    let coordinator = DisplayCoordinator(adapter: adapter) { _, _, _ in surface }
    coordinator.start()

    let battery = WidgetState(id: .battery, revision: 1, content: .battery(.noBattery))
    coordinator.applyWidgetChanges([.update(battery)])
    #expect(surface.changes == [.update(battery)])

    // A provider stopped while its item stays in the layout must clear it,
    // not leave the last value on screen indefinitely.
    coordinator.applyWidgetChanges([.removed(.battery)])
    #expect(surface.changes == [.update(battery), .removed(.battery)])

    coordinator.stop()
}

@MainActor
@Test func aKeepAwakeOnlyChangeDoesNotRebuildSurfaces() {
    let adapter = MenuBarObservationAdapter(provider: ScreenStub(readings: [flatReading()]),
                                            probe: ProbeStub())
    var built = 0
    let surface = RecordingSurface()
    let coordinator = DisplayCoordinator(adapter: adapter) { _, _, _ in
        built += 1
        return surface
    }
    coordinator.start()
    #expect(built == 1)

    var updated = DivotConfiguration.default
    updated.keepAwake = KeepAwakeConfiguration(remember: true, isActive: true)
    coordinator.apply(configuration: updated)

    // Remembering the state is a runtime preference: the panels stay put, but
    // the coordinator still adopts the newest document.
    #expect(built == 1)
    #expect(!surface.didClose)
    #expect(coordinator.configuration.keepAwake.isActive)

    coordinator.stop()
}

@MainActor
@Test func applyingAConfigurationRebuildsSurfacesWithTheNewGroups() {
    let adapter = MenuBarObservationAdapter(provider: ScreenStub(readings: [flatReading()]),
                                            probe: ProbeStub())
    var built: [DivotConfiguration] = []
    var created: [RecordingSurface] = []
    let coordinator = DisplayCoordinator(adapter: adapter) { _, _, configuration in
        built.append(configuration)
        let surface = RecordingSurface()
        created.append(surface)
        return surface
    }
    coordinator.start()
    #expect(built.count == 1)

    var updated = DivotConfiguration.default
    updated.left = [.clock]
    updated.right = [.battery]
    updated.layout.height = 36
    coordinator.apply(configuration: updated)

    // The old panel is torn down and a fresh one is built from the new document.
    #expect(built.count == 2)
    #expect(built.last?.left == [.clock])
    #expect(built.last?.right == [.battery])
    #expect(created.first?.didClose == true)
    #expect(coordinator.configuration.layout.height == 36)

    coordinator.stop()
}

@MainActor
@Test func notchedDisplayWithGrantedAccessibilityAlwaysGetsAPlacement() {
    // Accessibility is granted, but the AX sample is provisional, so the
    // detector has no decisive visibility and returns indeterminate. The bar
    // must still be placed — at the top edge — rather than leaving the panels
    // at their initial 1x1 frame.
    let adapter = MenuBarObservationAdapter(provider: ScreenStub(readings: [notchedReading()]),
                                            probe: ProvisionalProbeStub())
    let surface = RecordingSurface()
    let coordinator = DisplayCoordinator(adapter: adapter) { _, _, _ in surface }
    coordinator.start()

    let placement = try! #require(surface.updates.first?.placement)
    #expect(placement.mode == .topEdge)
    #expect(surface.updates.first?.visibility == .indeterminate(.notchedHousingMasksMenuBar))

    coordinator.stop()
}

@MainActor
@Test func menuBarOptInReevaluatesPlacementWithoutRebuildingPanels() {
    // The derived AX sample is withheld by default and used after the
    // configuration opts in. The opt-in renders the same bar, so the panels
    // must not be rebuilt — but the placement must be re-read and applied.
    let adapter = MenuBarObservationAdapter(provider: ScreenStub(readings: [notchedReading()]),
                                            probe: ProvisionalProbeStub())
    var built = 0
    let surface = RecordingSurface()
    let coordinator = DisplayCoordinator(adapter: adapter) { _, _, _ in
        built += 1
        return surface
    }
    coordinator.start()
    #expect(built == 1)
    #expect(!adapter.trustsAccessibilityProbe)
    #expect(surface.updates.first?.visibility == .indeterminate(.notchedHousingMasksMenuBar))
    #expect(surface.updates.first?.placement?.mode == .topEdge)

    var optedIn = DivotConfiguration.default
    optedIn.menuBar.trustAccessibilityProbe = true
    coordinator.apply(configuration: optedIn)

    // The settle timer commits the new placement; run the loop briefly.
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))

    // The opt-in renders the same bar: no rebuild, no close.
    #expect(built == 1)
    #expect(!surface.didClose)
    #expect(adapter.trustsAccessibilityProbe)
    #expect(coordinator.configuration.menuBar.trustAccessibilityProbe)
    #expect(surface.updates.last?.placement?.mode == .belowNativeBar(inset: 33))

    coordinator.stop()
}

@MainActor
@Test func rebuildingSurfacesReemitsPlacementSoRecreatedPanelsGetAFrame() {
    // Regression for #0020: a configuration change (a real config file at
    // launch) closes and recreates the panels. The recreated panels start at
    // their initial 1x1 frame, so the coordinator must re-emit a placement for
    // every display; an unchanged reading must not be a silent no-op.
    let adapter = MenuBarObservationAdapter(provider: ScreenStub(readings: [notchedReading()]),
                                            probe: ProvisionalProbeStub())
    var created: [RecordingSurface] = []
    let coordinator = DisplayCoordinator(adapter: adapter) { _, _, _ in
        let surface = RecordingSurface()
        created.append(surface)
        return surface
    }
    coordinator.start()
    #expect(created.count == 1)
    #expect(created[0].updates.first?.placement != nil)

    var updated = DivotConfiguration.default
    updated.left = [.clock]
    updated.right = [.battery]
    updated.appearance.family = .gruvbox
    coordinator.apply(configuration: updated)

    #expect(created.count == 2)
    // The recreated panel must receive a frame, not stay at 1x1.
    #expect(created[1].updates.first?.placement != nil)

    coordinator.stop()
}
