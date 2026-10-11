import Foundation
import DivotCore
@testable import DivotAppKit

/// A `LocationAuthorizationTracking` stub that lets a test set the status and
/// count permission requests without touching CoreLocation. Shared by the
/// settings and network-reading tests.
final class StubLocationTracker: LocationAuthorizationTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var statusValue: LocationAuthorizationStatus
    private var requestCountValue = 0
    private var handler: (@Sendable (LocationAuthorizationStatus) -> Void)?

    init(status: LocationAuthorizationStatus = .notDetermined) {
        self.statusValue = status
    }

    var status: LocationAuthorizationStatus {
        get { lock.lock(); defer { lock.unlock() }; return statusValue }
        set { lock.lock(); statusValue = newValue; lock.unlock() }
    }

    /// How many times permission was requested. Observing never requests.
    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requestCountValue }

    func currentStatus() -> LocationAuthorizationStatus { status }

    func observeAuthorization(
        handler: @escaping @Sendable (LocationAuthorizationStatus) -> Void
    ) -> any ProviderSubscription {
        lock.lock(); self.handler = handler; lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.handler = nil; self.lock.unlock()
        }
    }

    func requestAuthorization() {
        lock.lock(); requestCountValue += 1; lock.unlock()
    }

    func requestAuthorizationAndObserve(
        handler: @escaping @Sendable (LocationAuthorizationStatus) -> Void
    ) -> any ProviderSubscription {
        lock.lock(); requestCountValue += 1; self.handler = handler; lock.unlock()
        return CallbackSubscription { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.handler = nil; self.lock.unlock()
        }
    }

    /// Deliver a new status to the current observer, as CoreLocation would.
    func push(_ newStatus: LocationAuthorizationStatus) {
        status = newStatus
        lock.lock(); let handler = self.handler; lock.unlock()
        handler?(newStatus)
    }
}
