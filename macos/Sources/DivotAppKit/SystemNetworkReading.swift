import Foundation
import Network
import CoreWLAN
import DivotCore

/// Live connectivity from `NWPathMonitor`.
///
/// The monitor runs on its own queue and delivers the first path immediately, so
/// the provider needs no polling and the main thread is untouched. Wi-Fi name
/// reading is opt-in via `readWifiName` to avoid requesting location permission
/// when the user has not explicitly enabled the feature.
public final class NWPathNetworkReading: NetworkReading, @unchecked Sendable {
    private let locationTracker: LocationAuthorizationTracker

    public init(locationTracker: LocationAuthorizationTracker = LocationAuthorizationTracker()) {
        self.locationTracker = locationTracker
    }

    public func observe(readWifiName: Bool, handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "divot.network-path", qos: .utility)
        let state = State()

        let emit: @Sendable () -> Void = {
            let (path, status) = state.current
            if let path = path {
                let snapshot = NWPathNetworkReading.snapshot(from: path, readWifiName: readWifiName, locationStatus: status)
                DispatchQueue.main.async {
                    handler(snapshot)
                }
            }
        }

        monitor.pathUpdateHandler = { [queue, state] path in
            queue.async {
                state.setPath(path)
                emit()
            }
        }
        monitor.start(queue: queue)

        if readWifiName {
            state.setLocationSubscription(locationTracker.requestAuthorizationAndObserve { [queue, state] status in
                queue.async {
                    state.setLocationStatus(status.toStatusString())
                    emit()
                }
            })
        }

        return CallbackSubscription {
            state.clearLocationSubscription()
            monitor.cancel()
        }
    }

    static func snapshot(from path: NWPath, readWifiName: Bool = false, locationStatus: String? = nil) -> NetworkSnapshot {
        let interface = path.availableInterfaces.first { path.usesInterfaceType($0.type) }
            ?? path.availableInterfaces.first
        let kind = kind(of: path)
        let isAuthorized = locationStatus == "authorizedWhenInUse" || locationStatus == "authorizedAlways"
        let wifiName = (readWifiName && kind == .wifi && isAuthorized) ? attemptReadWifiName() : nil
        return NetworkSnapshot(isConnected: path.status == .satisfied,
                               kind: kind,
                               interfaceName: interface?.name,
                               isExpensive: path.isExpensive,
                               isConstrained: path.isConstrained,
                               wifiName: wifiName,
                               locationAuthorizationStatus: locationStatus)
    }

    private static func kind(of path: NWPath) -> NetworkKind {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .other
    }

    /// Attempt to read the current Wi-Fi network name using the public CWWiFiClient API.
    /// Returns nil if the API is unavailable, permission is denied, or no network is connected.
    private static func attemptReadWifiName() -> String? {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else { return nil }
        guard let ssid = interface.ssid(), !ssid.isEmpty else { return nil }
        return ssid
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var currentPath: NWPath?
        private var currentLocationStatus: String?
        private var locationSubscription: (any ProviderSubscription)?

        var current: (NWPath?, String?) {
            lock.lock()
            defer { lock.unlock() }
            return (currentPath, currentLocationStatus)
        }

        func setPath(_ path: NWPath?) {
            lock.lock()
            currentPath = path
            lock.unlock()
        }

        func setLocationStatus(_ status: String?) {
            lock.lock()
            currentLocationStatus = status
            lock.unlock()
        }

        func setLocationSubscription(_ sub: any ProviderSubscription) {
            lock.lock()
            locationSubscription = sub
            lock.unlock()
        }

        func clearLocationSubscription() {
            lock.lock()
            locationSubscription = nil
            lock.unlock()
        }
    }
}

private extension LocationAuthorizationStatus {
    func toStatusString() -> String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        case .authorizedAlways:
            return "authorizedAlways"
        }
    }
}
