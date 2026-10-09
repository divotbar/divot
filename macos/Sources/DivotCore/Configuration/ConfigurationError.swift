import Foundation

/// A validation failure for one field of the versioned configuration.
///
/// The `path` is the dotted location inside the JSON document (`appearance.mode`,
/// `widgets.clock.seconds`, `left[0]`), so a settings surface or a diagnostics
/// line can point the reader at the exact field instead of a generic parse
/// failure. This mirrors the field paths the website checker reports.
public struct ConfigurationError: Error, Equatable, Sendable, CustomStringConvertible, LocalizedError {
    /// Dotted JSON location of the problem.
    public let path: String
    /// Human-readable explanation of what was wrong and what is expected.
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    public var description: String { "\(path): \(message)" }
    public var errorDescription: String? { description }
}
