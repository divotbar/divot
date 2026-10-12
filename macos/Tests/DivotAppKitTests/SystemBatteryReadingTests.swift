import Foundation
import IOKit.ps
import Testing
import DivotCore
@testable import DivotAppKit

/// Reports plugged-but-not-charging on its first read, then charging on every
/// later read — the exact lag the bounded re-check exists for.
private final class LaggingChargingSource: @unchecked Sendable {
    private let lock = NSLock()
    private var readCount = 0
    private var snapshots: [BatterySnapshot] = []

    func read() -> BatterySnapshot {
        lock.lock()
        defer { lock.unlock() }
        readCount += 1
        let snapshot = BatterySnapshot(presence: .internalBattery,
                                       percentage: 60,
                                       isCharging: readCount > 1,
                                       isPluggedIn: true)
        snapshots.append(snapshot)
        return snapshot
    }

    var observed: [BatterySnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }
}

/// One notification reads the stale flag, then the bounded timer re-reads on
/// its fixed interval until the charging flag flips. This exercises the
/// observer timer path that the provider-level fake does not cover.
@Test func powerSourceObserverRechecksUntilTheChargingFlagFlips() async throws {
    let source = LaggingChargingSource()
    let observer = PowerSourceRunLoopObserver(
        window: BatteryRecheckWindow(interval: 0.1, maxAttempts: 10)) {
            _ = source.read()
        }
    observer.start()
    defer { observer.stop() }

    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline && !source.observed.contains(where: { $0.isCharging }) {
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    let observed = source.observed
    #expect(observed.first?.isCharging == false)
    #expect(observed.contains { $0.isCharging })
}

/// The `Is Charging` / `Is Charged` flags are read through
/// `NSNumber.boolValue`, so both the `CFBoolean` and the numeric `CFNumber`
/// encodings IOKit has shipped produce the same snapshot. A plain `as? Bool`
/// used to drop the numeric form to `false`, which hid the charging bolt.
@Test func batterySnapshotReadsChargingFromBooleanAndNumericValues() {
    let asBoolean = IOKitBatteryReading.snapshot(from: [
        kIOPSIsChargingKey: true,
        kIOPSPowerSourceStateKey: kIOPSACPowerValue
    ])
    #expect(asBoolean.isCharging)
    #expect(asBoolean.isPluggedIn)

    let numericOne = IOKitBatteryReading.snapshot(from: [
        kIOPSIsChargingKey: NSNumber(value: 1),
        kIOPSPowerSourceStateKey: kIOPSACPowerValue
    ])
    #expect(numericOne.isCharging)

    let numericZero = IOKitBatteryReading.snapshot(from: [
        kIOPSIsChargingKey: NSNumber(value: 0)
    ])
    #expect(!numericZero.isCharging)
    #expect(!numericZero.isPluggedIn)

    let missing = IOKitBatteryReading.snapshot(from: [:])
    #expect(!missing.isCharging)
    #expect(!missing.isFullyCharged)
}

@Test func batterySnapshotReadsFullyChargedAndPercentage() {
    let snapshot = IOKitBatteryReading.snapshot(from: [
        kIOPSIsChargedKey: NSNumber(value: 1),
        kIOPSCurrentCapacityKey: 37,
        kIOPSMaxCapacityKey: 50
    ])
    #expect(snapshot.isFullyCharged)
    #expect(snapshot.percentage == 74)
    #expect(snapshot.presence == .internalBattery)
}

@Test func boolValueAcceptsBooleanAndNumericInput() {
    #expect(IOKitBatteryReading.boolValue(true))
    #expect(IOKitBatteryReading.boolValue(NSNumber(value: 1)))
    #expect(!IOKitBatteryReading.boolValue(NSNumber(value: 0)))
    #expect(!IOKitBatteryReading.boolValue(nil))
    #expect(!IOKitBatteryReading.boolValue("yes"))
}
