import Foundation
import Testing
@testable import DivotCore

/// Accessibility regression checks for the pure layer: every shipped widget
/// exposes a real accessible label, every shipped family variant clears the
/// contrast floors, and every interactive item has an activation path. The
/// physical VoiceOver/display checks a test cannot make live in
/// `docs/accessibility-physical-checks.md`.

private let shippedFamilies: [AppearanceConfiguration.Family] = [.alpine, .gruvbox, .ayu, .dracula, .tokyoNight]

@Test func defaultWorkloadCoversEveryRequiredWidget() {
    let required: Set<BarItemID> = [.network, .volume, .frontApp, .time, .battery]
    let placed = Set(BarLayout.default.left + BarLayout.default.right)
    #expect(required.isSubset(of: placed))
}

@Test func everyWidgetPresentationHasANonEmptyAccessibleLabel() {
    for state in PerformanceHarness.defaultWorkloadStates() {
        let presentation = WidgetPresenter.present(id: state.id, state: state)
        #expect(!presentation.accessibilityLabel.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(state.id.rawValue) default")
    }
    for id in BarItemID.allCases {
        // Every honest unavailable state is still announced.
        for kind in [WidgetUnavailable.Kind.noData, .notSupported, .permissionDenied,
                     .managerUnavailable, .failed] {
            let state = WidgetState(id: id, revision: 1,
                                    content: .unavailable(.init(kind: kind,
                                                                message: "\(id.displayName) unavailable")))
            let presentation = WidgetPresenter.present(id: id, state: state)
            #expect(!presentation.accessibilityLabel.isEmpty, "\(id.rawValue) \(kind.rawValue)")
        }
        // The loading state before the first snapshot.
        #expect(!WidgetPresenter.present(id: id, state: nil).accessibilityLabel.isEmpty,
                "\(id.rawValue) loading")
    }
}

@Test func everyFamilyVariantClearsTheAccessibilityContrastFloors() {
    for family in shippedFamilies {
        for variant in ThemeVariant.allCases {
            let tokens = try! #require(ThemeCatalog.palette(family: family, variant: variant),
                                       "missing \(family.rawValue) \(variant.rawValue)").tokens
            let checks = PerformanceHarness.contrastChecks(family: family, variant: variant, tokens: tokens)
            // Six token roles plus the fixed charging green (#0074).
            #expect(checks.count == 7)
            for check in checks {
                #expect(check.clearsFloor,
                        "\(check.family) \(check.variant) \(check.role) = \(check.ratio) < \(check.floor)")
            }
        }
    }
}

@Test func errorStateNeverReliesOnColorAlone() {
    let failure = WidgetPresenter.present(
        id: .network,
        state: WidgetState(id: .network, revision: 1,
                           content: .unavailable(.init(kind: .failed, message: "Network failed"))))
    #expect(failure.isError)
    // The error role is paired with a distinct glyph and an announced reason.
    #expect(failure.symbolName == "exclamationmark.triangle.fill")
    #expect(!failure.accessibilityLabel.isEmpty)
}

@Test func keepAwakeStateIsAnnouncedThroughTheBatteryLabelAndIndicator() {
    let on = WidgetPresenter.present(
        id: .battery,
        state: WidgetState(id: .battery, revision: 1,
                           content: .battery(BatterySnapshot(presence: .internalBattery,
                                                             percentage: 50,
                                                             isKeepingAwake: true))))
    let indicator = try! #require(on.indicator)
    #expect(!indicator.accessibilityLabel.isEmpty)
    #expect(on.accessibilityLabel.contains("keep awake"))
}

@Test func everyInteractiveDefaultItemHasAnActivationPath() {
    for state in PerformanceHarness.defaultWorkloadStates() where state.id != .frontApp {
        #expect(WidgetActions.defaultAction(for: state.id, content: state.content) != .none,
                "\(state.id.rawValue) has no activation")
    }
    // The front-app action couples to live data, so it has a case for both.
    let front = WidgetActions.defaultAction(for: .frontApp,
                                            content: .frontApp(FrontAppSnapshot(name: "Xcode",
                                                                                bundleIdentifier: "com.apple.dt.Xcode")))
    #expect(front == .activateApplication(bundleIdentifier: "com.apple.dt.Xcode"))
    #expect(WidgetActions.defaultAction(for: .frontApp) == .none)
    // Workspaces activation belongs to the workspace-adapter milestone.
    #expect(WidgetActions.defaultAction(for: .workspaces) == .none)
}
