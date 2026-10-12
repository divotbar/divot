import Foundation
import IOKit.ps
import os
import DivotCore

/// Diagnostic logger for power-source reads.
///
/// Emitted at debug level so it is visible while streaming
/// (`log stream --predicate 'subsystem == "com.divot.Divot" && category == "battery"'`)
/// but is not persisted by default. Each read carries the charging and plug
/// flags, which is what confirms whether a notification arrived with a stale
/// charging flag.
private let powerSourceLog = Logger(subsystem: "com.divot.Divot", category: "battery")

/// Live power state from IOKit's power-source API.
///
/// Reading is a cheap property copy, never blocking disk or network I/O.
/// Changes arrive through `IOPSNotificationCreateRunLoopSource` on a dedicated
/// background run loop, so the main thread is never touched. Because a
/// notification can precede the charging flag flipping, each notification arms
/// a bounded, fixed-interval re-check so the bolt appears within about a second
/// instead of waiting for the next percentage change. The re-check closes after
/// a few attempts, so this is not continuous polling.
public final class IOKitBatteryReading: BatteryReading, @unchecked Sendable {
    public init() {}

    public func snapshot() -> BatterySnapshot? {
        IOKitBatteryReading.read()
    }

    public func observeChanges(_ handler: @escaping @Sendable (BatterySnapshot?) -> Void) -> any ProviderSubscription {
        let observer = PowerSourceRunLoopObserver(
            read: { IOKitBatteryReading.read() },
            onChange: handler)
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
            let snapshot = snapshot(from: description)
            powerSourceLog.debug(
                "power-source read charging=\(snapshot.isCharging, privacy: .public) plugged=\(snapshot.isPluggedIn, privacy: .public) level=\(snapshot.percentage ?? -1, privacy: .public)")
            return snapshot
        }
        // No internal battery: a desktop Mac. A settled state, not a failure.
        powerSourceLog.debug("power-source read no-battery")
        return .noBattery
    }

    /// Build the internal-battery snapshot from one IOKit power-source
    /// description.
    ///
    /// IOKit has historically returned `Is Charging` / `Is Charged` either as a
    /// `CFBoolean` or as a `CFNumber` (`1`/`0`) depending on the Mac and OS
    /// build. A plain `as? Bool` only matches the former, so a numeric value
    /// silently read as `false` and the bar lost the charging state. Reading
    /// through `NSNumber.boolValue` accepts both, so the bolt cannot be dropped
    /// between the power source and the presentation.
    static func snapshot(from description: [String: Any]) -> BatterySnapshot {
        BatterySnapshot(
            presence: .internalBattery,
            percentage: percentage(from: description),
            isCharging: boolValue(description[kIOPSIsChargingKey]),
            isPluggedIn: (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
            isFullyCharged: boolValue(description[kIOPSIsChargedKey]))
    }

    /// A tolerant boolean read for an IOKit power-source value.
    static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return false
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
///
/// Each notification reads immediately, then arms a bounded re-check timer:
/// the timer fires on the window's fixed interval while attempts remain, so a
/// charging flag that flips a moment after the notification is still observed.
final class PowerSourceRunLoopObserver: @unchecked Sendable {
    private let read: @Sendable () -> BatterySnapshot?
    private let onChange: @Sendable (BatterySnapshot?) -> Void
    private let lock = NSLock()
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var timer: Timer?
    private var window: BatteryRecheckWindow
    private var stopped = false
    private let ready = DispatchSemaphore(value: 0)

    init(window: BatteryRecheckWindow = BatteryRecheckWindow(),
         read: @escaping @Sendable () -> BatterySnapshot?,
         onChange: @escaping @Sendable (BatterySnapshot?) -> Void) {
        self.window = window
        self.read = read
        self.onChange = onChange
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
        window.close()
        let runLoop = self.runLoop
        lock.unlock()
        if let runLoop {
            // Queue the stop on the run loop rather than calling it directly:
            // this also covers the window where the source is installed but
            // `CFRunLoopRun` has not started yet, so the stop cannot be lost.
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue as CFString) { [weak self] in
                self?.tearDownScheduledTimer()
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
            Unmanaged<PowerSourceRunLoopObserver>.fromOpaque(context).takeUnretainedValue().notificationArrived()
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
        // Seed the bar with the current state; this also arms the first window.
        notificationArrived()
        CFRunLoopRun()
        tearDownScheduledTimer()
        CFRunLoopRemoveSource(currentRunLoop, source, .defaultMode)
    }

    /// A power-source notification landed (or the observer started). Read once
    /// now and keep a bounded re-check timer alive only while the state is
    /// still transient.
    private func notificationArrived() {
        lock.lock()
        window.notificationArrived()
        lock.unlock()
        deliver()
        lock.lock()
        let needsTimer = window.isActive
        lock.unlock()
        if needsTimer { scheduleTimerIfNeeded() }
    }

    /// Read the power source once, hand the snapshot to the subscriber, and
    /// close the re-check window early once the state is settled. Called from
    /// the run loop thread only.
    private func deliver() {
        let snapshot = read()
        onChange(snapshot)
        guard let snapshot, !BatteryRecheckWindow.isTransient(snapshot) else { return }
        lock.lock()
        window.close()
        lock.unlock()
    }

    private func scheduleTimerIfNeeded() {
        lock.lock()
        if timer != nil || stopped {
            lock.unlock()
            return
        }
        let interval = window.interval
        lock.unlock()
        // Timer's block runs on the run loop thread this method is called from.
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
        lock.lock()
        // A concurrent notification may have scheduled the timer first.
        if self.timer == nil, !stopped {
            self.timer = timer
            lock.unlock()
            RunLoop.current.add(timer, forMode: .default)
        } else {
            lock.unlock()
            timer.invalidate()
        }
    }

    private func timerFired() {
        lock.lock()
        let due = window.consume()
        lock.unlock()
        if due { deliver() }
        lock.lock()
        let stillActive = window.isActive
        let timer = self.timer
        if !stillActive { self.timer = nil }
        lock.unlock()
        if !stillActive { timer?.invalidate() }
    }

    /// Invalidate the timer on the run loop thread. Safe to call whether or not
    /// a timer was ever scheduled.
    private func tearDownScheduledTimer() {
        lock.lock()
        let timer = self.timer
        self.timer = nil
        lock.unlock()
        timer?.invalidate()
    }
}
