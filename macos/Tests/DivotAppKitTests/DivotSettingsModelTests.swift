import Foundation
import CoreLocation
import Testing
import DivotCore
@testable import DivotAppKit

@MainActor
private final class StubLoginItem: LoginItemControlling {
    var isEnabled = false
    var statusDescription = "Stub login item"
    var succeeds = true
    private(set) var lastRequest: Bool?

    func setEnabled(_ enabled: Bool) -> Bool {
        lastRequest = enabled
        if succeeds { isEnabled = enabled }
        return succeeds
    }
}

@MainActor
private func makeModel(loginItem: LoginItemControlling = StubLoginItem(),
                       locationTracker: any LocationAuthorizationTracking = LocationAuthorizationTracker())
    throws -> (DivotSettingsModel, ConfigurationController) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = ConfigurationStore(configURL: directory.appendingPathComponent("config.json"))
    let controller = ConfigurationController(store: store)
    return (DivotSettingsModel(controller: controller,
                               loginItem: loginItem,
                               locationTracker: locationTracker), controller)
}

@MainActor
@Test func familyAndModePersistSeparately() throws {
    let (model, controller) = try makeModel()

    model.update { $0.appearance.family = .gruvbox }
    model.update { $0.appearance.mode = .dark }

    // Changing the variant did not reset the family.
    #expect(model.configuration.appearance.family == .gruvbox)
    #expect(model.configuration.appearance.mode == .dark)

    // Both survive a reload from disk.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.appearance.family == .gruvbox)
    #expect(reloaded.current.appearance.mode == .dark)
}

@MainActor
@Test func anInvalidEditIsRefusedAndReported() throws {
    let (model, _) = try makeModel()
    let good = model.configuration.appearance.accent

    model.update { $0.appearance.accent = "not-hex" }

    #expect(model.errorMessage?.contains("appearance.accent") == true)
    #expect(model.configuration.appearance.accent == good)
}

@MainActor
@Test func itemsCanBeHiddenMovedAndReordered() throws {
    let (model, _) = try makeModel()

    model.setPlaced(.frontApp, false)
    #expect(!model.configuration.isPlaced(.frontApp))

    model.setPlaced(.frontApp, true)
    #expect(model.configuration.side(of: .frontApp) == .left)

    model.setSide(.frontApp, .right)
    #expect(model.configuration.side(of: .frontApp) == .right)

    // Reorder within the right group.
    let right = model.configuration.right
    guard let index = right.firstIndex(of: .frontApp), index > 0 else {
        Issue.record("expected front-app on the right after a non-first slot")
        return
    }
    model.moveWithinSide(.frontApp, delta: -1)
    #expect(model.configuration.right.firstIndex(of: .frontApp) == index - 1)
}

@MainActor
@Test func reorderIsDisabledAtTheEndsAndKeepsTheBarOrderInSync() throws {
    let (model, _) = try makeModel()

    // The default left group is [workspaces, front-app]: the first item can
    // only move later (right), and the last only earlier (left).
    let left = model.configuration.items(on: .left)
    let first = try #require(left.first)
    let last = try #require(left.last)
    #expect(!model.canMove(first, delta: -1))
    #expect(model.canMove(first, delta: 1))
    #expect(model.canMove(last, delta: -1))
    #expect(!model.canMove(last, delta: 1))

    // Pressing the disabled direction at either end is a no-op.
    model.moveWithinSide(first, delta: -1)
    model.moveWithinSide(last, delta: 1)
    #expect(model.configuration.items(on: .left) == left)

    // A middle item moves one slot, and the ordered configuration the bar
    // renders with follows it (right default is [battery, time, network, volume]).
    model.moveWithinSide(.time, delta: -1)
    #expect(model.configuration.items(on: .right) == [.time, .battery, .network, .volume])
    #expect(model.configuration.barLayout.items(on: .right) == model.configuration.right)

    // The moved item is now first, so it cannot move earlier again.
    #expect(!model.canMove(.time, delta: -1))
}

@MainActor
@Test func loginItemToggleRoutesThroughTheControl() throws {
    let stub = StubLoginItem()
    let (model, _) = try makeModel(loginItem: stub)

    #expect(!model.loginItemEnabled)
    model.setLaunchAtLogin(true)
    #expect(stub.lastRequest == true)
    #expect(model.loginItemEnabled)

    stub.succeeds = false
    model.setLaunchAtLogin(false)
    #expect(model.errorMessage != nil)
}

