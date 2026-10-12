// `kAXTrustedCheckOptionPrompt` is imported as a mutable C global, so Swift 6
// strict concurrency flags a direct read. `@preconcurrency` is the scoped
// escape hatch; the value is a fixed system constant, not mutable state.
@preconcurrency import ApplicationServices
import Foundation

/// The launch-time Accessibility permission check.
///
/// Divot's notched-display menu-bar probe needs Accessibility permission, but a
/// refused grant must never trap the app in a prompt loop. This type performs
/// the one check at launch: when the process is already trusted it does nothing,
/// and when it is not it asks the system to show the prompt at most once per
/// launch. The trusted reading and the prompt request are injected so the
/// decision is unit-testable without real system permission, and the live
/// defaults use only public APIs (`AXIsProcessTrusted` /
/// `AXIsProcessTrustedWithOptions`).
public struct AccessibilityPermissionPrompt {
    /// What the launch check did.
    public enum Outcome: Equatable, Sendable {
        /// The process already holds the permission; nothing was requested.
        case alreadyTrusted
        /// The system prompt was requested on this call.
        case prompted
        /// The prompt was already requested earlier this launch.
        case alreadyPrompted
    }

    public typealias IsTrusted = () -> Bool
    public typealias RequestPrompt = () -> Bool
    public typealias ReportHint = (String) -> Void

    /// The one-line hint shown when running unbundled and untrusted. An
    /// unbundled process is the terminal app that launched `swift run`, so the
    /// grant attaches there and does not survive into a packaged build.
    public static let unbundledHint =
        "divot: running unbundled; the Accessibility grant attaches to the host terminal or app, not Divot — dist/Divot.app is where it lasts.\n"

    private let isTrusted: IsTrusted
    private let requestPrompt: RequestPrompt
    private let isBundled: Bool
    private let reportHint: ReportHint
    private var hasRequestedPrompt = false

    /// - Parameters:
    ///   - isTrusted: Reads the current process trust. Defaults to the public
    ///     `AXIsProcessTrusted()`.
    ///   - requestPrompt: Requests the system prompt. Defaults to
    ///     `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt`.
    ///   - isBundled: Whether Divot is running from a `.app`. Defaults to
    ///     inspecting `Bundle.main`.
    ///   - reportHint: Sink for the unbundled hint. Defaults to stderr.
    public init(
        isTrusted: @escaping IsTrusted = { AXIsProcessTrusted() },
        requestPrompt: @escaping RequestPrompt = AccessibilityPermissionPrompt.liveRequestPrompt,
        isBundled: Bool = AccessibilityPermissionPrompt.processIsBundled,
        reportHint: @escaping ReportHint = { message in
            FileHandle.standardError.write(Data(message.utf8))
        }
    ) {
        self.isTrusted = isTrusted
        self.requestPrompt = requestPrompt
        self.isBundled = isBundled
        self.reportHint = reportHint
    }

    /// Pure decision: request only when untrusted and never before.
    public static func shouldPrompt(isTrusted: Bool, hasRequestedPrompt: Bool) -> Bool {
        !isTrusted && !hasRequestedPrompt
    }

    /// True when the process is running from a packaged `.app` bundle. A plain
    /// `swift run` binary has neither a bundle identifier nor a `.app` path.
    public static var processIsBundled: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    /// The live prompt call: public API only, no polling.
    public static func liveRequestPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Requests the prompt at most once per launch, only when untrusted.
    ///
    /// Safe to call repeatedly: the first eligible call asks the system and
    /// records it; every later call is a no-op. The unbundled hint is emitted
    /// only on that same eligible call, so it never repeats either.
    @discardableResult
    public mutating func requestPromptIfNeeded() -> Outcome {
        let trusted = isTrusted()
        // The pure decision is the single gate, so the tested rule and the live
        // path cannot drift apart.
        guard AccessibilityPermissionPrompt.shouldPrompt(isTrusted: trusted,
                                                         hasRequestedPrompt: hasRequestedPrompt) else {
            return trusted ? .alreadyTrusted : .alreadyPrompted
        }
        hasRequestedPrompt = true
        if !isBundled {
            reportHint(AccessibilityPermissionPrompt.unbundledHint)
        }
        _ = requestPrompt()
        return .prompted
    }
}
