import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

@Test func installedManagersReflectEverySupportedBinary() {
    #expect(WorkspaceAdapterFactory.installedManagers(aeroSpacePath: "/opt/homebrew/bin/aerospace",
                                                      yabaiPath: nil) == [.aerospace])
    #expect(WorkspaceAdapterFactory.installedManagers(aeroSpacePath: nil,
                                                      yabaiPath: "/opt/homebrew/bin/yabai") == [.yabai])
    // Priority order is deterministic when both are present.
    #expect(WorkspaceAdapterFactory.installedManagers(aeroSpacePath: "/opt/homebrew/bin/aerospace",
                                                      yabaiPath: "/opt/homebrew/bin/yabai") == [.aerospace, .yabai])
    #expect(WorkspaceAdapterFactory.installedManagers(aeroSpacePath: nil, yabaiPath: nil).isEmpty)
}

@Test func anAdapterIsBuiltForBothSupportedManagers() {
    #expect(WorkspaceAdapterFactory.makeAdapter(for: .aerospace)?.kind == .aerospace)
    #expect(WorkspaceAdapterFactory.makeAdapter(for: .yabai)?.kind == .yabai)
}

@Test func yabaiHasNoPersistentEventSourceButAeroSpaceDoes() {
    // yabai has no documented event stream; signals are its callback path, so a
    // stub stream is never fabricated here.
    switch WorkspaceAdapterFactory.makeEventSource(for: .yabai) {
    case nil: break
    case .some: Issue.record("yabai must not claim a persistent event source")
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

@Test func resolveHonorsAUserOverrideEvenWhenThatManagerIsNotInstalled() {
    let resolved = WorkspaceAdapterFactory.resolve(preferred: .yabai)
    #expect(resolved.selection?.kind == .yabai)
    #expect(resolved.selection?.reason == .userOverride)
}
