import Foundation
import Testing
import DivotCore
@testable import DivotAppKit

// MARK: - Binary location

@Test func candidatePathsPreferPathThenHomebrewAndDeduplicate() {
    let candidates = AeroSpaceBinaryLocator.candidatePaths(environment: ["PATH": "/usr/bin:/usr/local/bin"],
                                                           homeDirectory: "/Users/x")
    #expect(candidates.first == "/usr/bin/aerospace")
    #expect(candidates.contains("/opt/homebrew/bin/aerospace"))
    #expect(candidates.last == "/Users/x/.local/bin/aerospace")
    // /usr/local/bin comes from both PATH and the fallback; it appears once.
    #expect(Set(candidates).count == candidates.count)
}

@Test func locateReturnsTheFirstExistingCandidate() {
    let found = AeroSpaceBinaryLocator.locate(fileExists: { $0 == "/opt/homebrew/bin/aerospace" },
                                              environment: [:],
                                              homeDirectory: "/Users/x")
    #expect(found == "/opt/homebrew/bin/aerospace")
}

@Test func locateReturnsNilWhenNoCandidateExists() {
    let found = AeroSpaceBinaryLocator.locate(fileExists: { _ in false },
                                              environment: [:],
                                              homeDirectory: "/Users/x")
    #expect(found == nil)
}

// MARK: - Subscription line buffering

@Test func lineBufferReassemblesALineSplitAcrossChunks() {
    let buffer = SubscriptionLineBuffer()
    #expect(buffer.consume("{\"_event\":\"focus").isEmpty)
    let lines = buffer.consume("-changed\",\"workspace\":\"1\"}\n{\"_event\":\"mode")
    #expect(lines == ["{\"_event\":\"focus-changed\",\"workspace\":\"1\"}"])
    let remaining = buffer.consume("-changed\",\"mode\":\"main\"}\n")
    #expect(remaining == ["{\"_event\":\"mode-changed\",\"mode\":\"main\"}"])
}

@Test func lineBufferKeepsOnlyCompleteLines() {
    let buffer = SubscriptionLineBuffer()
    let lines = buffer.consume("a\nb\npartial")
    #expect(lines == ["a", "b"])
    #expect(buffer.consume(" rest\n") == ["partial rest"])
}

// MARK: - Process runner

@Test func runnerCapturesStdoutAndExitCode() async throws {
    let result = try await ProcessWorkspaceRunner().run(
        WorkspaceCommand(executable: "/bin/echo", arguments: ["hello"], timeout: 5))
    #expect(result.succeeded)
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
}

@Test func runnerSurfacesANonZeroExitWithoutThrowing() async throws {
    let result = try await ProcessWorkspaceRunner().run(
        WorkspaceCommand(executable: "/bin/sh", arguments: ["-c", "exit 3"], timeout: 5))
    #expect(!result.succeeded)
    #expect(result.exitCode == 3)
}

@Test func runnerTimesOutAHangingCommand() async {
    await #expect(throws: WorkspaceAdapterError.self) {
        _ = try await ProcessWorkspaceRunner().run(
            WorkspaceCommand(executable: "/bin/sleep", arguments: ["5"], timeout: 0.3))
    }
}
