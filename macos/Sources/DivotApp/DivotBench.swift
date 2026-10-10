import Foundation
import DivotAppKit
import DivotCore

/// `divot --bench` runs the performance harness and prints what this run
/// measured.
///
/// It is a diagnostic, not evidence by itself: the protocol in
/// `docs/performance.md` requires an optimized Release build on a stable
/// reference machine, and the helper/compositor/VoiceOver checks stay with a
/// person. The harness never writes a target or a prior result, so the output
/// is only ever a measurement of the current process.
@MainActor
enum DivotBench {
    static func run(arguments: [String]) {
        let wantsJSON = arguments.contains("--json")

        var environment = PerformanceEnvironment.detected()
        environment.commit = override("--commit", in: arguments) ?? environment.commit
        environment.hardwareModel = override("--hardware", in: arguments) ?? environment.hardwareModel
        environment.displays = override("--displays", in: arguments) ?? environment.displays
        environment.appearance = override("--appearance", in: arguments) ?? environment.appearance
        environment.powerSource = override("--power", in: arguments) ?? environment.powerSource

        var report = PerformanceHarness.run(environment: environment)
        report.measurements.append(contentsOf: PerformanceHarnessAppKit.measurements())
        report.coverage.append(PerformanceHarnessAppKit.accessibilityScenario)
        report.coverage.append(PerformanceHarnessAppKit.barRenderScenario)

        if wantsJSON {
            print(encode(report))
        } else {
            printHuman(report)
        }
    }

    /// Accept `--flag value` or `--flag=value`; return `nil` when absent.
    private static func override(_ flag: String, in arguments: [String]) -> String? {
        for (index, argument) in arguments.enumerated() {
            if argument == flag, index + 1 < arguments.count {
                return arguments[index + 1]
            }
            if argument.hasPrefix("\(flag)=") {
                return String(argument.dropFirst(flag.count + 1))
            }
        }
        return nil
    }

    private static func encode(_ report: PerformanceReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report),
              let text = String(data: data, encoding: .utf8) else {
            return "{\"error\":\"failed to encode performance report\"}"
        }
        return text
    }

    private static func printHuman(_ report: PerformanceReport) {
        print("# divot performance harness")
        print("generatedAt=\(ISO8601DateFormatter().string(from: report.generatedAt))")
        print("build=\(report.environment.buildConfiguration)")
        if report.environment.buildConfiguration != "release" {
            print("WARNING: this is a debug build; the protocol requires an optimized Release build.")
        }
        print("os=\(report.environment.osVersion)")
        print("arch=\(report.environment.architecture)")
        print("processors=\(report.environment.processorCount)")
        print("commit=\(report.environment.commit ?? "(supply --commit)")")
        print("hardware=\(report.environment.hardwareModel ?? "(supply --hardware)")")
        print("displays=\(report.environment.displays ?? "(supply --displays)")")
        print("appearance=\(report.environment.appearance ?? "(supply --appearance)")")
        print("power=\(report.environment.powerSource ?? "(supply --power)")")

        print("\n# coverage")
        for scenario in report.coverage { print("  \(scenario)") }

        print("\n# measurements (this run only; not a target)")
        for measurement in report.measurements {
            print(String(format: "  %@  %@ = %.3f %@ (n=%d)",
                         measurement.scenario,
                         measurement.metric,
                         measurement.value,
                         measurement.unit,
                         measurement.samples))
        }

        if !report.contrast.isEmpty {
            let minimum = report.contrast.map(\.ratio).min() ?? 0
            print("\n# contrast audit (minimum ratio \(String(format: "%.2f", minimum)))")
            for check in report.contrast.sorted(by: { $0.ratio < $1.ratio }).prefix(8) {
                print(String(format: "  %@ %@ %@ = %.2f (floor %.1f) %@",
                             check.family,
                             check.variant,
                             check.role,
                             check.ratio,
                             check.floor,
                             check.clearsFloor ? "ok" : "BELOW FLOOR"))
            }
        }

        print("\n# must be captured by a person (Instruments / real hardware)")
        for check in report.humanChecks { print("  - \(check)") }

        print("\n# notes")
        for note in report.notes { print("  - \(note)") }
    }
}
