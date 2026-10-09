import CoreGraphics
import Testing
import DivotCore
@testable import DivotAppKit

/// A surface that records what the coordinator forwards to it.
@MainActor
private final class RecordingSurface: BarDisplaySurface {
    private(set) var changes: [WidgetChange] = []
    private(set) var didClose = false

    func apply(_ update: DisplayBarUpdate, reduceMotion: Bool) {}
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