@MainActor
@Test func rememberKeepAwakeCapturesTheLiveState() throws {
    let (_, controller) = try makeModel()
    #expect(!controller.configuration.keepAwake.remember)

    // The live assertion is on when the user opts in, so the remembered state
    // must capture it rather than defaulting to off.
    let model = DivotSettingsModel(controller: controller, keepAwakeIsActive: { true })
    model.setRememberKeepAwake(true)
    #expect(model.configuration.keepAwake.remember)
    #expect(model.configuration.keepAwake.isActive)

    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.keepAwake == KeepAwakeConfiguration(remember: true, isActive: true))
}

@MainActor
@Test func textSizeAndFontApplyAndPersist() throws {
    let (model, controller) = try makeModel()

    model.setTextSize(18)
    model.setTextFont("Menlo")

    #expect(model.configuration.text == TextConfiguration(size: 18, font: "Menlo"))
    // The icon follows the text size, so the bar stays in proportion.
    #expect(model.configuration.barMetrics.textFontSize == 18)
    #expect(model.configuration.barMetrics.iconSize == 20)

    // Both survive a reload from disk, like the theme picker.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.text == TextConfiguration(size: 18, font: "Menlo"))
}

@MainActor
@Test func appIconOptInStartsOffAndTogglesAndPersists() throws {
    let (model, controller) = try makeModel()

    // The icon is off by default, so settings opens with the toggle off.
    #expect(!model.configuration.showAppIcon)

    model.setShowAppIcon(true)
    #expect(model.configuration.showAppIcon)

    // The change survives a relaunch from the same store.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.showAppIcon)

    // And it can be turned back off, writing the default shape again.
    model.setShowAppIcon(false)
    #expect(!model.configuration.showAppIcon)
    let reread = try ConfigurationParser.parse(Data(contentsOf: controller.configURL))
    #expect(!reread.configuration.showAppIcon)
}

@MainActor
@Test func appIconSizeStartsAtTheStatusIconSizeAndPersists() throws {
    let (model, controller) = try makeModel()

    // The default matches the status icon size so the left app icons line up
    // with the right-side icons (#0052).
    #expect(model.configuration.appIconSize == Double(BarMetrics.default.iconSize))
    #expect(model.configuration.barMetrics.appIconSize == model.configuration.barMetrics.iconSize)

    model.setAppIconSize(20)
    #expect(model.configuration.appIconSize == 20)
    #expect(model.configuration.barMetrics.appIconSize == 20)

    // The change survives a relaunch from the same store.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.appIconSize == 20)

    // An out-of-range edit is clamped to the slider range rather than written.
    model.setAppIconSize(100)
    #expect(model.configuration.appIconSize == DivotConfiguration.appIconSizeRange.upperBound)
}

@MainActor
@Test func menuBarCursorRevealDefaultsOnAndTheFallbackOffThenPersist() throws {
    let (model, controller) = try makeModel()

    // The pointer reveal is on by default; the always-below fallback is off.
    #expect(model.configuration.menuBar.moveBelowOnCursorReveal)
    #expect(!model.configuration.menuBar.alwaysBelow)

    model.setMoveBelowOnCursorReveal(false)
    model.setAlwaysBelowMenuBar(true)
    #expect(!model.configuration.menuBar.moveBelowOnCursorReveal)
    #expect(model.configuration.menuBar.alwaysBelow)

    // Both survive a relaunch from the same store.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(!reloaded.current.menuBar.moveBelowOnCursorReveal)
    #expect(reloaded.current.menuBar.alwaysBelow)
}

@MainActor
@Test func workspaceDotTogglesStartOnAndPersist() throws {
    let (model, controller) = try makeModel()

    // Both markers are on by default, so settings opens with both toggles on.
    #expect(model.configuration.showOccupiedDot)
    #expect(model.configuration.showEmptyDot)

    model.update { $0.showOccupiedDot = false }
    #expect(!model.configuration.showOccupiedDot)
    // Hiding one marker leaves the other untouched.
    #expect(model.configuration.showEmptyDot)

    // The change survives a relaunch from the same store.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(!reloaded.current.showOccupiedDot)
    #expect(reloaded.current.showEmptyDot)
}

@MainActor
@Test func bottomShadowStartsOffAndTogglesAndPersists() throws {
    let (model, controller) = try makeModel()

    // The shadow is off by default, so settings opens with the toggle off.
    #expect(!model.configuration.bottomShadow)

    model.setBottomShadow(true)
    #expect(model.configuration.bottomShadow)

    // The change survives a relaunch from the same store.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.bottomShadow)

    // And it can be turned back off, writing the default shape again.
    model.setBottomShadow(false)
    #expect(!model.configuration.bottomShadow)
    let reread = try ConfigurationParser.parse(Data(contentsOf: controller.configURL))
    #expect(!reread.configuration.bottomShadow)
}

