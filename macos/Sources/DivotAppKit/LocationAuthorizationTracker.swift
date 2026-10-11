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

/// Tracks CoreLocation authorization and requests permission when needed.
public final class LocationAuthorizationTracker: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
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
                self?.manager.requestWhenInUseAuthorization()
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

private extension CLAuthorizationStatus {
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
