import AppKit
import DivotAppKit
import DivotCore

/// `divot --report` prints one honest observation pass and exits, without
/// moving any panel or changing system state. It is the headless-friendly way to
/// inspect what the public APIs currently say on a machine.
@MainActor
enum DivotAppReport {
    static func run() {
        let adapter = MenuBarObservationAdapter(provider: NSScreenGeometryProvider(),
                                                probe: AXSystemMenuBarProbe())
        let observation = adapter.observe()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        print("# divot shell placement report")
        print("displays=\(observation.readings.count)")
        print("accessibility=\(describe(observation.accessibility))")
        print("reduceMotion=\(reduceMotion)")
        for reading in observation.readings {
            let visibility = NativeMenuBarDetector.detect(geometry: reading.geometry, signal: reading.signal)
            print("\(reading.id) notched=\(reading.geometry.isNotched) visibility=\(visibility)")
            if let placement = BarPlacementResolver.placement(screen: reading.geometry, visibility: visibility) {
                print("  mode=\(placement.mode) left=\(placement.geometry.left) right=\(placement.geometry.right)")
            } else {
                print("  mode=indeterminate (holds current placement; never hides)")
            }
        }
    }

    private static func describe(_ state: SystemMenuBarState) -> String {
        switch state {
        case .notTrusted: return "not trusted (permission required)"
        case .unavailable(let reason): return "unavailable (\(reason))"
        case .provisional(let visible, let description):
            return "provisional visible=\(visible) (unvalidated; not used for placement) \(description)"
        case .sampled(let visible, let description):
            return "validated visible=\(visible) \(description)"
        }
    }
}