@MainActor
@Test func anUninstalledConfiguredFontShowsTheSystemDefaultInThePicker() throws {
    let (model, _) = try makeModel()
    model.update { $0.text.font = "No Such Font 12345" }

    // The document keeps the honest value; the picker shows the fallback rather
    // than a blank row, and the bar resolves the system font at the configured size.
    #expect(model.configuration.text.font == "No Such Font 12345")
    #expect(model.selectedFontFamily == "")
    #expect(model.configuration.barMetrics.textFontSize == 14)
}

@MainActor
@Test func outOfRangeTextSizeIsRefusedAndReported() throws {
    let (model, _) = try makeModel()
    let good = model.configuration.text.size

    model.setTextSize(99)

    #expect(model.errorMessage?.contains("text.size") == true)
    #expect(model.configuration.text.size == good)
}

@MainActor
@Test func modelFollowsChangesPublishedByTheSharedController() throws {
    let (model, controller) = try makeModel()

    // An external reload or a save elsewhere publishes through the controller;
    // the open window follows it instead of holding a stale copy.
    controller.update { $0.appearance.mode = .dark }
    #expect(model.configuration.appearance.mode == .dark)
}

@MainActor
@Test func settingsExposeTheResolvedFamilyThemeAndSource() throws {
    let (model, _) = try makeModel()
    model.update { $0.appearance.family = .dracula }

    #expect(model.resolvedTheme.family == .dracula)
    #expect(model.themeSourceLine.contains("Dracula"))
    #expect(model.themeSourceLine.contains("MIT"))
    // The resolved accent is a real hex, resolved from the family rather than
    // the root default.
    #expect(model.resolvedAccentHex.hasPrefix("#"))
    #expect(model.resolvedAccentHex.count == 7)

    model.update { $0.appearance.family = .native }
    #expect(model.resolvedTheme.usesSystemColors)
    #expect(model.themeSourceLine.contains("macOS"))
}

@MainActor
@Test func everyThemeFamilySelectionAppliesAndPersists() throws {
    let (model, controller) = try makeModel()

    // Every family the picker offers maps to the persisted document and to the
    // palette the bar resolves. The native default follows macOS rather than a
    // fixed family palette.
    for family in AppearanceConfiguration.Family.allCases {
        model.update { $0.appearance.family = family }

        #expect(model.configuration.appearance.family == family)
        #expect(model.resolvedTheme.family == family)
        if family == .native {
            #expect(model.resolvedTheme.usesSystemColors)
            #expect(model.resolvedTheme.tokens == nil)
            #expect(model.themeSourceLine.contains("macOS"))
        } else {
            #expect(!model.resolvedTheme.usesSystemColors)
            let tokens = try #require(model.resolvedTheme.tokens)
            // The family's signature accent is applied by default, and the
            // settings line names the family rather than the native default.
            #expect(model.resolvedAccentHex == tokens.accent.hexString)
            #expect(model.themeSourceLine.contains(family.displayName))
        }
    }

    // The last selection is what a relaunch reloads from the same store.
    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.appearance.family == AppearanceConfiguration.Family.allCases.last)
}

@MainActor
@Test func everyAppearanceModeSelectionAppliesAndPersists() throws {
    let (model, controller) = try makeModel()
    model.update { $0.appearance.family = .ayu }

    // Each System/Light/Dark choice is applied and, because family and mode are
    // stored separately, never discards the chosen family.
    for mode in AppearanceConfiguration.Mode.allCases {
        model.update { $0.appearance.mode = mode }
        #expect(model.configuration.appearance.mode == mode)
        #expect(model.configuration.appearance.family == .ayu)
    }

    let reloaded = ConfigurationStore(configURL: controller.configURL)
    #expect(reloaded.load() == .loaded)
    #expect(reloaded.current.appearance.mode == AppearanceConfiguration.Mode.allCases.last)
    #expect(reloaded.current.appearance.family == .ayu)
}

@MainActor
@Test func paletteOverrideChangesTheAppliedResolvedPalette() throws {
    let (model, _) = try makeModel()
    model.update {
        $0.appearance.family = .tokyoNight
        $0.appearance.mode = .dark
    }
    let signatureAccent = try #require(model.resolvedTheme.tokens?.accent)

    model.update { $0.appearance.palette[.accent] = "#123456" }

    // The override is persisted and is what the resolved palette (and therefore
    // the bar) draws with, taking precedence over the family signature accent.
    #expect(model.configuration.appearance.palette[.accent] == "#123456")
    #expect(model.resolvedTheme.tokens?.accent == ThemeColor(hex: "#123456"))
    #expect(model.resolvedTheme.tokens?.accent != signatureAccent)
    #expect(model.resolvedAccentHex == "#123456")
}

