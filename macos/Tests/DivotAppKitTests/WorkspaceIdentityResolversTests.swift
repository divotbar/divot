import Testing
import DivotCore
@testable import DivotAppKit

// MARK: - Display index resolver

@Test func screenDisplayResolverMapsOneBasedScreenIndices() {
    // Display ids in NSScreen.screens order; positions are 1-based.
    let resolver = ScreenDisplayIndexResolver(displayIDs: [7, nil, 42])
    #expect(resolver.screenIndex(forDisplayIdentifier: 7) == 1)
    #expect(resolver.screenIndex(forDisplayIdentifier: 42) == 3)
    #expect(resolver.screenIndex(forDisplayIdentifier: 99) == nil)
    #expect(resolver.screenIndex(forDisplayIdentifier: 0) == nil)
}

@Test func screenDisplayResolverIsEmptyWithoutDisplays() {
    let resolver = ScreenDisplayIndexResolver(displayIDs: [])
    #expect(resolver.screenIndex(forDisplayIdentifier: 1) == nil)
}

// MARK: - Process identity resolver

@Test func processIdentityResolverRejectsNonPositivePIDs() {
    // The live resolver must never query the running-application list with a
    // sentinel pid; an unknown process is simply no icon.
    #expect(RunningApplicationIdentityResolver().bundleIdentifier(forProcessID: 0) == nil)
    #expect(RunningApplicationIdentityResolver().bundleIdentifier(forProcessID: -1) == nil)
}
