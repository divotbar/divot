import Foundation
import IOKit.ps
import Testing
@testable import DivotAppKit

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
