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
    public init() {}

    public func observe(readWifiName: Bool, handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "divot.network-path", qos: .utility)
        monitor.pathUpdateHandler = { path in
            handler(NWPathNetworkReading.snapshot(from: path, readWifiName: readWifiName))
        }
        monitor.start(queue: queue)
        return CallbackSubscription { monitor.cancel() }
    }

    static func snapshot(from path: NWPath, readWifiName: Bool = false) -> NetworkSnapshot {
        let interface = path.availableInterfaces.first { path.usesInterfaceType($0.type) }
            ?? path.availableInterfaces.first
        let kind = kind(of: path)
        let wifiName = (readWifiName && kind == .wifi) ? attemptReadWifiName() : nil
        return NetworkSnapshot(isConnected: path.status == .satisfied,
                               kind: kind,
                               interfaceName: interface?.name,
                               isExpensive: path.isExpensive,
                               isConstrained: path.isConstrained,
                               wifiName: wifiName)
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
}
