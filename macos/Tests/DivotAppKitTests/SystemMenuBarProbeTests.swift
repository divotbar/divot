import CoreGraphics
import Testing
@testable import DivotAppKit

// MARK: - Missing / invalid AX attributes

@Test func completeSampleIsProvisionalUntilValidated() {
    let description = "position=(0.0, 0.0) size=(1710.0, 33.0) hidden=false"
    let shown = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                         size: CGSize(width: 1710, height: 33),
                                         hidden: false)
    #expect(shown == .provisional(visible: true, description: description))
    // A complete but unvalidated sample must never be decisive: it would move
    // panels on a false visibility claim.
    #expect(shown.accessibilityVisible == nil)
    #expect(shown.rawDerivedVisible == true)
    #expect(shown.isProvisional)
    #expect(shown.permissionGranted)

    // Only an explicitly validated sample is a decisive visibility.
    let validated = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                             size: CGSize(width: 1710, height: 33),
                                             hidden: false,
                                             validated: true)
    #expect(validated == .sampled(visible: true, description: description))
    #expect(validated.accessibilityVisible == true)
    #expect(!validated.isProvisional)
}

@Test func provisionalHiddenSampleStaysIndeterminate() {
    let hidden = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                          size: CGSize(width: 1710, height: 33),
                                          hidden: true)
    #expect(hidden.accessibilityVisible == nil)
    #expect(hidden.rawDerivedVisible == false)

    let validated = SystemMenuBarProbe.state(position: CGPoint(x: 0, y: 0),
                                             size: CGSize(width: 1710, height: 33),
                                             hidden: true,
                                             validated: true)
    #expect(validated.accessibilityVisible == false)
}

@Test func missingAttributesStayIndeterminate() {
    let size = CGSize(width: 1710, height: 33)
    let position = CGPoint(x: 0, y: 0)

    #expect(SystemMenuBarProbe.state(position: nil, size: size, hidden: false).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: position, size: nil, hidden: false).accessibilityVisible == nil)
    // A missing `hidden` must not default to `false` (which would claim visible).
    #expect(SystemMenuBarProbe.state(position: position, size: size, hidden: nil).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: nil, size: size, hidden: true).accessibilityVisible == nil)
}

@Test func emptyAreaIsIndeterminateNotHidden() {
    let position = CGPoint(x: 0, y: 0)
    #expect(SystemMenuBarProbe.state(position: position, size: .zero, hidden: false).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: position,
                                     size: CGSize(width: 0, height: 33),
                                     hidden: false).accessibilityVisible == nil)
    #expect(SystemMenuBarProbe.state(position: position,
                                     size: CGSize(width: 1710, height: 0),
                                     hidden: true).accessibilityVisible == nil)
}

@Test func unavailableStateReportsPermissionSeparately() {
    let state = SystemMenuBarProbe.state(position: nil, size: nil, hidden: nil)
    if case .unavailable = state {} else { Issue.record("expected unavailable, got \(state)") }
    // Trusted, just unusable: that is not the same as missing permission.
    #expect(state.permissionGranted)
}
