import Testing
import Foundation
import Darwin
import DivotCore
@testable import DivotAppKit

@Suite("Snapshot filter helpers")
struct SnapshotTestHelpersTests {

    @Test("parseSnapshotFilter returns empty when DIVOT_SNAPSHOT_ONLY is not set")
    @MainActor
    func parseFilterUnset() {
        let (tokens, message, active) = SnapshotTestHelpers.parseSnapshotFilter()
        #expect(tokens.isEmpty)
        #expect(message == nil)
        #expect(!active)
    }

    @Test("parseSnapshotFilter returns tokens when DIVOT_SNAPSHOT_ONLY is set")
    @MainActor
    func parseFilterSingleToken() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "worldclock", 1)
        let (tokens, message, active) = SnapshotTestHelpers.parseSnapshotFilter()
        #expect(tokens == ["worldclock"])
        #expect(message == nil)
        #expect(active)
    }

    @Test("parseSnapshotFilter splits comma-separated tokens")
    @MainActor
    func parseFilterMultipleTokens() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "wifi,volume,appearance", 1)
        let (tokens, message, active) = SnapshotTestHelpers.parseSnapshotFilter()
        #expect(tokens == ["wifi", "volume", "appearance"])
        #expect(message == nil)
        #expect(active)
    }

    @Test("parseSnapshotFilter trims whitespace from tokens")
    @MainActor
    func parseFilterTrimsWhitespace() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "wifi , volume , appearance", 1)
        let (tokens, message, active) = SnapshotTestHelpers.parseSnapshotFilter()
        #expect(tokens == ["wifi", "volume", "appearance"])
        #expect(message == nil)
        #expect(active)
    }

    @Test("parseSnapshotFilter detects empty token string")
    @MainActor
    func parseFilterEmpty() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "", 1)
        let (tokens, message, active) = SnapshotTestHelpers.parseSnapshotFilter()
        #expect(tokens.isEmpty)
        #expect(message == nil)
        #expect(!active)
    }

    @Test("matchesSnapshotFilter returns true when filter is not set")
    @MainActor
    func matchesFilterUnset() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        unsetenv("DIVOT_SNAPSHOT_ONLY")
        #expect(SnapshotTestHelpers.matchesSnapshotFilter(named: "anything"))
    }

    @Test("matchesSnapshotFilter matches token in filename")
    @MainActor
    func matchesFilterToken() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "worldclock", 1)
        #expect(SnapshotTestHelpers.matchesSnapshotFilter(named: "worldclock-popover-native-light-default"))
        #expect(SnapshotTestHelpers.matchesSnapshotFilter(named: "worldclock-popover-native-dark-default-two-timezones"))
        #expect(!SnapshotTestHelpers.matchesSnapshotFilter(named: "volume-popover-native-light-default"))
    }

    @Test("matchesSnapshotFilter matches any of multiple tokens")
    @MainActor
    func matchesFilterMultipleTokens() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "wifi,volume", 1)
        #expect(SnapshotTestHelpers.matchesSnapshotFilter(named: "wifi-popover-native-light-default"))
        #expect(SnapshotTestHelpers.matchesSnapshotFilter(named: "volume-popover-native-light-default"))
        #expect(SnapshotTestHelpers.matchesSnapshotFilter(named: "wifi-permission-popover-native-light-default"))
        #expect(!SnapshotTestHelpers.matchesSnapshotFilter(named: "appearance-popover-native-light-default"))
        #expect(!SnapshotTestHelpers.matchesSnapshotFilter(named: "bar-right-native-light-default-chips-off"))
    }

    @Test("wantsPNG integrates filter with set logic")
    @MainActor
    func wantsPNGIntegration() {
        let originalEnv = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_ONLY"]
        let originalSet = ProcessInfo.processInfo.environment["DIVOT_SNAPSHOT_SET"]
        defer {
            if let value = originalEnv {
                setenv("DIVOT_SNAPSHOT_ONLY", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_ONLY")
            }
            if let value = originalSet {
                setenv("DIVOT_SNAPSHOT_SET", value, 1)
            } else {
                unsetenv("DIVOT_SNAPSHOT_SET")
            }
        }

        setenv("DIVOT_SNAPSHOT_ONLY", "worldclock", 1)
        unsetenv("DIVOT_SNAPSHOT_SET")

        // Filter matches but full matrix is enabled
        #expect(SnapshotTestHelpers.wantsPNG(named: "worldclock-popover-native-light-default"))
        #expect(SnapshotTestHelpers.wantsPNG(named: "worldclock-popover-gruvbox-dark-large"))
        // Filter doesn't match
        #expect(!SnapshotTestHelpers.wantsPNG(named: "volume-popover-native-light-default"))
    }
}
