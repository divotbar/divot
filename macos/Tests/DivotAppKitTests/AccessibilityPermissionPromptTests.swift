import Foundation
import Testing
@testable import DivotAppKit

/// Thread-safe capture for the injected prompt/hint seams. Swift Testing runs
/// tests in parallel, so each test owns its own recorder.
private final class PromptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var prompts = 0
    private var hints: [String] = []

    func recordPrompt() {
        lock.lock()
        prompts += 1
        lock.unlock()
    }

    func recordHint(_ message: String) {
        lock.lock()
        hints.append(message)
        lock.unlock()
    }

    var promptCount: Int {
        lock.lock(); defer { lock.unlock() }
        return prompts
    }

    var capturedHints: [String] {
        lock.lock(); defer { lock.unlock() }
        return hints
    }
}

// MARK: - Pure decision

@Test func promptsOnlyWhenUntrustedAndNotYetAskedThisLaunch() {
    #expect(!AccessibilityPermissionPrompt.shouldPrompt(isTrusted: true, hasRequestedPrompt: false))
    #expect(AccessibilityPermissionPrompt.shouldPrompt(isTrusted: false, hasRequestedPrompt: false))
    #expect(!AccessibilityPermissionPrompt.shouldPrompt(isTrusted: false, hasRequestedPrompt: true))
    #expect(!AccessibilityPermissionPrompt.shouldPrompt(isTrusted: true, hasRequestedPrompt: true))
}

// MARK: - Launch behavior

@Test func trustedProcessIsNeverPrompted() {
    let recorder = PromptRecorder()
    var prompt = AccessibilityPermissionPrompt(
        isTrusted: { true },
        requestPrompt: { recorder.recordPrompt(); return true },
        isBundled: true,
        reportHint: { recorder.recordHint($0) })

    #expect(prompt.requestPromptIfNeeded() == .alreadyTrusted)
    #expect(prompt.requestPromptIfNeeded() == .alreadyTrusted)
    #expect(recorder.promptCount == 0)
}

@Test func untrustedProcessIsPromptedExactlyOncePerLaunch() {
    let recorder = PromptRecorder()
    var prompt = AccessibilityPermissionPrompt(
        isTrusted: { false },
        requestPrompt: { recorder.recordPrompt(); return false },
        isBundled: true,
        reportHint: { recorder.recordHint($0) })

    #expect(prompt.requestPromptIfNeeded() == .prompted)
    #expect(prompt.requestPromptIfNeeded() == .alreadyPrompted)
    #expect(prompt.requestPromptIfNeeded() == .alreadyPrompted)
    #expect(recorder.promptCount == 1)
}

@Test func unbundledProcessGetsTheHostAppHintExactlyOnce() {
    let recorder = PromptRecorder()
    var prompt = AccessibilityPermissionPrompt(
        isTrusted: { false },
        requestPrompt: { recorder.recordPrompt(); return false },
        isBundled: false,
        reportHint: { recorder.recordHint($0) })

    #expect(prompt.requestPromptIfNeeded() == .prompted)
    #expect(recorder.capturedHints == [AccessibilityPermissionPrompt.unbundledHint])
    // The hint belongs to the single eligible call, not to later no-ops.
    #expect(prompt.requestPromptIfNeeded() == .alreadyPrompted)
    #expect(recorder.capturedHints.count == 1)
    #expect(recorder.promptCount == 1)
}

@Test func bundledProcessNeverGetsTheUnbundledHint() {
    let recorder = PromptRecorder()
    var prompt = AccessibilityPermissionPrompt(
        isTrusted: { false },
        requestPrompt: { recorder.recordPrompt(); return false },
        isBundled: true,
        reportHint: { recorder.recordHint($0) })

    #expect(prompt.requestPromptIfNeeded() == .prompted)
    #expect(recorder.capturedHints.isEmpty)
}
