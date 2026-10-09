import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

@Test func aeroSpaceIsTheOnlyInstalledManagerToday() {
    #expect(WorkspaceAdapterFactory.installedManagers(aeroSpacePath: "/opt/homebrew/bin/aerospace") == [.aerospace])
    #expect(WorkspaceAdapterFactory.installedManagers(aeroSpacePath: nil).isEmpty)
}

@Test func aeroSpaceAdapterIsBuiltForTheSelectedManager() {
    let adapter = WorkspaceAdapterFactory.makeAdapter(for: .aerospace)
    #expect(adapter?.kind == .aerospace)
}

@Test func yabaiHasNoAdapterOrEventSourceYet() {
    switch WorkspaceAdapterFactory.makeAdapter(for: .yabai) {
    case nil: break
    case .some: Issue.record("yabai must not claim an adapter before its milestone")
    }
    switch WorkspaceAdapterFactory.makeEventSource(for: .yabai) {
    case nil: break
    case .some: Issue.record("yabai must not claim an event source before its milestone")
    }
}

@Test func resolveWithoutAManagerYieldsTheHonestUnavailablePath() {
    let resolved = WorkspaceAdapterFactory.resolve(preferred: nil)
    // No runner is exercised here; with no located installer the selection is
    // nil and the feed renders the unavailable state rather than fake spaces.
    if WorkspaceAdapterFactory.installedManagers().isEmpty {
        #expect(resolved.selection == nil)
        switch resolved.adapter {
        case nil: break
        case .some: Issue.record("no adapter should be built when no manager is installed")
        }
    }
}
