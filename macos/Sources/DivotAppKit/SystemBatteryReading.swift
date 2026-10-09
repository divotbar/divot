import Foundation
import IOKit.ps
import DivotCore

/// Live power state from IOKit's power-source API.
///
/// Reading is a cheap property copy, never blocking disk or network I/O.
/// Changes arrive through `IOPSNotificationCreateRunLoopSource` on a dedicated
/// background run loop, so no polling is required and the main thread is never
/// touched.
public final class IOKitBatteryReading: BatteryReading, @unchecked Sendable {
    public init() {}

    public func snapshot() -> BatterySnapshot? {
        IOKitBatteryReading.read()
    }

    public func observeChanges(_ handler: @escaping @Sendable () -> Void) -> any ProviderSubscription {
        let observer = PowerSourceRunLoopObserver(handler: handler)
        observer.start()
        return CallbackSubscription { observer.stop() }
    }

    static func read() -> BatterySnapshot? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .noBattery
        }
        for source in sources {
            guard let raw = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue(),
                  let description = raw as? [String: Any] else { continue }
            guard (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            return BatterySnapshot(
                presence: .internalBattery,
                percentage: percentage(from: description),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
                isFullyCharged: description[kIOPSIsChargedKey] as? Bool ?? false)
        }
        // No internal battery: a desktop Mac. A settled state, not a failure.
        return .noBattery
    }

    private static func percentage(from description: [String: Any]) -> Int? {
        let current = description[kIOPSCurrentCapacityKey] as? Int
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Int
        if let current, let maxCapacity, maxCapacity > 0 {
            return Int((Double(current) / Double(maxCapacity) * 100).rounded())
        }
        return current
    }
}

/// Owns one background run loop with a power-source notification source.
private final class PowerSourceRunLoopObserver: @unchecked Sendable {
    private let handler: @Sendable () -> Void
    private let lock = NSLock()
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var stopped = false
    private let ready = DispatchSemaphore(value: 0)

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func start() {
        let thread = Thread { [weak self] in self?.run() }
        thread.name = "divot.power-source"
        thread.stackSize = 512 * 1024
        lock.lock()
        self.thread = thread
        lock.unlock()
        thread.start()
    }

    func stop() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        stopped = true
        let runLoop = self.runLoop
        lock.unlock()
        if let runLoop {
            // Queue the stop on the run loop rather than calling it directly:
            // this also covers the window where the source is installed but
            // `CFRunLoopRun` has not started yet, so the stop cannot be lost.
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue as CFString) {
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
            CFRunLoopWakeUp(runLoop)
        }
        ready.wait()
    }

    private func run() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            Unmanaged<PowerSourceRunLoopObserver>.fromOpaque(context).takeUnretainedValue().fire()
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            ready.signal()
            return
        }
        let currentRunLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(currentRunLoop, source, .defaultMode)
        lock.lock()
        runLoop = currentRunLoop
        let alreadyStopped = stopped
        lock.unlock()
        ready.signal()
        if alreadyStopped {
            CFRunLoopRemoveSource(currentRunLoop, source, .defaultMode)
            return
        }
        fire()
        CFRunLoopRun()
        CFRunLoopRemoveSource(currentRunLoop, source, .defaultMode)
    }

    private func fire() {
        handler()
    }
}
