import DivotCore

/// The built-in provider set for the first-launch bar.
///
/// `make(for:)` builds only the providers a configuration actually places, so
/// removing an item from both groups stops that provider instead of leaving it
/// collecting. `workspaces` is not a `WidgetProvider`: it renders through
/// `WorkspaceFeed`, so the app starts and stops that feed alongside this set.
@MainActor
public enum DefaultWidgetProviders {
    /// Every built-in provider, for the default configuration and diagnostics.
    public static func make() -> [any WidgetProvider] {
        make(for: .default)
    }

    /// The providers enabled by `configuration`, in a stable order.
    public static func make(for configuration: DivotConfiguration,
                            keepAwake: (any KeepAwakeObserving)? = nil,
                            appearance: (any AppearanceReading)? = nil) -> [any WidgetProvider] {
        var providers: [any WidgetProvider] = []
        for id in placedProviderIDs(in: configuration) {
            switch id {
            case .battery: providers.append(BatteryProvider(reading: IOKitBatteryReading(),
                                                            keepAwake: keepAwake))
            case .clock: providers.append(ClockProvider(seconds: configuration.widgets.clock.seconds))
            case .network: providers.append(NetworkProvider(reading: NWPathNetworkReading(),
                                                           readWifiName: configuration.widgets.network.showWifiName))
            case .volume: providers.append(VolumeProvider(reading: CoreAudioVolumeReading()))
            case .frontApp: providers.append(FrontAppProvider(reading: NSWorkspaceFrontAppReading()))
            case .appearance: providers.append(AppearanceProvider(reading: appearance ?? SystemAppearanceReading()))
            case .workspaces: break
            }
        }
        return providers
    }

    /// The built-in provider identifiers a configuration enables. Pure, so the
    /// "disabled providers stop" rule is testable without constructing readers.
    public static func placedProviderIDs(in configuration: DivotConfiguration) -> [BarItemID] {
        let order: [BarItemID] = [.battery, .clock, .network, .volume, .frontApp, .appearance]
        return order.filter { configuration.isPlaced($0) }
    }
}
