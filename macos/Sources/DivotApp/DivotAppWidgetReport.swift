import AppKit
import DivotAppKit
import DivotCore

/// `divot --widgets` runs the built-in providers for a short window and prints
/// what they reported. It is a diagnostic for a person on real hardware: it
/// makes no placement changes and proves nothing by itself, but shows the live
/// values rather than a mock.
@MainActor
enum DivotAppWidgetReport {
    static func run(duration: TimeInterval = 0.6) {
        var collected: [BarItemID: WidgetState] = [:]
        let pipeline = WidgetPipeline { changes in
            for change in changes {
                switch change {
                case .update(let state): collected[state.id] = state
                case .removed(let id): collected.removeValue(forKey: id)
                }
            }
        }
        let task = Task { await pipeline.configure(DefaultWidgetProviders.make()) }

        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        task.cancel()
        Task { await pipeline.stop() }

        let metrics = DivotConfiguration.default.barMetrics
        // The default app icon size must equal the status icon size, and this
        // line lets the packaged-app smoke test assert it (#0052).
        print("# divot widget report (live built-in providers, \(duration)s window)")
        print("metrics.iconSize=\(Int(metrics.iconSize)) metrics.appIconSize=\(Int(metrics.appIconSize))")
        // The battery, network and volume symbols draw at this point size; the
        // default is the native menu-bar symbol size (#0057).
        print("metrics.statusSymbolSize=\(Int(metrics.statusSymbolPointSize))")
        // The image each of the three symbols resolves to at that point size,
        // so a packaged-app run records the measured icon size, not just the
        // configured number.
        for (id, symbol) in [(BarItemID.battery, "battery.100"),
                             (BarItemID.network, "wifi"),
                             (BarItemID.volume, "speaker.wave.2.fill")] {
            let size = NativeStatusSymbol.image(symbolName: symbol, metrics: metrics)?.size ?? .zero
            print("statusSymbol.\(id.rawValue)=\(symbol) \(Int(size.width))x\(Int(size.height))pt")
        }
        // The charging mark draws in one fixed green, never the theme accent;
        // print the resolved colour so a packaged-app run records the green the
        // bar will draw (#0074).
        if let rgb = NSColor(ChargingIndicatorPalette.green).usingColorSpace(.sRGB) {
            print(String(format: "charging.green=#%02X%02X%02X",
                         Int((rgb.redComponent * 255).rounded()),
                         Int((rgb.greenComponent * 255).rounded()),
                         Int((rgb.blueComponent * 255).rounded())))
        }
        print("layout.left=\(BarLayout.default.left.map(\.rawValue).joined(separator: ","))")
        print("layout.right=\(BarLayout.default.right.map(\.rawValue).joined(separator: ","))")
        for id in BarItemID.placeableItems {
            guard let state = collected[id] else {
                print("\(id.rawValue): (no data within \(duration)s)")
                continue
            }
            let presentation = WidgetPresenter.present(id: id, state: state)
            let text = presentation.text.isEmpty ? "(icon \(presentation.symbolName ?? "-"))" : presentation.text
            print("\(id.rawValue): \(text) · \(presentation.accessibilityLabel)")
            if let badge = presentation.badge {
                print("\(id.rawValue).badge=\(badge.symbolName) role=\(badge.role.rawValue)")
            }
        }
    }
}
