import Foundation
import Testing
@testable import DivotCore

private func state(_ id: BarItemID, _ content: WidgetContent) -> WidgetState {
    WidgetState(id: id, revision: 1, content: content)
}

private let utc = TimeZone(identifier: "UTC")!
private let posix = Locale(identifier: "en_US_POSIX")
private let options = WidgetPresentationOptions(clock: ClockFormatOptions(),
                                                locale: posix, timeZone: utc)

@Test func batteryPresentationShowsPercentageAndPowerSymbols() {
    let half = WidgetPresenter.present(id: .battery,
                                       state: state(.battery, .battery(.init(presence: .internalBattery, percentage: 50))),
                                       options: options)
    #expect(half.text == "50%")
    #expect(half.symbolName == "battery.50")
    #expect(!half.isError)

    let charging = WidgetPresenter.present(id: .battery,
                                           state: state(.battery, .battery(.init(presence: .internalBattery, percentage: 80, isCharging: true))),
                                           options: options)
    #expect(charging.symbolName == "battery.100.bolt")
    #expect(charging.accessibilityLabel.contains("charging"))
}

@Test func desktopMacGetsASensibleNoBatteryPresentation() {
    let presentation = WidgetPresenter.present(id: .battery,
                                               state: state(.battery, .battery(.noBattery)),
                                               options: options)
    #expect(presentation.symbolName == "powerplug.fill")
    #expect(presentation.text.isEmpty)
    #expect(!presentation.isError)
    #expect(presentation.accessibilityLabel.contains("No battery"))
}

@Test func keepAwakeAddsTheIndicatorAndNeverChangesThePowerReading() {
    let on = WidgetPresenter.present(
        id: .battery,
        state: state(.battery, .battery(.init(presence: .internalBattery,
                                              percentage: 42,
                                              isKeepingAwake: true))),
        options: options)
    #expect(on.text == "42%")
    #expect(on.symbolName == "battery.50")
    #expect(on.indicator?.symbolName == "cup.and.saucer.fill")
    #expect(on.indicator?.role == .keepAwakeActive)
    #expect(on.accessibilityLabel.contains("keep awake on"))

    let off = WidgetPresenter.present(
        id: .battery,
        state: state(.battery, .battery(.init(presence: .internalBattery, percentage: 42))),
        options: options)
    #expect(off.indicator == nil)
    #expect(!off.accessibilityLabel.contains("keep awake"))
}

@Test func batteryPercentageIsShownByDefault() {
    let snapshot = BatterySnapshot(presence: .internalBattery, percentage: 75)
    let presentation = WidgetPresenter.present(
        id: .battery,
        state: state(.battery, .battery(snapshot)),
        options: options)
    #expect(presentation.text == "75%")
}

@Test func batteryPercentageHidesWhenOptionIsDisabled() {
    let snapshot = BatterySnapshot(presence: .internalBattery, percentage: 75)
    let hiddenOptions = WidgetPresentationOptions(
        clock: ClockFormatOptions(),
        battery: BatteryFormatOptions(showPercentage: false),
        locale: posix,
        timeZone: utc)
    let presentation = WidgetPresenter.present(
        id: .battery,
        state: state(.battery, .battery(snapshot)),
        options: hiddenOptions)
    #expect(presentation.text.isEmpty)
    #expect(presentation.symbolName == "battery.75")
    #expect(presentation.accessibilityLabel.contains("Battery 75%"))
}

@Test func networkPresentationReflectsTransportAndConnection() {
    let wifi = WidgetPresenter.present(id: .network,
                                       state: state(.network, .network(.init(isConnected: true, kind: .wifi))),
                                       options: options)
    #expect(wifi.symbolName == "wifi")
    #expect(!wifi.isError)

    let offline = WidgetPresenter.present(id: .network,
                                          state: state(.network, .network(.init(isConnected: false))),
                                          options: options)
    #expect(offline.symbolName == "wifi.slash")
    #expect(offline.isError)

    let metered = WidgetPresenter.present(id: .network,
                                          state: state(.network, .network(.init(isConnected: true, kind: .wifi, isExpensive: true))),
                                          options: options)
    #expect(metered.accessibilityLabel.contains("metered"))
}

