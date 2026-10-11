import Foundation
import Dispatch

// MARK: - Report shape

/// One measured value from a harness scenario.
///
/// A measurement is only ever a number this run actually observed; the harness
/// never writes a target or an expected value into the field. `samples` records
/// how many iterations produced `value`.
public struct PerformanceMeasurement: Codable, Equatable, Sendable {
    public let scenario: String
    public let metric: String
    public let value: Double
    public let unit: String
    public let samples: Int

    public init(scenario: String, metric: String, value: Double,
                unit: String, samples: Int) {
        self.scenario = scenario
        self.metric = metric
        self.value = value
        self.unit = unit
        self.samples = samples
    }
}

/// One audited contrast pairing for a shipped family variant.
///
/// These are computed from the pinned palettes, so they are reproducible
/// measurements of the code, not device observations.
public struct PerformanceContrastCheck: Codable, Equatable, Sendable {
    public let family: String
    public let variant: String
    public let role: String
    public let ratio: Double
    public let floor: Double

    public init(family: String, variant: String, role: String,
                ratio: Double, floor: Double) {
        self.family = family
        self.variant = variant
        self.role = role
        self.ratio = ratio
        self.floor = floor
    }

    public var clearsFloor: Bool { ratio >= floor }
}

/// The machine/OS facts the harness can read itself. Anything the harness
/// cannot observe — the exact commit, the hardware model, display count and
/// scales, the appearance actually in use, and the power source — is left
/// `nil` (or blank) unless a person passes it in; the harness never guesses
/// evidence.
public struct PerformanceEnvironment: Codable, Equatable, Sendable {
    public var osVersion: String
    public var architecture: String
    public var processorCount: Int
    /// `debug` or `release`, from the build that produced this process.
    public var buildConfiguration: String
    /// Human-supplied: git commit under test.
    public var commit: String?
    /// Human-supplied: hardware model on the reference machine.
    public var hardwareModel: String?
    /// Human-supplied: display count, scales, refresh rates.
    public var displays: String?
    /// Human-supplied: the appearance mode measured (light/dark).
    public var appearance: String?
    /// Human-supplied: power source (AC/battery).
    public var powerSource: String?

    public init(osVersion: String,
                architecture: String,
                processorCount: Int,
                buildConfiguration: String,
                commit: String? = nil,
                hardwareModel: String? = nil,
                displays: String? = nil,
                appearance: String? = nil,
                powerSource: String? = nil) {
        self.osVersion = osVersion
        self.architecture = architecture
        self.processorCount = processorCount
        self.buildConfiguration = buildConfiguration
        self.commit = commit
        self.hardwareModel = hardwareModel
        self.displays = displays
        self.appearance = appearance
        self.powerSource = powerSource
    }

    /// What this process can read without a window server or extra permission.
    public static func detected() -> PerformanceEnvironment {
        let info = ProcessInfo.processInfo
        return PerformanceEnvironment(
            osVersion: info.operatingSystemVersionString,
            architecture: PerformanceHarness.architecture,
            processorCount: info.processorCount,
            buildConfiguration: PerformanceHarness.buildConfiguration)
    }
}

/// A full harness run: environment, measured values, the audited contrast
/// pairings, the scenarios that were exercised, and the checks the harness
/// deliberately leaves to a person.
public struct PerformanceReport: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var environment: PerformanceEnvironment
    public var measurements: [PerformanceMeasurement]
    public var contrast: [PerformanceContrastCheck]
    public var coverage: [String]
    /// Scenarios that need Instruments and/or physical hardware. They are named
    /// here so the report is honest about what it did *not* measure.
    public var humanChecks: [String]
    public var notes: [String]

    public init(generatedAt: Date,
                environment: PerformanceEnvironment,
                measurements: [PerformanceMeasurement],
                contrast: [PerformanceContrastCheck],
                coverage: [String],
                humanChecks: [String],
                notes: [String]) {
        self.generatedAt = generatedAt
        self.environment = environment
        self.measurements = measurements
        self.contrast = contrast
        self.coverage = coverage
        self.humanChecks = humanChecks
        self.notes = notes
    }
}

// MARK: - Scenarios

/// The repeatable, in-process scenarios the harness covers. Each corresponds to
/// a row in the optimized-build protocol in `docs/performance.md`.
public enum PerformanceScenario: String, CaseIterable, Codable, Sendable {
    /// The native default workload: network, volume, front-app, clock
    /// (time + weekday + date), and battery.
    case defaultWorkload
    /// Resolving every family under both appearance modes.
    case appearanceModes
    /// Resolving and contrast-auditing all four families × light/dark.
    case themeFamilies
    /// A burst of workspace snapshots through the pure feed state machine.
    case workspaceBurst
    /// Subscription teardown for provider cancellation, plus stale rejection.
    case providerCancellation
    /// Rapid native-menu-bar reveal/hide placement in the display coordinator.
    case menuBarRevealHide
    /// Mapping the default click/keyboard action for every widget.
    case keyboardActions

