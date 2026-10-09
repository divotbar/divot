import Foundation
import DivotCore

/// A persistent `aerospace subscribe` connection bridged to an `AsyncStream`.
///
/// This is the event-driven path the architecture prefers: refreshes are driven
/// by manager events rather than by polling the CLI at frame rate. The process
/// is torn down when the stream terminates or `stop()` is called.
public final class AeroSpaceSubscription: WorkspaceEventSource, @unchecked Sendable {
    private let executablePath: String
    private let lock = NSLock()
    private var process: Process?
    private var pipe: Pipe?

    public init(executablePath: String) {
        self.executablePath = executablePath
    }

    public func events() -> AsyncStream<WorkspaceEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = AeroSpaceCLI.subscribe(executable: executablePath).arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { _ in continuation.finish() }

            let handle = pipe.fileHandleForReading
            let buffer = SubscriptionLineBuffer()
            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                for line in buffer.consume(data) {
                    if let event = AeroSpaceParser.event(fromLine: line) {
                        continuation.yield(event)
                    }
                }
            }

            // The consumer cancelling its task ends the stream; tear the process
            // down with it so no subscription outlives the feed generation.
            continuation.onTermination = { [weak self] _ in self?.stopSync() }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                continuation.finish()
                return
            }

            lock.lock()
            self.process = process
            self.pipe = pipe
            lock.unlock()
        }
    }

    public func stop() async {
        stopSync()
    }

    private func stopSync() {
        lock.lock()
        let process = self.process
        let pipe = self.pipe
        self.process = nil
        self.pipe = nil
        lock.unlock()

        pipe?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning { process.terminate() }
    }
}

/// Buffers a byte stream into whole UTF-8 lines.
///
/// Splitting on the newline byte before decoding means a chunk that ends in the
/// middle of a multibyte character is kept intact instead of being dropped. The
/// readability handler can arrive on a background queue, so access is
/// serialized.
final class SubscriptionLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

    func consume(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)

        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let lineData = pending[pending.startIndex..<newline]
            pending.removeSubrange(pending.startIndex...newline)
            // A line that fails to decode is dropped rather than corrupting the
            // next one; the bytes up to the newline are never split.
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}