@Test func networkPresentationShowsWifiNameWhenEnabled() {
    let optionsOff = WidgetPresentationOptions(clock: ClockFormatOptions(),
                                               network: NetworkFormatOptions(showWifiName: false),
                                               locale: posix, timeZone: utc)
    let hiddenName = WidgetPresenter.present(
        id: .network,
        state: state(.network, .network(.init(isConnected: true, kind: .wifi, wifiName: "MyNetwork"))),
        options: optionsOff)
    #expect(hiddenName.text.isEmpty)
    #expect(!hiddenName.accessibilityLabel.contains("MyNetwork"))

    let optionsOn = WidgetPresentationOptions(clock: ClockFormatOptions(),
                                              network: NetworkFormatOptions(showWifiName: true),
                                              locale: posix, timeZone: utc)
    let shownName = WidgetPresenter.present(
        id: .network,
        state: state(.network, .network(.init(isConnected: true, kind: .wifi, wifiName: "MyNetwork"))),
        options: optionsOn)
    #expect(shownName.text == "MyNetwork")
    #expect(shownName.accessibilityLabel.contains("Wi-Fi network: MyNetwork"))
}

@Test func networkPresentationWithoutNameShowsOnlyIcon() {
    let optionsOn = WidgetPresentationOptions(clock: ClockFormatOptions(),
                                              network: NetworkFormatOptions(showWifiName: true),
                                              locale: posix, timeZone: utc)
    let noName = WidgetPresenter.present(
        id: .network,
        state: state(.network, .network(.init(isConnected: true, kind: .wifi))),
        options: optionsOn)
    #expect(noName.text.isEmpty)
    #expect(noName.symbolName == "wifi")
}

@Test func networkPresentationIgnoresWifiNameOnNonWifiNetworks() {
    let optionsOn = WidgetPresentationOptions(clock: ClockFormatOptions(),
                                              network: NetworkFormatOptions(showWifiName: true),
                                              locale: posix, timeZone: utc)
    let ethernet = WidgetPresenter.present(
        id: .network,
        state: state(.network, .network(.init(isConnected: true, kind: .ethernet, wifiName: "MyNetwork"))),
        options: optionsOn)
    #expect(ethernet.text.isEmpty)
    #expect(ethernet.symbolName == "cable.connector")
}

@Test func volumePresentationCoversMuteAndNoOutput() {
    let muted = WidgetPresenter.present(id: .volume,
                                        state: state(.volume, .volume(.init(hasOutputDevice: true, level: 0.4, isMuted: true))),
                                        options: options)
    #expect(muted.symbolName == "speaker.slash.fill")
    #expect(muted.text == "Muted")

    let half = WidgetPresenter.present(id: .volume,
                                       state: state(.volume, .volume(.init(hasOutputDevice: true, level: 0.5))),
                                       options: options)
    #expect(half.symbolName == "speaker.wave.2.fill")
    #expect(half.text == "50%")

    let none = WidgetPresenter.present(id: .volume,
                                       state: state(.volume, .volume(.noOutput)),
                                       options: options)
    #expect(none.isError)
    #expect(none.accessibilityLabel.contains("No audio output"))
}

@Test func volumeOptionsControlPercentageAndMutedLabelIndependently() {
    let snapshot = VolumeSnapshot(hasOutputDevice: true, level: 0.5)

    // Both enabled (default)
    let both = WidgetPresenter.present(
        id: .volume,
        state: state(.volume, .volume(snapshot)),
        options: WidgetPresentationOptions(volume: VolumeFormatOptions(showPercent: true, showMuted: true)))
    #expect(both.text == "50%")

    // Percentage disabled
    let noPercent = WidgetPresenter.present(
        id: .volume,
        state: state(.volume, .volume(snapshot)),
        options: WidgetPresentationOptions(volume: VolumeFormatOptions(showPercent: false, showMuted: true)))
    #expect(noPercent.text == "")

    // Muted disabled (but volume is not muted)
    let noMutedLabel = WidgetPresenter.present(
        id: .volume,
        state: state(.volume, .volume(snapshot)),
        options: WidgetPresentationOptions(volume: VolumeFormatOptions(showPercent: true, showMuted: false)))
    #expect(noMutedLabel.text == "50%")
}

