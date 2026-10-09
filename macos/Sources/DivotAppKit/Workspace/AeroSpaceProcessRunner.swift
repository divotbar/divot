import Foundation
import DivotCore

/// Runs one bounded AeroSpace command as a short-lived subprocess.
///
/// The command runs off the main thread with a hard timeout, so a hung manager
/// can never freeze the bar. Output is small (a workspace/window listing), so
/// reading to EOF after exit is safe.
public struct ProcessWorkspaceRunner: WorkspaceProcessRunning {
    public init() {}

    public func run(_ command: WorkspaceCommand) async throws -> WorkspaceCommandResult {
        try await Task.detached(priority: .utility) {
            try ProcessWorkspaceRunner.runSynchronously(command)
        }.value
    }

    static func runSynchronously(_ command: WorkspaceCommand) throws -> WorkspaceCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw WorkspaceAdapterError.commandFailed(command: command.displayName,
                                                      exitCode: -1,
                                                      stderr: error.localizedDescription)
        }

        let box = ProcessBox(process)
        let timedOut = TimeoutFlag()
        let watchdog = DispatchWorkItem {
            guard box.process.isRunning else { return }
            timedOut.markTimedOut()
            box.process.terminate()
            // If a process ignores SIGTERM, force it down shortly after so the
            // read below can never block forever.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                if box.process.isRunning { kill(box.process.processIdentifier, SIGKILL) }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + command.timeout, execute: watchdog)

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        if timedOut.value {
            throw WorkspaceAdapterError.timedOut(command: command.displayName)
        }

        return WorkspaceCommandResult(exitCode: process.terminationStatus,
                                      stdout: String(decoding: outData, as: UTF8.self),
                                      stderr: String(decoding: errData, as: UTF8.self))
    }
}

/// `Process` is not `Sendable`; the watchdog only reads `isRunning`, terminates,
/// and force-kills it, which the OS serializes safely.
private final class ProcessBox: @unchecked Sendable {
    let process: Process
    init(_ process: Process) { self.process = process }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var marked = false

    func markTimedOut() {
        lock.lock()
        marked = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return marked
    }
}

/// Locates the `aerospace` executable.
///
/// GUI apps do not inherit a shell's `PATH`, so the Homebrew prefixes are always
/// considered. The existence check is injectable so the ordering is testable
/// without touching the real filesystem.
public enum AeroSpaceBinaryLocator {
    public static let executableName = "aerospace"

    public static func candidatePaths(environment: [String: String] = ProcessInfo.processInfo.environment,
                                      homeDirectory: String = NSHomeDirectory()) -> [String] {
        var candidates: [String] = []
        if let path = environment["PATH"] {
            for directory in path.split(separator: ":") where !directory.isEmpty {
                candidates.append("\(directory)/\(executableName)")
            }
        }
        candidates.append("/opt/homebrew/bin/\(executableName)")
        candidates.append("/usr/local/bin/\(executableName)")
        candidates.append("\(homeDirectory)/.local/bin/\(executableName)")

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    public static func locate(fileExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
                              environment: [String: String] = ProcessInfo.processInfo.environment,
                              homeDirectory: String = NSHomeDirectory()) -> String? {
        candidatePaths(environment: environment, homeDirectory: homeDirectory).first(where: fileExists)
    }
}
