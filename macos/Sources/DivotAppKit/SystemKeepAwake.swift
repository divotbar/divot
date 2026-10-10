import Foundation
import IOKit.pwr_mgt
import DivotCore

/// The production `PowerAssertionCreating`, backed by the public IOKit power
/// assertion API.
///
/// It asks for both documented idle-sleep assertions — system *and* display —
/// so a keep-awake session behaves like Caffeine/Amphetamine rather than letting
/// the screen dim while the machine stays up. No private API is used and there
/// is no `caffeinate` subprocess.
public final class IOKitPowerAssertionCreator: PowerAssertionCreating {
    public init() {}

    public func acquireAssertion(reason: String) -> (any PowerAssertionHandle)? {
        var ids: [IOPMAssertionID] = []
        for type in Self.assertionTypes {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(type as CFString,
                                                     IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                     reason as CFString,
                                                     &id)
            if result == kIOReturnSuccess {
                ids.append(id)
            }
        }
        // If not even one assertion could be created, report failure so the bar
        // shows "off" instead of claiming a state the process does not hold.
        guard !ids.isEmpty else { return nil }
        return IOKitPowerAssertionHandle(ids: ids)
    }

    /// The public assertion types Divot requests.
    static let assertionTypes: [String] = [
        kIOPMAssertionTypePreventUserIdleSystemSleep,
        kIOPMAssertionTypePreventUserIdleDisplaySleep
    ]
}

/// Releases the held IOKit assertions exactly once.
final class IOKitPowerAssertionHandle: PowerAssertionHandle, @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [IOPMAssertionID]

    init(ids: [IOPMAssertionID]) {
        self.ids = ids
    }

    func release() {
        lock.lock()
        let held = ids
        ids = []
        lock.unlock()
        for id in held { IOPMAssertionRelease(id) }
    }
}
