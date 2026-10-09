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