// MARK: - Location Authorization

private let wifiNameDeniedMessage = "Location permission is needed to show the Wi-Fi name"

@MainActor
@Test func coreLocationStatusesMapToDivotAuthorizationStates() {
    // `.restricted` has no Divot state of its own; it is treated as denied so
    // the Settings row can explain and link out either way. macOS grants as
    // `authorizedAlways`; `authorizedWhenInUse` is iOS-only.
    #expect(CLAuthorizationStatus.notDetermined.toLocationAuthorizationStatus() == .notDetermined)
    #expect(CLAuthorizationStatus.restricted.toLocationAuthorizationStatus() == .denied)
    #expect(CLAuthorizationStatus.denied.toLocationAuthorizationStatus() == .denied)
    #expect(CLAuthorizationStatus.authorizedAlways.toLocationAuthorizationStatus() == .authorizedAlways)
}

@MainActor
@Test func wifiNamePermissionMessageMatchesEachAuthorizationState() throws {
    // not-determined and both granted flavors use caption copy; denied carries
    // the message and the button to open Location Services.
    let expectations: [(LocationAuthorizationStatus, String)] = [
        (.notDetermined, "Asking for location permission when you turn this on."),
        (.authorizedWhenInUse, "Location permission granted. Wi-Fi network name will appear when connected."),
        (.authorizedAlways, "Location permission granted. Wi-Fi network name will appear when connected."),
        (.denied, wifiNameDeniedMessage),
    ]

    for (status, message) in expectations {
        let (model, _) = try makeModel(locationTracker: StubLocationTracker(status: status))
        model.update { $0.widgets.network.showWifiName = true }

        #expect(model.locationAuthorizationStatus == status)
        #expect(model.wifiNamePermissionMessage == message)
        #expect(model.wifiNamePermissionOffersSettings == (status == .denied))
    }
}

@MainActor
@Test func restrictedLocationPermissionShowsTheDeniedSettingsMessage() throws {
    // CoreLocation reports restricted as its own status; the Settings row must
    // still show the denied message and the Location Services button.
    let restricted = CLAuthorizationStatus.restricted.toLocationAuthorizationStatus()
    let (model, _) = try makeModel(locationTracker: StubLocationTracker(status: restricted))
    model.update { $0.widgets.network.showWifiName = true }

    #expect(model.locationAuthorizationStatus == .denied)
    #expect(model.wifiNamePermissionMessage == wifiNameDeniedMessage)
    #expect(model.wifiNamePermissionOffersSettings)
}

@MainActor
@Test func settingsFollowsLocationAuthorizationChanges() async throws {
    let tracker = StubLocationTracker(status: .notDetermined)
    let (model, _) = try makeModel(locationTracker: tracker)

    tracker.push(.authorizedWhenInUse)
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(model.locationAuthorizationStatus == .authorizedWhenInUse)
    #expect(!model.wifiNamePermissionOffersSettings)

    tracker.push(.denied)
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(model.locationAuthorizationStatus == .denied)
    #expect(model.wifiNamePermissionOffersSettings)
}

@MainActor
@Test func wifiNameToggleOnlyRequestsLocationPermissionWhenTurnedOn() throws {
    let tracker = StubLocationTracker(status: .notDetermined)
    let (model, _) = try makeModel(locationTracker: tracker)

    // Opening Settings observes the status but must not prompt.
    #expect(tracker.requestCount == 0)

    // Writing the already-off toggle off stays silent.
    model.setShowWifiName(false)
    #expect(tracker.requestCount == 0)

    // Turning the feature on from off asks exactly once.
    model.setShowWifiName(true)
    #expect(model.configuration.widgets.network.showWifiName)
    #expect(tracker.requestCount == 1)

    // Turning it back off, then on again, is a fresh request only on the on.
    model.setShowWifiName(false)
    #expect(!model.configuration.widgets.network.showWifiName)
    #expect(tracker.requestCount == 1)
}

@MainActor
@Test func wifiNameLocationServicesURLOpensThePrivacyPane() {
    // The denied row's button opens this pane; the string is asserted so the
    // scheme cannot silently drift.
    #expect(DivotSettingsModel.locationServicesURL.absoluteString
        == "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
}
