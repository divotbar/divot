import AppKit
import CoreGraphics
import DivotCore

/// A focused, public-API-only probe for task 0013 (native macOS Spaces).
///
/// It answers one question with evidence: what can a native Spaces adapter
/// observe or do using only documented APIs? It reuses `DivotCore`'s
/// `NativeSpacesCapabilities` and `NativeSpaceObservation` so the probe and the
/// capability report agree.
///
/// It is strictly read-only: it never calls a private symbol, never moves a
/// panel, and never switches a Space. It reports what it can see and states,
/// per operation, what public APIs cannot do. Physical Space switching and
/// multi-display behavior need a person; see
/// `docs/evidence/0013-native-spaces-feasibility.md`.
@MainActor
final class SpacesProbe {
    private let verbose: Bool

    init(verbose: Bool = false) {
        self.verbose = verbose
    }

    // MARK: Display reads

    private func displays() -> [NativeSpaceDisplay] {
        NSScreen.screens.enumerated().map { index, screen in
            let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return NativeSpaceDisplay(
                id: number,
                name: screen.localizedName,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                backingScaleFactor: Double(screen.backingScaleFactor),
                isMain: index == 0 || number == CGMainDisplayID()
            )
        }
    }

    // MARK: Window reads

    /// Reads the on-screen windows public APIs expose, converting Core
    /// Graphics' top-left global origin into AppKit's bottom-left origin using
    /// the primary display's height. Only normal (layer 0) windows are kept so
    /// the app mapping reflects applications, not menu-bar/dock surfaces.
    private func windows() -> [NativeSpaceWindow] {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        return raw.compactMap { info in
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            guard layer == 0 else { return nil }

            let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.intValue ?? 0
            let number = (info[kCGWindowNumber as String] as? NSNumber)?.intValue ?? 0
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""

            var bounds = CGRect.zero
            if let dict = info[kCGWindowBounds as String] as? NSDictionary {
                bounds = CGRect(
                    x: (dict["X"] as? NSNumber)?.doubleValue ?? 0,
                    y: (dict["Y"] as? NSNumber)?.doubleValue ?? 0,
                    width: (dict["Width"] as? NSNumber)?.doubleValue ?? 0,
                    height: (dict["Height"] as? NSNumber)?.doubleValue ?? 0
                )
            }
            // Flip y: CG origin is top-left of the primary display.
            let flipped = CGRect(x: bounds.minX,
                                 y: primaryHeight - bounds.maxY,
                                 width: bounds.width,
                                 height: bounds.height)

            let app = NSRunningApplication(processIdentifier: pid_t(pid))
            return NativeSpaceWindow(
                windowNumber: number,
                ownerName: app?.localizedName ?? owner,
                bundleID: app?.bundleIdentifier ?? "",
                pid: pid,
                bounds: flipped,
                isOnScreen: (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? true,
                layer: layer
            )
        }
    }

    // MARK: Report

    func report() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("# divot spaces probe")
        print("os=\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        print("api=public-only (no private Symbols; read-only)")

        print("# capability: what a native Spaces adapter would need")
        for capability in NativeSpacesCapabilities.publicAPIOnly {
            print("  \(capability.operation.rawValue)=\(capability.support.label) — \(capability.detail)")
        }
        print("  publicly-achievable=\(NativeSpacesCapabilities.publiclyAchievable.map(\.operation.rawValue).joined(separator: ","))")
        print("  not-publicly-achievable=\(NativeSpacesCapabilities.notPubliclyAchievable.map(\.operation.rawValue).joined(separator: ","))")

        let observation = NativeSpaceObservation(displays: displays(), windows: windows())

        print("# observation: displays (public NSScreen)")
        print("displays=\(observation.displays.count) multiDisplay=\(observation.isMultiDisplay)")
        for display in observation.displays {
            let apps = observation.apps(on: display).map(\.name).joined(separator: ",")
            let windowCount = observation.windows(on: display).count
            print("  [\(display.id)] \"\(display.displayName)\" main=\(display.isMain) "
                + "scale=\(display.backingScaleFactor) frame=\(display.frame) "
                + "visible=\(display.visibleFrame) windows=\(windowCount) apps=[\(apps)]")
        }

        print("# observation: Spaces (public APIs)")
        switch observation.spaceListing {
        case .unavailable(let reason):
            print("spaces=unavailable (\(reason))")
        case .listed(let spaces):
            print("spaces=\(spaces.count)")
        }
        let mapped = observation.displays.reduce(0) { $0 + observation.windows(on: $1).count }
        print("onScreenWindows(layer0)=\(observation.windows.count) mappedToDisplay=\(mapped) "
            + "unmapped=\(observation.windows.count - mapped) apps=[\(observation.allApps.map(\.name).joined(separator: ","))]")
        if verbose {
            for window in observation.windows.sorted(by: { $0.windowNumber < $1.windowNumber }) {
                let display = observation.display(containing: CGPoint(x: window.bounds.midX, y: window.bounds.midY))
                print("  window[\(window.windowNumber)] pid=\(window.pid) app=\"\(window.ownerName)\" "
                    + "bundle=\(window.bundleID.isEmpty ? "-" : window.bundleID) bounds=\(window.bounds) "
                    + "display=\(display.map { "\($0.id)" } ?? "none")")
            }
        }
        print("note=on-screen windows are the active Space only; no public Space id is attached to any window")
    }

    // MARK: Watch

    /// Observes the public Spaces-change notification. It can only report that
    /// something changed; the payload carries no Space identity, which is the
    /// finding. No polling.
    func watch() {
        report()
        print("# watching for Spaces/display notifications (Ctrl-C to stop); event-driven, no polling")
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                           object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                print("event=workspace.activeSpaceDidChange payload=none (no Space identity)")
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                print("event=application.didChangeScreenParameters")
            }
        }
        NSApplication.shared.run()
    }
}

setlinebuf(stdout)
let arguments = Array(CommandLine.arguments.dropFirst())
let probe = SpacesProbe(verbose: arguments.contains("--windows"))
if arguments.contains("--watch") {
    probe.watch()
} else {
    probe.report()
}
