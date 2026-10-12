import AppKit
import ApplicationServices
import DivotCore

/// The live `divot status` environment: public APIs only, no prompting, no
/// window-manager mutation, and no busy polling. Each reading is a single
/// synchronous call so the command returns immediately.
public extension DivotStatusEnvironment {
    static var live: DivotStatusEnvironment {
        DivotStatusEnvironment(
            version: { DivotAppFacts.version },
            isRunning: { DivotAppFacts.isRunning },
            accessibilityGranted: { AXIsProcessTrusted() },
            locationState: { LocationAuthorizationTracker().currentStatus().statusPermissionState },
            installedManagers: { WorkspaceAdapterFactory.installedManagers() },
            store: ConfigurationStore(),
            environment: ProcessInfo.processInfo.environment)
    }
}

/// App facts read from the running binary's bundle. Bundled previews carry a
/// `DivotPreviewVersion`; an unsigned development build reports `unbundled`
/// rather than inventing a release version.
public enum DivotAppFacts {
    public static var version: String {
        let bundle = Bundle.main
        for key in ["DivotPreviewVersion", "CFBundleShortVersionString"] {
            if let value = bundle.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
                return value
            }
        }
        return "unbundled"
    }

    /// Whether another Divot app instance is running, excluding this CLI
    /// process. A packaged build is matched by bundle identifier; an unbundled
    /// development build falls back to matching the executable path, since it
    /// has no bundle identifier to share.
    public static var isRunning: Bool {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications
        if let bundleID = Bundle.main.bundleIdentifier {
            return applications.contains {
                $0.bundleIdentifier == bundleID && $0.processIdentifier != selfPID
            }
        }
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return false }
        return applications.contains {
            $0.processIdentifier != selfPID &&
            $0.executableURL?.resolvingSymlinksInPath() == executable
        }
    }
}

extension LocationAuthorizationStatus {
    /// Map CoreLocation's authorization to the report's permission state.
    var statusPermissionState: StatusPermissionState {
        switch self {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorizedWhenInUse, .authorizedAlways: return .granted
        }
    }
}
