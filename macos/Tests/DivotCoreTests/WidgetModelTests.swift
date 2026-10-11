import Foundation
import Testing
@testable import DivotCore

// MARK: - Clock scheduling

@Test func clockWakesAtTheNextMinuteBoundary() {
    let base = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01T00:00:00Z
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base, seconds: false) == 60)
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base.addingTimeInterval(59.5), seconds: false) == 0.5)
    // Exactly on a boundary still moves forward, never a zero-length sleep.
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base.addingTimeInterval(60), seconds: false) == 60)
}

@Test func clockCanWakeAtSecondBoundaries() {
    let base = Date(timeIntervalSinceReferenceDate: 0)
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base, seconds: true) == 1)
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base.addingTimeInterval(0.25), seconds: true) == 0.75)
}

@Test func clockScheduleHandlesNonFiniteInput() {
    #expect(ClockSchedule.secondsUntilNextBoundary(after: Date(timeIntervalSinceReferenceDate: .infinity),
                                                   seconds: false) == 60)
}

// MARK: - Clock text

@Test func clockTemplateMatchesConfiguredComponents() {
    #expect(ClockText.template(ClockFormatOptions()) == "EEE MMMd jmm")
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: false, seconds: true)) == "jmms")
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: true)) == "MMMd jmm")
}

@Test func clockTextIsALocalizedDatePlusTime() {
    let date = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13T12:26:40Z
    let text = ClockText.string(for: ClockSnapshot(date: date),
                                options: ClockFormatOptions(seconds: false),
                                locale: Locale(identifier: "en_US_POSIX"),
                                timeZone: TimeZone(identifier: "UTC")!)
    // Weekday + abbreviated month/day + 24h time under POSIX.
    #expect(text.contains("Sun"))
    #expect(text.contains("Sep"))
    #expect(text.contains("13"))
    #expect(text.contains("12:26"))
}

@Test func timeFormatTemplate24Hour() {
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: false, seconds: false),
                              timeFormat: .twentyFourHour) == "HHmm")
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: false, seconds: true),
                              timeFormat: .twentyFourHour) == "HHmms")
}

@Test func timeFormatTemplateAMPM() {
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: false, seconds: false),
                              timeFormat: .ampm) == "jmm")
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: false, seconds: true),
                              timeFormat: .ampm) == "jmms")
}

@Test func timeFormatTemplateCustom() {
    #expect(ClockText.template(ClockFormatOptions(weekday: false, date: false, seconds: false),
                              timeFormat: .custom) == "jmm")
}

@Test func timeFormatTwentyFourHour() {
    let date = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13T12:26:40Z
    let text = ClockText.string(for: ClockSnapshot(date: date),
                                options: ClockFormatOptions(weekday: false, date: false, seconds: false),
                                locale: Locale(identifier: "en_US_POSIX"),
                                timeZone: TimeZone(identifier: "UTC")!,
                                timeFormat: .twentyFourHour)
    #expect(text == "12:26")
}

@Test func timeFormatAMPM() {
    let date = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13T12:26:40Z
    let text = ClockText.string(for: ClockSnapshot(date: date),
                                options: ClockFormatOptions(weekday: false, date: false, seconds: false),
                                locale: Locale(identifier: "en_US"),
                                timeZone: TimeZone(identifier: "UTC")!,
                                timeFormat: .ampm)
    #expect(text.contains("12:26"))
    #expect(text.contains("PM"))
}

@Test func customTimePatternValidation() {
    #expect(ClockText.isValidCustomPattern("HHmm"))
    #expect(ClockText.isValidCustomPattern("hh:mm a"))
    #expect(!ClockText.isValidCustomPattern(""))
    #expect(!ClockText.isValidCustomPattern("invalid pattern %%%"))
}

@Test func timeFormatCustomPattern() {
    let date = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13T12:26:40Z
    let text = ClockText.string(for: ClockSnapshot(date: date),
                                options: ClockFormatOptions(weekday: false, date: false, seconds: false),
                                locale: Locale(identifier: "en_US_POSIX"),
                                timeZone: TimeZone(identifier: "UTC")!,
                                timeFormat: .custom,
                                customTimePattern: "HH:mm:ss")
    #expect(text == "12:26:40")
}

