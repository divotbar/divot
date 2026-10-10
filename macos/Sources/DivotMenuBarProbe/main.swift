import AppKit
import ApplicationServices
import DivotAppKit
import DivotCore

/// A focused, public-API-only probe for task 0009.
///
/// It reports what the public NSScreen/NSApplication APIs currently say,
/// resolves a menu-bar placement with `DivotCore`'s pure detector, and
/// optionally watches the shared event set and feeds it to the coalescing
/// controller. It reuses `DivotAppKit`'s observation adapter so the probe and
/// the app agree on geometry, display identity, and the Accessibility probe.
///
/// It deliberately does not move any Divot panel or change any system setting,
/// so it is safe to run read-only. Physical validation (actually toggling the
/// bar, multi-display, fullscreen, sleep/wake) is a human step; see
/// `docs/evidence/0009-native-menu-bar-coexistence.md`.
@MainActor
final class Probe {
    private var controller = MenuBarInsetController(initial: .indeterminate(.notchedHousingMasksMenuBar))
    private let provider = NSScreenGeometryProvider()
    private let probe = AXSystemMenuBarProbe(validated: true)

    func currentReadings() -> [ScreenGeometryReading] { provider.screens() }

    private func signal() -> NativeMenuBarSignal {
        // The Accessibility result is trusted for this build: the on-screen
        // position test distinguishes a revealed bar from an auto-hidden one
        // that still reports `hidden == false` (see `SystemMenuBarProbe`).
        NativeMenuBarSignal(accessibilityVisible: probe.sample().accessibilityVisible,
                            configuredAlwaysVisible: nil)
    }

    private func describe(_ reading: ScreenGeometryReading, index: Int) -> String {
        let geometry = reading.geometry
        let visibility = NativeMenuBarDetector.detect(geometry: geometry, signal: signal())
        return """
        \(reading.id) [\(index)] frame=\(geometry.frame) visible=\(geometry.visibleFrame) \
        topBand=\(geometry.topBand) housingTop=\(geometry.housingTop) \
        menuBarInset=\(geometry.menuBarInset) notched=\(geometry.isNotched) \
        scale=\(geometry.backingScaleFactor) auxL=\(String(describing: geometry.auxiliaryTopLeft)) \
        auxR=\(String(describing: geometry.auxiliaryTopRight)) -> \(visibility)
        """
    }

    func report() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("# divot menu-bar probe")
        print("os=\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        let readings = currentReadings()
        print("screens=\(readings.count)")
        for (index, reading) in readings.enumerated() {
            print(describe(reading, index: index))
        }
        if let first = readings.first {
            let visibility = NativeMenuBarDetector.detect(geometry: first.geometry, signal: signal())
            print("resolved=\(visibility)")
            switch visibility {
            case .indeterminate(let reason):
                print("ambiguity=\(reason.rawValue) (public geometry cannot decide; no silent hide)")
            case .visible(let inset):
                print("placement=below-native-bar inset=\(inset)")
            case .hidden:
                print("placement=top-edge inset=0")
            }
        }
        print("defaults._HIHideMenuBar=\(UserDefaults.standard.object(forKey: "_HIHideMenuBar").map { "\($0)" } ?? "unset") (undocumented; diagnostic only)")
        print("systemPresentationOptions=\(NSApplication.shared.currentSystemPresentationOptions.rawValue)")
        print("appPresentationOptions=\(NSApplication.shared.presentationOptions.rawValue)")
        print("accessibilityTrusted=\(AXIsProcessTrusted())")
        switch probe.sample() {
        case .notTrusted:
            print("axMenuBar=unavailable (Accessibility permission not granted)")
        case .unavailable(let reason):
            print("axMenuBar=\(reason)")
        case .provisional(let visible, let description):
            print("axMenuBar=provisional visible=\(visible) (unvalidated heuristic; not used for placement) \(description)")
        case .sampled(_, let description):
            print("axMenuBar=validated \(description)")
        }
    }

    func watch() {
        report()
        print("# watching for events (Ctrl-C to stop); event-driven, no polling")
        for name in MenuBarEventNotifications.all {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let eventName = note.name.rawValue
                MainActor.assumeIsolated {
                    self?.handle(event: eventName)
                }
            }
        }
        NSApplication.shared.run()
    }

    private func handle(event: String) {
        guard let first = currentReadings().first else { return }
        let visibility = NativeMenuBarDetector.detect(geometry: first.geometry, signal: signal())
        let now = ProcessInfo.processInfo.systemUptime
        let immediate = controller.observe(visibility, at: now)
        print("event=\(event) observed=\(visibility) immediate=\(immediate)")
        guard controller.isSettling else { return }
        let deadline = controller.policy.settleDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + deadline) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let settled = self.controller.advance(to: ProcessInfo.processInfo.systemUptime)
                if !settled.isEmpty {
                    print("settled=\(settled) committed=\(self.controller.committed)")
                }
            }
        }
    }
}

let probe = Probe()
setlinebuf(stdout)
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--watch") {
    probe.watch()
} else {
    probe.report()
}
