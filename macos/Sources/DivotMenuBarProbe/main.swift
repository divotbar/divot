import AppKit
import ApplicationServices
import DivotCore

/// A focused, public-API-only probe for task 0009.
///
/// It does three things and nothing else:
/// 1. reports what the public NSScreen/NSApplication APIs currently say,
/// 2. resolves a menu-bar placement with `DivotCore`'s pure detector, and
/// 3. optionally watches OS notifications and feeds them to the coalescing
///    controller (event-driven; no polling loop).
///
/// It deliberately does not move any Divot panel or change any system setting,
/// so it is safe to run read-only. Physical validation (actually toggling the
/// bar, multi-display, fullscreen, sleep/wake) is a human step; see
/// `docs/evidence/0009-native-menu-bar-coexistence.md`.
@MainActor
final class Probe {
    private var controller = MenuBarInsetController(initial: .indeterminate(.notchedHousingMasksMenuBar))

    private static let notifications: [NSNotification.Name] = [
        NSApplication.didChangeScreenParametersNotification,
        NSApplication.didChangeOcclusionStateNotification,
        NSApplication.didBecomeActiveNotification,
        NSApplication.didResignActiveNotification,
        NSWorkspace.activeSpaceDidChangeNotification,
        NSWorkspace.didActivateApplicationNotification,
        NSMenu.didBeginTrackingNotification,
        NSMenu.didEndTrackingNotification
    ]

    func currentGeometry() -> [ScreenGeometry] {
        NSScreen.screens.map { screen in
            ScreenGeometry(frame: screen.frame,
                           visibleFrame: screen.visibleFrame,
                           safeAreaTop: screen.safeAreaInsets.top,
                           auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                           auxiliaryTopRight: screen.auxiliaryTopRightArea,
                           backingScaleFactor: screen.backingScaleFactor)
        }
    }

    /// Reads the Accessibility system-wide menu-bar element. Returns a string
    /// describing the raw sample; `nil` means the accessibility probe is not
    /// trusted, so the geometry path must not assume a result.
    func accessibilityMenuBarSample() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        var barRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(system, kAXMenuBarAttribute as CFString, &barRef)
        guard err == .success, let barRef else {
            return "no menu-bar element (AXError \(err.rawValue))"
        }
        let bar = barRef as! AXUIElement
        func value(_ attribute: CFString) -> CFTypeRef? {
            var v: CFTypeRef?
            return AXUIElementCopyAttributeValue(bar, attribute, &v) == .success ? v : nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        if let p = value(kAXPositionAttribute as CFString) {
            AXValueGetValue(p as! AXValue, .cgPoint, &position)
        }
        if let s = value(kAXSizeAttribute as CFString) {
            AXValueGetValue(s as! AXValue, .cgSize, &size)
        }
        var hidden = false
        if let h = value(kAXHiddenAttribute as CFString), CFGetTypeID(h) == CFBooleanGetTypeID() {
            hidden = CFBooleanGetValue((h as! CFBoolean))
        }
        return "position=\(position) size=\(size) hidden=\(hidden)"
    }

    /// Independent, public geometry reading used only for the report. This is
    /// not fed into the detector as a trusted signal (see the evidence doc).
    private func signal() -> NativeMenuBarSignal {
        // The Accessibility result is intentionally not trusted by default: an
        // unverified off-screen heuristic must not silently drive placement.
        NativeMenuBarSignal(accessibilityVisible: nil, configuredAlwaysVisible: nil)
    }

    private func describe(_ geometry: ScreenGeometry, index: Int) -> String {
        let visibility = NativeMenuBarDetector.detect(geometry: geometry, signal: signal())
        return """
        display[\(index)] frame=\(geometry.frame) visible=\(geometry.visibleFrame) \
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
        print("screens=\(NSScreen.screens.count)")
        for (index, geometry) in currentGeometry().enumerated() {
            print(describe(geometry, index: index))
        }
        if let main = currentGeometry().first {
            let visibility = NativeMenuBarDetector.detect(geometry: main, signal: signal())
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
        if let sample = accessibilityMenuBarSample() {
            print("axMenuBar=\(sample)")
        } else {
            print("axMenuBar=unavailable (Accessibility permission not granted)")
        }
    }

    func watch() {
        report()
        print("# watching for events (Ctrl-C to stop); event-driven, no polling")
        for name in Self.notifications {
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
        guard let main = currentGeometry().first else { return }
        let visibility = NativeMenuBarDetector.detect(geometry: main, signal: signal())
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
