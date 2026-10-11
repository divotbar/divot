import Foundation
import Testing
@testable import DivotCore

/// Structural coverage for the performance harness itself. These tests never
/// assert a timing threshold: shared CI timing is advisory, and the protocol's
/// ceilings need a stable physical reference machine. They assert that the
/// harness actually ran every scenario and never invented evidence.
@Test func harnessCoversEveryProtocolScenario() {
    let report = PerformanceHarness.run()
    let coverage = Set(report.coverage)
    for scenario in PerformanceScenario.allCases {
        #expect(coverage.contains(scenario.rawValue), "missing \(scenario.rawValue)")
    }
    // Stable, duplicate-free coverage so the report is readable.
    #expect(coverage.count == report.coverage.count)
}

@Test func harnessMeasurementsAreFiniteAndNonNegative() {
    let report = PerformanceHarness.run()
    #expect(!report.measurements.isEmpty)
    for measurement in report.measurements {
        #expect(measurement.value.isFinite, "\(measurement.metric) not finite")
        #expect(measurement.value >= 0, "\(measurement.metric) negative")
        #expect(measurement.samples > 0)
        #expect(!measurement.metric.isEmpty)
    }
}

@Test func harnessContrastAuditClearsEveryFloorForAllFourFamilies() {
    let report = PerformanceHarness.run()
    // 4 families × 2 variants × 6 audited roles.
    #expect(report.contrast.count == 4 * 2 * 6)
    for check in report.contrast {
        #expect(check.clearsFloor,
                "\(check.family) \(check.variant) \(check.role) = \(check.ratio) < \(check.floor)")
    }
}

@Test func harnessNeverInventsHumanSuppliedEnvironment() {
    let report = PerformanceHarness.run(environment: .detected())
    // Only facts the process can read are auto-filled; the rest stay blank.
    #expect(report.environment.commit == nil)
    #expect(report.environment.hardwareModel == nil)
    #expect(report.environment.displays == nil)
    #expect(report.environment.appearance == nil)
    #expect(report.environment.powerSource == nil)
    #expect(["debug", "release"].contains(report.environment.buildConfiguration))
    #expect(!report.environment.architecture.isEmpty)
    #expect(report.environment.processorCount > 0)
    // The scenarios a person must capture are named, not silently omitted.
    #expect(report.humanChecks.contains { $0.contains("helper-cost") })
    #expect(report.humanChecks.contains { $0.contains("compositor-cost") })
    #expect(report.humanChecks.contains { $0.contains("voiceover") })
    #expect(!report.notes.isEmpty)
}

@Test func harnessCarriesSuppliedFactsVerbatim() {
    var environment = PerformanceEnvironment.detected()
    environment.commit = "deadbeef"
    environment.displays = "2 displays: 2560x1440@2 non-notch, 1728x1117@2 notch"
    let instant = Date(timeIntervalSince1970: 0)
    let report = PerformanceHarness.run(environment: environment, now: instant)
    #expect(report.environment.commit == "deadbeef")
    #expect(report.environment.displays?.contains("notch") == true)
    #expect(report.generatedAt == instant)
}

@Test func defaultWorkloadIncludesTheRequiredWidgets() {
    let ids = Set(PerformanceHarness.defaultWorkloadStates().map(\.id))
    #expect(ids == [.network, .volume, .frontApp, .date, .time, .battery])
}
