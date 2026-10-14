import AppKit
import Testing
import DivotCore
@testable import DivotAppKit

/// Offscreen renders of the keep-awake toast for visual review (caffeine on/off).
@MainActor
@Suite("Keep-awake toast snapshots")
struct KeepAwakeToastSnapshotTests {
    struct Config: Sendable {
        let family: AppearanceConfiguration.Family
        let dark: Bool
        let active: Bool

        var name: String {
            let state = active ? "on" : "off"
            return "caffeine-toast-\(family.rawValue)-\(dark ? "dark" : "light")-\(state)-default"
        }
    }

    nonisolated static let configs: [Config] = {
        let families: [AppearanceConfiguration.Family] = [.native, .gruvbox]
        return families.flatMap { family in
            [false, true].flatMap { dark in
                [true, false].map { active in Config(family: family, dark: dark, active: active) }
            }
        }
    }()

    @Test(arguments: configs)
    func rendersToast(config: Config) throws {
        let appearance = try #require(NSAppearance(named: config.dark ? .darkAqua : .aqua))
        let theme = BarTheme.resolve(AppearanceConfiguration(family: config.family,
                                                             mode: config.dark ? .dark : .light),
                                     dark: config.dark)
        let state = KeepAwakeToastState(isActive: config.active)
        let view = KeepAwakeToastContentView(state: state, theme: theme)
        view.appearance = appearance
        let size = view.intrinsicContentSize
        view.frame = NSRect(origin: .zero, size: size)

        let rep = try #require(SnapshotTestHelpers.render(view, size: size),
                               "Offscreen rendering produced no pixels for \(config.name)")
        let directory = SnapshotTestHelpers.snapshotDirectory(testFile: #filePath)
        try SnapshotTestHelpers.writePNG(name: config.name, rep: rep, directory: directory)
    }
}
