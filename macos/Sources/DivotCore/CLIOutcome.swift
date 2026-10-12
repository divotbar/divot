import Foundation

/// The result of one `divot` subcommand: text to print and the process exit
/// code. Keeping commands pure (no printing, no `exit`) makes their output
/// deterministic and testable, and lets `main.swift` own the process.
public struct CLIOutcome: Equatable, Sendable {
    public let output: String
    public let exitCode: Int32

    public init(output: String, exitCode: Int32 = 0) {
        self.output = output
        self.exitCode = exitCode
    }
}
