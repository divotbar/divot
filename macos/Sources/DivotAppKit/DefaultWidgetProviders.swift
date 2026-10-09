import DivotCore

/// The built-in provider set for the first-launch bar.
///
/// Every listed provider is required for the first useful release: battery,
/// clock, network, volume, and the frontmost app. Workspaces are added by the
/// workspace-adapter milestone behind the same `WidgetProvider` interface.
@MainActor
public enum DefaultWidgetProviders {
    public static func make() -> [any WidgetProvider] {
        [
            BatteryProvider(reading: IOKitBatteryReading()),
            ClockProvider(),
            NetworkProvider(reading: NWPathNetworkReading()),
            VolumeProvider(reading: CoreAudioVolumeReading()),
            FrontAppProvider(reading: NSWorkspaceFrontAppReading())
        ]
    }
}
