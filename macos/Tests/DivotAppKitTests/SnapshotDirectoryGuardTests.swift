import Foundation
import Testing
@testable import DivotAppKit

/// Negative cases for the never-commit guard on `DIVOT_SNAPSHOT_DIR`: rendered
/// images may only go to an ignored location, so tracked-looking paths and
/// near-miss names must be refused.
@MainActor
@Suite("Snapshot directory guard")
struct SnapshotDirectoryGuardTests {

    private func withShotDir(_ value: String?, _ body: () -> Void) {
        let key = "REPOOS_SHOT_DIR"
        let previous = ProcessInfo.processInfo.environment[key]
        if let value { setenv(key, value, 1) } else { unsetenv(key) }
        defer { if let previous { setenv(key, previous, 1) } else { unsetenv(key) } }
        body()
    }

    @Test("Accepts .build and snapshots directories")
    func acceptsIgnoredPaths() {
        withShotDir(nil) {
            #expect(SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: "/repo/macos/.build/snapshots")))
            #expect(SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: "/repo/macos/.build/debug/out")))
            #expect(SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: "/tmp/run/snapshots")))
        }
    }

    @Test("Refuses tracked-looking paths and near-miss names")
    func refusesTrackedPaths() {
        withShotDir(nil) {
            for path in ["/repo/macos/Tests", "/repo/docs", "/repo/work", "/tmp/x-snapshots",
                         "/tmp/snapshots-old/out", "/repo/macos/build", "/repo/work/.attachments/0081/shots/cmd"] {
                #expect(!SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: path)), "\(path) must be refused")
            }
        }
    }

    @Test("REPOOS_SHOT_DIR is accepted only on an exact match under .attachments")
    func repoosShotDirNeedsExactMatch() {
        let shot = "/repo/work/.attachments/0081/shots/cmd"
        withShotDir(shot) {
            #expect(SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: shot)))
            #expect(!SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: shot + "/../other")))
            #expect(!SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: "/repo/macos/Tests")))
        }
        withShotDir("/repo/docs") {
            #expect(!SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: "/repo/docs")),
                    "a REPOOS_SHOT_DIR outside .attachments must not unlock a tracked path")
        }
        withShotDir("") {
            #expect(!SnapshotTestHelpers.isIgnoredLocation(URL(fileURLWithPath: "/repo/docs")))
        }
    }
}
