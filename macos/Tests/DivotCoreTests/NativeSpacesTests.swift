import CoreGraphics
import Foundation
import Testing
@testable import DivotCore

// MARK: - Fixtures

private let primary = NativeSpaceDisplay(id: 1,
                                         name: "Built-in",
                                         frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
                                         visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1074),
                                         isMain: true)

private let secondary = NativeSpaceDisplay(id: 2,
                                           name: "Studio Display",
                                           frame: CGRect(x: 1710, y: 0, width: 2560, height: 1440),
                                           visibleFrame: CGRect(x: 1710, y: 0, width: 2560, height: 1440))

private func window(_ number: Int,
                    _ name: String,
                    bundle: String,
                    pid: Int,
                    centerX: Double,
                    centerY: Double) -> NativeSpaceWindow {
    NativeSpaceWindow(windowNumber: number,
                      ownerName: name,
                      bundleID: bundle,
                      pid: pid,
                      bounds: CGRect(x: centerX - 100, y: centerY - 100, width: 200, height: 200))
}

// MARK: - Capability report

@Test func onlyDisplayReadsAndTheChangeEventArePubliclyAchievable() {
    let achievable = Set(NativeSpacesCapabilities.publiclyAchievable.map(\.operation))
    #expect(achievable == [.listDisplays, .mapAppsToDisplays, .observeActiveSpaceChange])
}

@Test func everyNativeWorkspaceOperationIsPrivateOrUnavailable() {
    let unavailable = Set(NativeSpacesCapabilities.notPubliclyAchievable.map(\.operation))
    #expect(unavailable == [.listSpaces, .switchToSpace, .mapAppsToSpaces, .perDisplaySpaces])
    // The heart of the research: no supported path lists or switches Spaces.
    for operation in [NativeSpacesOperation.listSpaces, .switchToSpace, .mapAppsToSpaces, .perDisplaySpaces] {
        #expect(!NativeSpacesCapabilities.capability(for: operation).support.isPubliclyAchievable)
    }
}

@Test func spaceChangeNotificationCarriesNoIdentity() {
    let capability = NativeSpacesCapabilities.capability(for: .observeActiveSpaceChange)
    #expect(capability.support == .publicAPIWithoutSpaceIdentity)
    #expect(capability.support.isPubliclyAchievable)
}

@Test func capabilityTableCoversEveryOperationExactlyOnce() {
    let operations = NativeSpacesCapabilities.publicAPIOnly.map(\.operation)
    #expect(Set(operations) == Set(NativeSpacesOperation.allCases))
    #expect(operations.count == NativeSpacesOperation.allCases.count)
    for operation in NativeSpacesOperation.allCases {
        #expect(NativeSpacesCapabilities.capability(for: operation).operation == operation)
    }
}

@Test func nativeSpacesIsNotASelectedWorkspaceManager() {
    // No `nativeSpaces` case may be smuggled into the manager selection to claim
    // parity: AeroSpace then yabai remain the only adapters.
    #expect(WorkspaceManagerKind.selectionPriority == [.aerospace, .yabai])
    #expect(WorkspaceManagerKind.allCases.count == 2)
}

// MARK: - Observation model

@Test func spacesAreHonestlyUnavailableNeverAnEmptyList() {
    let observation = NativeSpaceObservation(displays: [primary], windows: [])
    #expect(!observation.spaceListing.isAvailable)
    #expect(observation.spaceListing.spaces.isEmpty)
    guard case .unavailable(let reason) = observation.spaceListing else {
        Issue.record("expected unavailable")
        return
    }
    #expect(!reason.isEmpty)
}

@Test func mapsWindowsToTheDisplayContainingTheirCenter() {
    let near = window(1, "Safari", bundle: "com.apple.Safari", pid: 10, centerX: 800, centerY: 500)
    let far = window(2, "Xcode", bundle: "com.apple.dt.Xcode", pid: 11, centerX: 1710 + 1200, centerY: 700)
    let observation = NativeSpaceObservation(displays: [primary, secondary], windows: [near, far])

    #expect(observation.isMultiDisplay)
    #expect(observation.windows(on: primary).map { $0.windowNumber } == [1])
    #expect(observation.windows(on: secondary).map { $0.windowNumber } == [2])
    #expect(observation.apps(on: primary) == [WorkspaceAppIdentity(bundleID: "com.apple.Safari", name: "Safari")])
    #expect(observation.apps(on: secondary) == [WorkspaceAppIdentity(bundleID: "com.apple.dt.Xcode", name: "Xcode")])
}

@Test func deduplicatesAppsPerDisplayByBundleIdentity() {
    let one = window(1, "Terminal", bundle: "com.apple.Terminal", pid: 20, centerX: 300, centerY: 300)
    let two = window(2, "Terminal", bundle: "com.apple.Terminal", pid: 20, centerX: 700, centerY: 400)
    let observation = NativeSpaceObservation(displays: [primary], windows: [one, two])

    #expect(observation.windows(on: primary).count == 2)
    #expect(observation.apps(on: primary).count == 1)
    #expect(observation.allApps.count == 1)
}

@Test func aWindowWhoseCenterIsOffEveryDisplayIsNotGuessedAtASpace() {
    // Mirrors the probe run: a window parked beyond the right edge is on-screen
    // yet maps to no display, and there is no public Space to attribute it to.
    let offscreen = window(9, "Chrome", bundle: "com.google.Chrome", pid: 30, centerX: 1710 + 500, centerY: -500)
    let observation = NativeSpaceObservation(displays: [primary], windows: [offscreen])

    #expect(observation.windows(on: primary).isEmpty)
    #expect(observation.display(containing: CGPoint(x: offscreen.bounds.midX, y: offscreen.bounds.midY)) == nil)
    #expect(observation.allApps.count == 1)
}

@Test func identityFallsBackToOwnerNameWhenBundleIDIsMissing() {
    let unnamed = NativeSpaceWindow(windowNumber: 5, ownerName: "Widget", bundleID: "", pid: 40)
    let observation = NativeSpaceObservation(displays: [primary], windows: [unnamed])
    #expect(observation.allApps == [WorkspaceAppIdentity(bundleID: "", name: "Widget")])
    #expect(observation.allApps[0].dedupKey == "name:Widget")
}