// MARK: - Store

@Test func storeRejectsStaleGenerations() {
    var store = WidgetStore()
    let first = store.activate(.battery)
    let appliedFirst = store.apply(.battery(.noBattery), for: .battery, generation: first)
    #expect(appliedFirst)
    // Re-activating bumps the generation and clears prior state.
    let second = store.activate(.battery)
    #expect(second > first)
    #expect(store.state(for: .battery) == nil)
    // A completion from the old activation is ignored.
    let appliedStale = store.apply(.battery(.init(presence: .internalBattery, percentage: 5)),
                                   for: .battery, generation: first)
    #expect(!appliedStale)
    let appliedFresh = store.apply(.battery(.init(presence: .internalBattery, percentage: 80)),
                                   for: .battery, generation: second)
    #expect(appliedFresh)
}

@Test func storeRejectsEmissionsAfterDeactivation() {
    var store = WidgetStore()
    let generation = store.activate(.clock)
    store.deactivate(.clock)
    let applied = store.apply(.clock(ClockSnapshot(date: Date())), for: .clock, generation: generation)
    #expect(!applied)
    #expect(store.generation(of: .clock) == nil)
}

@Test func storeAssignsMonotonicRevisionsAndSortsStates() {
    var store = WidgetStore()
    let clockGen = store.activate(.clock)
    let batteryGen = store.activate(.battery)
    let appliedClock = store.apply(.clock(ClockSnapshot(date: Date(timeIntervalSinceReferenceDate: 0))),
                                   for: .clock, generation: clockGen)
    let appliedBattery = store.apply(.battery(.noBattery), for: .battery, generation: batteryGen)
    #expect(appliedClock)
    #expect(appliedBattery)
    let states = store.states
    #expect(states.map(\.id) == [.battery, .clock])
    // Clock was activated first, so it carries the earlier revision even
    // though states are sorted by id for stable rendering.
    #expect(states.first { $0.id == .clock }!.revision < states.first { $0.id == .battery }!.revision)
}

@Test func storeRejectsContentThatDoesNotFitTheItem() {
    var store = WidgetStore()
    let gen = store.activate(.battery)
    // A battery provider must never paint clock content.
    let appliedClock = store.apply(.clock(ClockSnapshot(date: Date())), for: .battery, generation: gen)
    #expect(!appliedClock)
    #expect(store.state(for: .battery) == nil)
    // An unavailable state is always allowed and contextual.
    let appliedUnavailable = store.apply(.unavailable(.init(kind: .permissionDenied, message: "denied")),
                                         for: .battery, generation: gen)
    #expect(appliedUnavailable)
}

// MARK: - Coalescing

@Test func coalescerCollapsesRepeatedIds() {
    var coalescer = WidgetUpdateCoalescer()
    #expect(coalescer.isEmpty)
    coalescer.mark(.battery)
    coalescer.mark(.clock)
    coalescer.mark(.battery)
    #expect(!coalescer.isEmpty)
    let drained = coalescer.drain()
    #expect(drained == [.battery, .clock])
    #expect(coalescer.isEmpty)
    let again = coalescer.drain()
    #expect(again.isEmpty)
}

// MARK: - Content compatibility

@Test func contentCompatibilityMatchesItem() {
    #expect(WidgetContent.battery(.noBattery).isCompatible(with: .battery))
    #expect(!WidgetContent.battery(.noBattery).isCompatible(with: .clock))
    #expect(WidgetContent.clock(ClockSnapshot(date: Date())).isCompatible(with: .clock))
    #expect(WidgetContent.unavailable(.init(kind: .noData, message: "x")).isCompatible(with: .workspaces))
}

// MARK: - Battery states

@Test func batterySnapshotClampsPercentageAndHasADesktopState() {
    let clamped = BatterySnapshot(presence: .internalBattery, percentage: 240)
    #expect(clamped.percentage == 100)
    #expect(BatterySnapshot.noBattery.presence == .none)
    #expect(BatterySnapshot.noBattery.percentage == nil)
}

@Test func volumeSnapshotClampsLevelAndHasANoOutputState() {
    #expect(VolumeSnapshot(hasOutputDevice: true, level: 4).level == 1)
    #expect(VolumeSnapshot(hasOutputDevice: true, level: -1).level == 0)
    #expect(!VolumeSnapshot.noOutput.hasOutputDevice)
}