    public var summary: String {
        switch self {
        case .defaultWorkload:
            return "presentation of the native default workload (network/volume/front-app/clock/battery)"
        case .appearanceModes:
            return "resolve every family under light and dark"
        case .themeFamilies:
            return "resolve and contrast-audit all four families × light/dark"
        case .workspaceBurst:
            return "256 workspace snapshots through the pure feed state machine"
        case .providerCancellation:
            return "tear down a subscription bag and reject a stale emission"
        case .menuBarRevealHide:
            return "reveal/hide cycles through the display coordinator"
        case .keyboardActions:
            return "map the default action for every widget"
        }
    }
}

// MARK: - Harness

/// A repeatable, in-process performance harness for the pure Divot paths.
///
/// It measures only work it can actually observe. Helper-process CPU,
/// WindowServer/compositor cost, on-device VoiceOver, and physical
/// display/fullscreen behavior cannot be measured here: they need Instruments
/// and a person on the reference machine. The report names those checks instead
/// of inventing a value (see `docs/performance.md` and
/// `docs/accessibility-physical-checks.md`).
public enum PerformanceHarness {

    /// `debug` under a debug build, `release` under an optimized build. The
    /// protocol requires the release value; the harness records which one ran.
    public static var buildConfiguration: String {
        #if DEBUG
        return "debug"
        #else
        return "release"
        #endif
    }

    /// The CPU architecture of the process.
    public static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    /// Text roles use the WCAG AA body-text floor; icons/state use non-text.
    /// `accent` is a chrome/border role, so it uses the thinner floor the
    /// existing theme fixtures agreed on.
    private static let textFloor = ContrastAudit.textThreshold
    private static let nonTextFloor = ContrastAudit.nonTextThreshold
    private static let accentFloor = 2.5

    /// Run every pure scenario and return the measured report.
    ///
    /// - Parameter environment: defaults to the facts this process can read;
    ///   pass a populated one to attach commit/hardware/display/appearance/power
    ///   facts supplied by a person.
    public static func run(environment: PerformanceEnvironment = .detected(),
                           now: Date = Date()) -> PerformanceReport {
        var measurements: [PerformanceMeasurement] = []
        var contrast: [PerformanceContrastCheck] = []

        measurements.append(defaultWorkloadMeasurement())
        measurements.append(contentsOf: appearanceModeMeasurements())
        let themeResult = themeFamilyMeasurements()
        measurements.append(contentsOf: themeResult.measurements)
        contrast.append(contentsOf: themeResult.contrast)
        measurements.append(workspaceBurstMeasurement())
        measurements.append(contentsOf: providerCancellationMeasurements())
        measurements.append(menuBarRevealHideMeasurement())
        measurements.append(keyboardActionsMeasurement())

        return PerformanceReport(
            generatedAt: now,
            environment: environment,
            measurements: measurements,
            contrast: contrast,
            coverage: PerformanceScenario.allCases.map(\.rawValue),
            humanChecks: humanChecks,
            notes: notes)
    }

    // MARK: Default workload

    /// The reference first-launch workload: the provider-backed items and the
    /// workspace row. Deterministic values so repeated runs are comparable.
    public static func defaultWorkloadStates() -> [WidgetState] {
        let instant = Date(timeIntervalSince1970: 1_800_000_000)
        return [
            WidgetState(id: .battery, revision: 1,
                        content: .battery(BatterySnapshot(presence: .internalBattery,
                                                          percentage: 82,
                                                          isCharging: false,
                                                          isPluggedIn: true))),
            WidgetState(id: .date, revision: 1,
                        content: .date(ClockSnapshot(date: instant))),
            WidgetState(id: .time, revision: 1,
                        content: .time(ClockSnapshot(date: instant))),
            WidgetState(id: .network, revision: 1,
                        content: .network(NetworkSnapshot(isConnected: true, kind: .wifi))),
            WidgetState(id: .volume, revision: 1,
                        content: .volume(VolumeSnapshot(hasOutputDevice: true, level: 0.4))),
            WidgetState(id: .frontApp, revision: 1,
                        content: .frontApp(FrontAppSnapshot(name: "Ghostty",
                                                            bundleIdentifier: "com.github.ghostty")))
        ]
    }

