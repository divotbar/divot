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
        let pipeline = WidgetPipeline { states in
            for state in states { collected[state.id] = state }
        }
        let task = Task { await pipeline.configure(DefaultWidgetProviders.make()) }

        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        task.cancel()
        Task { await pipeline.stop() }

        print("# divot widget report (live built-in providers, \(duration)s window)")
        print("layout.left=\(BarLayout.default.left.map(\.rawValue).joined(separator: ","))")
        print("layout.right=\(BarLayout.default.right.map(\.rawValue).joined(separator: ","))")
        for id in BarItemID.allCases {
            guard let state = collected[id] else {
                print("\(id.rawValue): (no data within \(duration)s)")
                continue
            }
            let presentation = WidgetPresenter.present(id: id, state: state)
            let text = presentation.text.isEmpty ? "(icon \(presentation.symbolName ?? "-"))" : presentation.text
            print("\(id.rawValue): \(text) · \(presentation.accessibilityLabel)")
        }
    }
}