// MARK: - Layout

@Test func defaultLayoutMatchesTheFirstLaunchStory() {
    #expect(BarLayout.default.left == [.workspaces, .frontApp])
    #expect(BarLayout.default.right == [.battery, .time, .network, .volume])
    #expect(BarLayout.default.side(of: .frontApp) == .left)
    #expect(BarLayout.default.side(of: .volume) == .right)
}

@Test func layoutItemsFollowThePlacedSide() {
    let layout = BarLayout(left: [.clock], right: [.network])
    #expect(layout.items(on: .left) == [.clock])
    #expect(layout.items(on: .right) == [.network])
    #expect(layout.side(of: .battery) == nil)
}

@Test func settingsItemsReplaceTheLegacyClockWithDateAndTime() {
    #expect(BarItemID.placeableItems.contains(.date))
    #expect(BarItemID.placeableItems.contains(.time))
    // The combined clock is kept only so older documents can migrate.
    #expect(!BarItemID.placeableItems.contains(.clock))
    #expect(BarItemID.placeableItems.count == BarItemID.allCases.count - 1)
}

// MARK: - Actions

@Test func defaultActionsOpenHonestSettingsLinks() {
    // The battery item toggles keep-awake (task 0018) instead of opening a pane.
    #expect(WidgetActions.defaultAction(for: .battery) == .toggleKeepAwake)
    #expect(WidgetActions.defaultAction(for: .network) == .openSettings(.network))
    #expect(WidgetActions.defaultAction(for: .volume) == .openSettings(.sound))
    #expect(WidgetActions.defaultAction(for: .clock) == .openSettings(.dateTime))
    // The split items open the same Date & Time pane as the old clock.
    #expect(WidgetActions.defaultAction(for: .date) == .openSettings(.dateTime))
    #expect(WidgetActions.defaultAction(for: .time) == .openSettings(.dateTime))
    // Workspaces are the adapter milestone's actions, never a fake sample.
    #expect(WidgetActions.defaultAction(for: .workspaces) == .none)
}

@Test func clockScheduleFindsTheNextMinuteSecondAndDayBoundary() {
    let base = Date(timeIntervalSinceReferenceDate: 0)
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base, seconds: false) == 60)
    #expect(ClockSchedule.secondsUntilNextBoundary(after: base, seconds: true) == 1)

    // A fixed calendar keeps the day-boundary arithmetic deterministic.
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let noon = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 08:00:00 UTC
    let toMidnight = ClockSchedule.secondsUntilNextDayBoundary(after: noon, calendar: calendar)
    #expect(toMidnight > 0)
    #expect(toMidnight <= 24 * 60 * 60)
    #expect(calendar.date(byAdding: .second, value: Int(toMidnight), to: noon).map {
        calendar.component(.hour, from: $0) == 0
    } == true)
}

@Test func keepAwakeToggleDoesNotDependOnTheBatteryReading() {
    let charging = WidgetContent.battery(.init(presence: .internalBattery, percentage: 80, isCharging: true))
    let none = WidgetContent.battery(.noBattery)
    #expect(WidgetActions.defaultAction(for: .battery, content: charging) == .toggleKeepAwake)
    #expect(WidgetActions.defaultAction(for: .battery, content: none) == .toggleKeepAwake)
}

@Test func frontAppActionNeedsALiveBundleIdentifier() {
    let snapshot = FrontAppSnapshot(name: "Safari", bundleIdentifier: "com.apple.Safari")
    #expect(WidgetActions.defaultAction(for: .frontApp, content: .frontApp(snapshot))
            == .activateApplication(bundleIdentifier: "com.apple.Safari"))
    let anonymous = FrontAppSnapshot(name: "Unknown")
    #expect(WidgetActions.defaultAction(for: .frontApp, content: .frontApp(anonymous)) == .none)
}

@Test func everySettingsPaneHasACandidateLink() {
    for pane in WidgetSettingsPane.allCases {
        let url = try! #require(pane.url)
        #expect(url.scheme == "x-apple.systempreferences")
    }
}
