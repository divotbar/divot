import Foundation
import CoreLocation
import DivotCore

/// The authorization status for Location Services.
public enum LocationAuthorizationStatus: Equatable, Sendable {
    /// The user has not yet been asked for permission.
    case notDetermined
    /// The user explicitly denied permission.
    case denied
    /// The user granted permission while the app was in focus.
    case authorizedWhenInUse
    /// The user granted always permission.
    case authorizedAlways

    /// Whether Wi-Fi name reading is permitted.
    var isAuthorizedForWifiName: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined, .denied:
            return false
        }
    }
}

/// Authorizes Location Services for reading the Wi-Fi network name.
///
/// A protocol so the Settings model and the network reading can be driven by a
/// stub in tests without standing up CoreLocation.
public protocol LocationAuthorizationTracking: AnyObject {
    /// The current authorization status, read synchronously.
    func currentStatus() -> LocationAuthorizationStatus
    /// Observe status changes without ever prompting.
    func observeAuthorization(
        handler: @escaping @Sendable (LocationAuthorizationStatus) -> Void
    ) -> any ProviderSubscription
    /// Ask for permission only while the app has not yet been asked, then leave
    /// the status to `observeAuthorization`. Never prompts once answered.
    func requestAuthorization()
    /// Request permission when undetermined and observe status changes.
    func requestAuthorizationAndObserve(
        handler: @escaping @Sendable (LocationAuthorizationStatus) -> Void
    ) -> any ProviderSubscription
}

/// Tracks CoreLocation authorization and requests permission when needed.
public final class LocationAuthorizationTracker: NSObject, CLLocationManagerDelegate, LocationAuthorizationTracking, @unchecked Sendable {
    private let manager = CLLocationManager()
    private let queue = DispatchQueue(label: "divot.location-authorization", qos: .utility)
    private var statusHandler: @Sendable (LocationAuthorizationStatus) -> Void = { _ in }

    public override init() {
        super.init()
        manager.delegate = self
    }

    /// Get the current authorization status synchronously.
    public func currentStatus() -> LocationAuthorizationStatus {
        let status = CLLocationManager.authorizationStatus()
        return status.toLocationAuthorizationStatus()
    }

    /// Observe authorization status changes without requesting permission.
    public func observeAuthorization(
        handler: @escaping @Sendable (LocationAuthorizationStatus) -> Void
    ) -> any ProviderSubscription {
        queue.async { [weak self] in
            self?.statusHandler = handler
            let status = CLLocationManager.authorizationStatus()
            let converted = status.toLocationAuthorizationStatus()
            DispatchQueue.main.async {
                handler(converted)
            }
        }

        return CallbackSubscription { [weak self] in
            self?.statusHandler = { _ in }
        }
    }

    /// Ask for permission only while the status is still undetermined. Safe to
    /// call repeatedly; once the user has answered it does nothing. The prompt
    /// is posted on the main thread, which macOS expects.
    public func requestAuthorization() {
        guard currentStatus() == .notDetermined else { return }
        DispatchQueue.main.async { [weak self] in
            self?.manager.requestWhenInUseAuthorization()
        }
    }

    /// Request location permission and observe status changes.
    public func requestAuthorizationAndObserve(
        handler: @escaping @Sendable (LocationAuthorizationStatus) -> Void
    ) -> any ProviderSubscription {
        queue.async { [weak self] in
            self?.statusHandler = handler
            let status = CLLocationManager.authorizationStatus()
            let converted = status.toLocationAuthorizationStatus()
            DispatchQueue.main.async {
                handler(converted)
            }
            if converted == .notDetermined {
                DispatchQueue.main.async {
                    self?.manager.requestWhenInUseAuthorization()
                }
            }
        }

        return CallbackSubscription { [weak self] in
            self?.statusHandler = { _ in }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus.toLocationAuthorizationStatus()
        let handler = statusHandler
        DispatchQueue.main.async {
            handler(status)
        }
    }
}

extension CLAuthorizationStatus {
    func toLocationAuthorizationStatus() -> LocationAuthorizationStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .restricted, .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }
}
