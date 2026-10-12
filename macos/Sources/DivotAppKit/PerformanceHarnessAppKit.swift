import AppKit
import DivotCore

/// The AppKit half of the performance harness.
///
/// The pure scenarios live in `DivotCore.PerformanceHarness`. This adds the
/// view-level work a shared CI runner can still measure: building and restyling
/// the bar for every family under both appearance modes, and auditing that every
/// widget carries an accessible label and the right role. It deliberately does
/// not create panels or touch the window server, so it stays a repeatable
/// in-process measurement rather than a device test.
@MainActor
public enum PerformanceHarnessAppKit {

    /// Scenario name for the view-level accessibility audit.
    public static let accessibilityScenario = "accessibilityContract"
    /// Scenario name for the bar build/restyle measurement.
    public static let barRenderScenario = "barRender"

    /// Both AppKit scenarios, in stable order.
    public static func measurements() -> [PerformanceMeasurement] {
        accessibilityMeasurements() + barRenderMeasurements()
    }

    // MARK: Accessibility audit

    /// Build every default item in every family × variant, assert each one
    /// exposes a non-empty accessible label and the role matching whether it is
    /// interactive, and measure the build+update cost.
    private static func accessibilityMeasurements() -> [PerformanceMeasurement] {
        let states = PerformanceHarness.defaultWorkloadStates()
        var missingLabels = 0
        var wrongRoles = 0
        var interactive = 0
        var checked = 0

        let iterations = 500
        let value = PerformanceHarness.measureMicroseconds(iterations: iterations) {
            for dark in [false, true] {
                for family in AppearanceConfiguration.Family.allCases {
                    let theme = BarTheme.resolve(AppearanceConfiguration(family: family), dark: dark)
                    for state in states {
                        let action = WidgetActions.defaultAction(for: state.id, content: state.content)
                        let view = BarItemView(item: state.id)
                        view.apply(theme: theme)
                        view.update(WidgetPresenter.present(id: state.id, state: state), action: action)

                        checked += 1
                        if action != .none { interactive += 1 }
                        if (view.accessibilityLabel() ?? "").isEmpty { missingLabels += 1 }
                        let expected: NSAccessibility.Role = action == .none ? .staticText : .button
                        if view.accessibilityRole() != expected { wrongRoles += 1 }
                    }
                }
            }
        }

        return [
            PerformanceMeasurement(scenario: accessibilityScenario,
                                   metric: "view.buildUpdate",
                                   value: value,
                                   unit: "microseconds/iteration",
                                   samples: iterations),
            PerformanceMeasurement(scenario: accessibilityScenario,
                                   metric: "items.missingAccessibilityLabel",
                                   value: Double(missingLabels),
                                   unit: "count",
                                   samples: checked),
            PerformanceMeasurement(scenario: accessibilityScenario,
                                   metric: "items.wrongAccessibilityRole",
                                   value: Double(wrongRoles),
                                   unit: "count",
                                   samples: checked),
            PerformanceMeasurement(scenario: accessibilityScenario,
                                   metric: "items.interactive",
                                   value: Double(interactive),
                                   unit: "count",
                                   samples: checked)
        ]
    }

    // MARK: Bar build/restyle

    /// Build and fill the right bar for every family × appearance mode, measure
    /// the build + restyle cost. This is the render-layer half of "all four
    /// theme families, both appearance modes".
    private static func barRenderMeasurements() -> [PerformanceMeasurement] {
        let items = BarLayout.default.right
        let changes = PerformanceHarness.defaultWorkloadStates()
            .filter { items.contains($0.id) }
            .map(WidgetChange.update)

        return AppearanceConfiguration.Family.allCases.flatMap { family -> [PerformanceMeasurement] in
            [false, true].map { dark -> PerformanceMeasurement in
                let theme = BarTheme.resolve(AppearanceConfiguration(family: family), dark: dark)
                let value = PerformanceHarness.measureMicroseconds(iterations: 1_000) {
                    let content = BarContentView(side: .right, items: items, theme: theme)
                    content.frame = NSRect(x: 0, y: 0, width: 752, height: BarMetrics.default.height)
                    content.applyInitialState()
                    content.apply(changes)
                    content.layoutSubtreeIfNeeded()
                }
                return PerformanceMeasurement(scenario: barRenderScenario,
                                              metric: "build.\(family.rawValue).\(dark ? "dark" : "light")",
                                              value: value,
                                              unit: "microseconds/iteration",
                                              samples: 1_000)
            }
        }
    }
}
