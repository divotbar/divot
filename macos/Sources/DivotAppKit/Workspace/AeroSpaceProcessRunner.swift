import Foundation
import DivotCore

/// Runs one bounded AeroSpace command as a short-lived subprocess.
///
/// The command runs off the main thread with a hard timeout, so a hung manager
/// can never freeze the bar. Cancelling the calling task terminates the
/// process, so a reconfigured feed does not leave a CLI command running until
/// its timeout.
public struct ProcessWorkspaceRunner: WorkspaceProcessRunning {
    public init() {}

    public func run(_ command: WorkspaceCommand) async throws -> WorkspaceCommandResult {
        let running = RunningProcess(command: command)
        return try await withTaskCancellationHandler {
            try await running.waitForExit()
        } onCancel: {
            running.cancel()
        }
    }
}

/// One spawned process with timeout, cancellation and single-shot completion.
///
/// All mutable state is guarded by `lock`; the process is only started, read,
/// terminated and force-killed through this type, so it is safe to hand a
/// reference to the cancellation handler.
private final class RunningProcess: @unchecked Sendable {
    private let command: WorkspaceCommand
    private let process = Process()
    private let stdout = Pipe()
    private let stderr = Pipe()

    private let lock = NSLock()
    private var continuation: CheckedContinuation<WorkspaceCommandResult, Error>?
    private var pendingResult: Result<WorkspaceCommandResult, Error>?
    private var timedOut = false
    private var cancelled = false
    private var finished = false
    private var watchdog: DispatchWorkItem?

    init(command: WorkspaceCommand) {
        self.command = command
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardOutput = stdout
        process.standardError = stderr
    }

    func waitForExit() async throws -> WorkspaceCommandResult {
        try start()
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let pendingResult {
                lock.unlock()
                continuation.resume(with: pendingResult)
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    /// Terminate the process because its task was cancelled.
    func cancel() {
        lock.lock()
        cancelled = true
        let running = process.isRunning
        lock.unlock()
        if running { process.terminate() }
    }

    // MARK: Private

    private func start() throws {
        process.terminationHandler = { [weak self] finishedProcess in
            self?.finish(exitCode: finishedProcess.terminationStatus)
        }
        do {
            try process.run()
        } catch {
            throw WorkspaceAdapterError.commandFailed(command: command.displayName,
                                                      exitCode: -1,
                                                      stderr: error.localizedDescription)
        }
        let watchdog = DispatchWorkItem { [weak self] in self?.fireTimeout() }
        self.watchdog = watchdog
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + command.timeout, execute: watchdog)
    }

    private func fireTimeout() {
        lock.lock()
        timedOut = true
        let running = process.isRunning
        lock.unlock()
        guard running else { return }
        process.terminate()
        // If the process ignores SIGTERM, force it down so the read below can
        // never block forever.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.process.isRunning else { return }
            kill(self.process.processIdentifier, SIGKILL)
        }
    }

    private func finish(exitCode: Int32) {
        watchdog?.cancel()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        let result: Result<WorkspaceCommandResult, Error>
        lock.lock()
        let didTimeOut = timedOut
        let wasCancelled = cancelled
        lock.unlock()

        if didTimeOut {
            result = .failure(WorkspaceAdapterError.timedOut(command: command.displayName))
        } else if wasCancelled {
            result = .failure(WorkspaceAdapterError.cancelled)
        } else {
            result = .success(WorkspaceCommandResult(exitCode: exitCode,
                                                     stdout: String(decoding: outData, as: UTF8.self),
                                                     stderr: String(decoding: errData, as: UTF8.self)))
        }

        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        if continuation == nil { pendingResult = result }
        lock.unlock()
        continuation?.resume(with: result)
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
