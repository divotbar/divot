import Foundation
import Testing
@testable import DivotCore

@Test func toastStartsHidden() {
    let controller = KeepAwakeToastController()
    #expect(controller.current == nil)
}

@MainActor
@Test func showingToastSetsCurrentState() {
    let controller = KeepAwakeToastController()
    controller.showToast(isActive: true)
    #expect(controller.current?.isActive == true)
    #expect(controller.current?.mainText == "Caffeine on")
    #expect(controller.current?.subtext == "Your Mac will stay awake")
    #expect(controller.current?.colorRole == .active)
}

@MainActor
@Test func toggleToastOffSetsInactiveState() {
    let controller = KeepAwakeToastController()
    controller.showToast(isActive: false)
    #expect(controller.current?.isActive == false)
    #expect(controller.current?.mainText == "Caffeine off")
    #expect(controller.current?.subtext == "Your Mac can sleep")
    #expect(controller.current?.colorRole == .inactive)
}

@MainActor
@Test func showingANewToastReplacesThePrevious() {
    let controller = KeepAwakeToastController()
    controller.showToast(isActive: true)
    let first = controller.current
    controller.showToast(isActive: false)
    let second = controller.current
    #expect(first != nil && second != nil && first?.isActive != second?.isActive)
}

@MainActor
@Test func dismissingToastHidesIt() {
    let controller = KeepAwakeToastController()
    controller.showToast(isActive: true)
    #expect(controller.current != nil)
    controller.dismissToast()
    #expect(controller.current == nil)
}

@MainActor
@Test func observersSeeChanges() {
    let controller = KeepAwakeToastController()
    let box = ObservationBox()

    let _ = controller.observe { toast in
        box.append(toast)
    }

    controller.showToast(isActive: true)
    controller.showToast(isActive: false)
    controller.dismissToast()

    let observed = box.values
    #expect(observed.count == 3)
    #expect(observed[0]?.isActive == true)
    #expect(observed[1]?.isActive == false)
    #expect(observed[2] == nil)
}

@MainActor
@Test func autoDissmissalAfterDuration() async throws {
    let controller = KeepAwakeToastController()
    controller.dismissalDuration = 0.05

    let box = DismissalBox()
    let _ = controller.observe { toast in
        if toast == nil { box.setDismissed() }
    }

    controller.showToast(isActive: true)
    #expect(controller.current != nil)

    try await Task.sleep(for: .milliseconds(100))

    #expect(box.isDismissed)
    #expect(controller.current == nil)
}

@Test func releaseAllClearsState() {
    let controller = KeepAwakeToastController()
    controller.showToast(isActive: true)
    #expect(controller.current != nil)

    controller.releaseAll()

    #expect(controller.current == nil)
}

private final class ObservationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [KeepAwakeToastState?] = []
    func append(_ value: KeepAwakeToastState?) {
        lock.lock(); items.append(value); lock.unlock()
    }
    var values: [KeepAwakeToastState?] {
        lock.lock(); defer { lock.unlock() }; return items
    }
}

private final class DismissalBox: @unchecked Sendable {
    private let lock = NSLock()
    private var dismissed = false
    func setDismissed() {
        lock.lock(); dismissed = true; lock.unlock()
    }
    var isDismissed: Bool {
        lock.lock(); defer { lock.unlock() }; return dismissed
    }
}
