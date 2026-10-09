import Foundation

/// Watches the configuration file's directory for writes and replacements.
///
/// Watching the directory (not the file) means an editor that saves by writing a
/// temp file and renaming it over the target is observed, not just in-place
/// writes. Events arrive on a private queue; the owner hops to the main actor.
public final class ConfigurationFileWatcher: @unchecked Sendable {
    private let directoryURL: URL
    private let queue = DispatchQueue(label: "dev.divot.configuration-watch")
    private var source: DispatchSourceFileSystemObject?
    private var handler: (@Sendable () -> Void)?

    public init(configURL: URL) {
        self.directoryURL = configURL.deletingLastPathComponent()
    }

    /// Start watching. Replaces any previous watcher. Does nothing if the
    /// directory cannot be opened (for example, no config directory yet).
    public func start(_ handler: @escaping @Sendable () -> Void) {
        stop()
        self.handler = handler
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .rename, .delete, .extend],
                                                               queue: queue)
        source.setEventHandler { [weak self] in self?.handler?() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
        handler = nil
    }

    deinit {
        source?.cancel()
    }
}