    private static func defaultWorkloadMeasurement() -> PerformanceMeasurement {
        let states = defaultWorkloadStates()
        let value = measureMicroseconds(iterations: 2_000) {
            for state in states {
                _ = WidgetPresenter.present(id: state.id, state: state)
            }
        }
        return PerformanceMeasurement(scenario: PerformanceScenario.defaultWorkload.rawValue,
                                      metric: "workload.present",
                                      value: value,
                                      unit: "microseconds/iteration",
                                      samples: 2_000)
    }

    // MARK: Appearance modes / theme families

    private static func appearanceModeMeasurements() -> [PerformanceMeasurement] {
        var results: [PerformanceMeasurement] = []
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            let value = measureMicroseconds(iterations: 1_000) {
                for family in AppearanceConfiguration.Family.allCases {
                    _ = ThemeResolver.resolve(AppearanceConfiguration(family: family), dark: dark)
                }
            }
            results.append(PerformanceMeasurement(scenario: PerformanceScenario.appearanceModes.rawValue,
                                                  metric: "resolve.allFamilies.\(mode)",
                                                  value: value,
                                                  unit: "microseconds/iteration",
                                                  samples: 1_000))
        }
        return results
    }

    private static func themeFamilyMeasurements() -> (measurements: [PerformanceMeasurement],
                                                      contrast: [PerformanceContrastCheck]) {
        var measurements: [PerformanceMeasurement] = []
        var contrast: [PerformanceContrastCheck] = []
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox, .ayu, .dracula, .tokyoNight]

        for family in families {
            for dark in [false, true] {
                let variant = ThemeResolver.variant(dark: dark)
                let appearance = AppearanceConfiguration(family: family)
                let value = measureMicroseconds(iterations: 1_000) {
                    _ = ThemeResolver.resolve(appearance, dark: dark)
                }
                measurements.append(PerformanceMeasurement(
                    scenario: PerformanceScenario.themeFamilies.rawValue,
                    metric: "resolve.\(family.rawValue).\(variant.rawValue)",
                    value: value,
                    unit: "microseconds/iteration",
                    samples: 1_000))

                guard let tokens = ThemeResolver.resolve(appearance, dark: dark).tokens else {
                    continue // native uses system colors; audited in the AppKit layer.
                }
                contrast.append(contentsOf: contrastChecks(family: family,
                                                          variant: variant,
                                                          tokens: tokens))
            }
        }

        let worst = contrast.map(\.ratio).min() ?? 0
        measurements.append(PerformanceMeasurement(
            scenario: PerformanceScenario.themeFamilies.rawValue,
            metric: "contrast.minimumRatio",
            value: worst,
            unit: "ratio",
            samples: contrast.count))
        return (measurements, contrast)
    }

    /// The accessibility floors the audit enforces, per role.
    static func contrastChecks(family: AppearanceConfiguration.Family,
                               variant: ThemeVariant,
                               tokens: ThemeTokens) -> [PerformanceContrastCheck] {
        let pairs: [(String, ThemeColor, ThemeColor, Double)] = [
            ("foreground/background", tokens.foreground, tokens.background, textFloor),
            ("foreground/surface", tokens.foreground, tokens.surface, textFloor),
            ("selectedForeground/selected", tokens.selectedForeground, tokens.selected, textFloor),
            ("occupied/background", tokens.occupied, tokens.background, nonTextFloor),
            ("error/background", tokens.error, tokens.background, nonTextFloor),
            ("accent/background", tokens.accent, tokens.background, accentFloor)
        ]
        return pairs.map { role, foreground, background, floor in
            PerformanceContrastCheck(family: family.rawValue,
                                     variant: variant.rawValue,
                                     role: role,
                                     ratio: foreground.contrastRatio(against: background),
                                     floor: floor)
        }
    }

    // MARK: Workspace bursts

    private static func workspaceBurstMeasurement() -> PerformanceMeasurement {
        let value = measureMicroseconds(iterations: 200) {
            var machine = WorkspaceFeedStateMachine()
            let generation = machine.begin()
            for index in 0..<256 {
                let snapshot = WorkspaceSnapshot(
                    manager: .aerospace,
                    workspaces: (0..<10).map { workspace in
                        Workspace(id: WorkspaceID("\(workspace + 1)"),
                                  isFocused: workspace == index % 10,
                                  apps: index.isMultiple(of: 2)
                                      ? [WorkspaceApp(identity: .init(bundleID: "com.example.app",
                                                                      name: "App"),
                                                      pid: 1, windowID: index)]
                                      : [])
                    })
                _ = machine.accept(snapshot: snapshot, generation: generation)
            }
        }
        return PerformanceMeasurement(scenario: PerformanceScenario.workspaceBurst.rawValue,
                                      metric: "stateMachine.256Snapshots",
                                      value: value,
                                      unit: "microseconds/iteration",
                                      samples: 200)
    }

    // MARK: Provider cancellation

    private static func providerCancellationMeasurements() -> [PerformanceMeasurement] {
        let cancel = measureMicroseconds(iterations: 2_000) {
            let bag = SubscriptionBag()
            for _ in 0..<64 { bag.add(CallbackSubscription {}) }
            bag.cancel()
        }
        let stale = measureMicroseconds(iterations: 2_000) {
            var store = WidgetStore()
            let generation = store.activate(.network)
            _ = store.apply(.network(NetworkSnapshot(isConnected: true, kind: .wifi)),
                            for: .network, generation: generation)
            store.deactivate(.network)
            // A late emission from the cancelled activation must be rejected.
            _ = store.apply(.network(NetworkSnapshot(isConnected: true, kind: .ethernet)),
                            for: .network, generation: generation)
        }
        return [
            PerformanceMeasurement(scenario: PerformanceScenario.providerCancellation.rawValue,
                                   metric: "subscriptionBag.cancel64",
                                   value: cancel,
                                   unit: "microseconds/iteration",
                                   samples: 2_000),
            PerformanceMeasurement(scenario: PerformanceScenario.providerCancellation.rawValue,
                                   metric: "store.rejectStaleAfterCancel",
                                   value: stale,
                                   unit: "microseconds/iteration",
                                   samples: 2_000)
        ]
    }

    // MARK: Menu-bar reveal/hide

    private static func menuBarRevealHideMeasurement() -> PerformanceMeasurement {
        // A notch-free 1920×1080 display with no native-bar band. Visibility is
        // toggled through the explicit "always visible" signal on constant
        // geometry so the controller's observe/advance path is what runs.
        let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let geometry = ScreenGeometry(frame: frame, visibleFrame: frame, safeAreaTop: 0)
        let value = measureMicroseconds(iterations: 2_000) {
            var coordinator = DisplayBarCoordinator(menuBarPolicy: .init(settleDelay: 0))
            for index in 0..<4 {
                let signal = NativeMenuBarSignal(configuredAlwaysVisible: index.isMultiple(of: 2))
                _ = coordinator.update(readings: [DisplayReading(id: DisplayBarID(1),
                                                                 geometry: geometry,
                                                                 signal: signal)],
                                       at: TimeInterval(index))
                _ = coordinator.advance(at: TimeInterval(index))
            }
        }
        return PerformanceMeasurement(scenario: PerformanceScenario.menuBarRevealHide.rawValue,
                                      metric: "coordinator.revealHideCycle",
                                      value: value,
                                      unit: "microseconds/iteration",
                                      samples: 2_000)
    }

    // MARK: Keyboard actions

    private static func keyboardActionsMeasurement() -> PerformanceMeasurement {
        let states = defaultWorkloadStates()
        let value = measureMicroseconds(iterations: 4_000) {
            for state in states {
                _ = WidgetActions.defaultAction(for: state.id, content: state.content)
            }
            _ = WidgetActions.defaultAction(for: .workspaces)
        }
        return PerformanceMeasurement(scenario: PerformanceScenario.keyboardActions.rawValue,
                                      metric: "actions.mapDefault",
                                      value: value,
                                      unit: "microseconds/iteration",
                                      samples: 4_000)
    }

    // MARK: Timing

    /// Warm up once, then time `iterations` calls and return microseconds per
    /// iteration. The warm-up keeps one-time lazy initialization out of the
    /// measured window.
    public static func measureMicroseconds(iterations: Int, _ work: () -> Void) -> Double {
        work()
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { work() }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(iterations) / 1_000
    }

    // MARK: Human checks

    /// Scenario names that require Instruments and/or physical hardware. Kept
    /// stable so the report and the docs agree.
    public static let humanChecks: [String] = [
        "helper-cost: sample every Divot helper process with Instruments Time Profiler and energy diagnostics",
        "compositor-cost: measure WindowServer/GPU work and end-to-visible latency with Core Animation instrument traces",
        "physical-displays: negative origins, mixed scales, notch/notch-free, sleep/wake, hot-plug, fullscreen/Spaces",
        "voiceover: traverse every widget, theme, and panel with VoiceOver on a real Mac",
        "reference-comparison: identical workload against SketchyBar and a-bar, plus an idle baseline"
    ]

    public static let notes: [String] = [
        "Values are in-process measurements from this run only; the harness never writes a target or a prior result.",
        "Timing ceilings need a stable physical reference machine, not a shared CI runner; shared CI timing is advisory.",
        "Helper, compositor, physical-display, and VoiceOver evidence must be captured by a person; see docs/performance.md.",
        "No performance result is committed to this repository; store reports under docs/benchmarks/ and link large raw captures outside Git."
    ]
}