@Test func volumeOptionsHideMutedStateWhenDisabled() {
    let mutedSnapshot = VolumeSnapshot(hasOutputDevice: true, level: 0.5, isMuted: true)

    // Muted label enabled (default)
    let showMuted = WidgetPresenter.present(
        id: .volume,
        state: state(.volume, .volume(mutedSnapshot)),
        options: WidgetPresentationOptions(volume: VolumeFormatOptions(showPercent: true, showMuted: true)))
    #expect(showMuted.text == "Muted")

    // Muted label disabled
    let hideMuted = WidgetPresenter.present(
        id: .volume,
        state: state(.volume, .volume(mutedSnapshot)),
        options: WidgetPresentationOptions(volume: VolumeFormatOptions(showPercent: false, showMuted: false)))
    #expect(hideMuted.text == "")

    // Show percentage but muted - still shows percentage when muted
    let muteShowPercent = WidgetPresenter.present(
        id: .volume,
        state: state(.volume, .volume(mutedSnapshot)),
        options: WidgetPresentationOptions(volume: VolumeFormatOptions(showPercent: true, showMuted: false)))
    #expect(muteShowPercent.text == "")
}

@Test func clockPresentationUsesTheConfiguredLocaleAndZone() {
    let date = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13T12:26:40Z
    let presentation = WidgetPresenter.present(id: .clock,
                                               state: state(.clock, .clock(ClockSnapshot(date: date))),
                                               options: options)
    #expect(presentation.text.contains("Sun"))
    #expect(presentation.text.contains("12:26"))
}

@Test func frontAppPresentationUsesTheApplicationName() {
    let presentation = WidgetPresenter.present(
        id: .frontApp,
        state: state(.frontApp, .frontApp(FrontAppSnapshot(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"))),
        options: options)
    #expect(presentation.text == "Xcode")
    #expect(presentation.accessibilityLabel.contains("Xcode"))
}

@Test func frontAppOptionsControlNameAndIconIndependently() {
    let snapshot = FrontAppSnapshot(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")

    let nameOnly = WidgetPresenter.present(
        id: .frontApp,
        state: state(.frontApp, .frontApp(snapshot)),
        options: WidgetPresentationOptions(frontApp: FrontAppFormatOptions(showIcon: false, showName: true)))
    #expect(nameOnly.text == "Xcode")
    #expect(nameOnly.iconBundleIdentifier == nil)

    let iconOnly = WidgetPresenter.present(
        id: .frontApp,
        state: state(.frontApp, .frontApp(snapshot)),
        options: WidgetPresentationOptions(frontApp: FrontAppFormatOptions(showIcon: true, showName: false)))
    #expect(iconOnly.text == "")
    #expect(iconOnly.iconBundleIdentifier == "com.apple.dt.Xcode")
    // The name is still announced even when the label is hidden.
    #expect(iconOnly.accessibilityLabel.contains("Xcode"))
}

@Test func appearancePresentationShowsLightOrDarkMode() {
    let light = WidgetPresenter.present(
        id: .appearance,
        state: state(.appearance, .appearance(AppearanceSnapshot(mode: .light))),
        options: options)
    #expect(light.symbolName == "sun.max.fill")
    #expect(light.accessibilityLabel == "Light mode")
    #expect(light.text.isEmpty)

    let dark = WidgetPresenter.present(
        id: .appearance,
        state: state(.appearance, .appearance(AppearanceSnapshot(mode: .dark))),
        options: options)
    #expect(dark.symbolName == "moon.fill")
    #expect(dark.accessibilityLabel == "Dark mode")
    #expect(dark.text.isEmpty)
}

@Test func unavailableStatesAreHonestAndOnlyFailuresAreErrors() {
    let denied = WidgetPresenter.present(
        id: .network,
        state: state(.network, .unavailable(.init(kind: .permissionDenied, message: "Location permission denied"))),
        options: options)
    #expect(!denied.isError)
    #expect(denied.symbolName == "lock.fill")
    #expect(denied.accessibilityLabel == "Location permission denied")

    let failed = WidgetPresenter.present(
        id: .battery,
        state: state(.battery, .unavailable(.init(kind: .failed, message: "read failed"))),
        options: options)
    #expect(failed.isError)
}

@Test func missingItemsPresentAsLoadingExceptWorkspaces() {
    let loading = WidgetPresenter.present(id: .battery, state: nil, options: options)
    #expect(loading.text == "…")
    #expect(loading.accessibilityLabel.contains("Battery"))

    let workspaces = WidgetPresenter.present(id: .workspaces, state: nil, options: options)
    #expect(workspaces.text == "—")
    #expect(workspaces.accessibilityLabel.contains("No workspace manager"))
}

@Test func mismatchedStateIsTreatedAsMissing() {
    let wrong = WidgetPresenter.present(id: .clock,
                                        state: state(.battery, .battery(.noBattery)),
                                        options: options)
    #expect(wrong.text == "…")
}
