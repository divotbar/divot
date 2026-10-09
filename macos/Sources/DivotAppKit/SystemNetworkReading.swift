import Foundation
import Network
import DivotCore

/// Live connectivity from `NWPathMonitor`.
///
/// The monitor runs on its own queue and delivers the first path immediately, so
/// the provider needs no polling and the main thread is untouched. Only
/// permission-free fields are read: no SSID or other location-gated detail, so
/// the network indicator never triggers a location prompt.
public final class NWPathNetworkReading: NetworkReading, @unchecked Sendable {
    public init() {}

    public func observe(_ handler: @escaping @Sendable (NetworkSnapshot) -> Void) -> any ProviderSubscription {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "divot.network-path", qos: .utility)
        monitor.pathUpdateHandler = { path in
            handler(NWPathNetworkReading.snapshot(from: path))
        }
        monitor.start(queue: queue)
        return CallbackSubscription { monitor.cancel() }
    }

    static func snapshot(from path: NWPath) -> NetworkSnapshot {
        let interface = path.availableInterfaces.first { path.usesInterfaceType($0.type) }
            ?? path.availableInterfaces.first
        return NetworkSnapshot(isConnected: path.status == .satisfied,
                               kind: kind(of: path),
                               interfaceName: interface?.name,
                               isExpensive: path.isExpensive,
                               isConstrained: path.isConstrained)
    }

    private static func kind(of path: NWPath) -> NetworkKind {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .other
    }
}
