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

        printWorkspaceReport()
    }

    /// One read-only pass against whichever manager is installed. Blocks the
    /// (idle) main thread on short-lived subprocesses so the whole report stays
    /// a single synchronous command; it never subscribes or mutates manager
    /// state.
    private static func printWorkspaceReport() {
        print("# workspaces")
        // The screen mapping must be captured on the main actor before the
        // adapter runs its queries on background work.
        let displayIndex = ScreenDisplayIndexResolver.live()
        // Read the validated configuration for the adapter and honor the same
        // environment override the running app uses.
        let store = ConfigurationStore()
        _ = store.load()
        let preferred = WorkspaceEnvironmentOverrides.adapter(store.current.widgets.workspaces.adapter)
        let installed = WorkspaceAdapterFactory.installedManagers()
        guard let selection = WorkspaceManagerSelector.select(preferred: preferred,
                                                              installed: installed),
              let adapter = WorkspaceAdapterFactory.makeAdapter(for: selection.kind,
                                                                displayIndex: displayIndex) else {
            print("adapter=(none)")
            print("availability=unavailable (\(WorkspaceUnavailabilityReason.managerNotInstalled.summary))")
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            let availability = await adapter.capabilities()
            print("adapter=\(adapter.kind.rawValue)")
            print("availability=\(availability.summary)")
            if availability.isAvailable {
                do {
                    let snapshot = try await adapter.snapshot()
                    for workspace in snapshot.workspaces {
                        let state = workspace.isFocused ? "focused" : (workspace.isOccupied ? "occupied" : "empty")
                        let apps = workspace.apps.map(\.identity.name).joined(separator: ",")
                        let screens = workspace.monitor?.screensID.map(String.init) ?? "-"
                        print("  \(workspace.id) monitor=\(workspace.monitor?.id ?? 0) screens=\(screens) state=\(state) apps=[\(apps)]")
                    }
                } catch {
                    print("snapshot=error \(error)")
                }
            }
            await adapter.stop()
            semaphore.signal()
        }
        semaphore.wait()
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
