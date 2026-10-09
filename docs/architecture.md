# Architecture

## Native application

Swift 6.2+, AppKit, Core Animation, and selective Core Graphics/Core Text. The always-visible bar uses AppKit rather than SwiftUI. SwiftUI is permitted for infrequently opened settings. No WebKit or web runtime in the app. There is no reason to introduce a C/Rust subsystem until profiling identifies a bottleneck.

```text
App coordinator (main thread)
  ├─ Display coordinator → left/right NSPanel per display
  │    └─ BarView → small layer-backed item views
  ├─ Configuration store → validated immutable snapshots (left/right groups)
  ├─ Provider coordinator → background data collection
  │    ├─ clock / battery / network / volume / frontmost app
  │    └─ workspace adapter → snapshots and actions
  └─ Settings + AppKit menus/popovers
```

## Panels and geometry

Borderless nonactivating `NSPanel`s own placement and click behavior. A display gets two segment panels so the notch remains outside every hit region. Panels use global screen coordinates, including negative origins; align rendering to the current backing scale. Geometry comes from `NSScreen`, including its auxiliary top areas. `DivotCore.BarGeometry` is the tested, pure layout boundary; platform reads stay in the later display adapter.

Choose and validate public window levels and collection behaviors on target OS versions. Panels follow a persistent placement state: the top edge when the native menu bar is hidden, below it when the bar appears, returning to the top when it hides. Fullscreen, other Spaces, system menus, and focus cannot be assumed from a style-mask setting. Never adopt private APIs just to match a competitor's feature. Display transitions are coordinated as a batch to avoid intermediate positions.

## Rendering

Use a shallow `NSView` hierarchy with cached layer-backed contents. Dirty widgets invalidate their own content. Geometry changes trigger layout; a numeric value changing within a stable slot does not. Cache glyph measurements and images keyed by family, variant, scale, appearance, and content. Prefer native text and controls where they offer correct accessibility and interaction; custom drawing must implement equivalent accessibility elements/actions.

Semantic tokens carry foreground, background, accent, selected, occupied, and error roles so the native default and the four theme families share one drawing path. Changing family or appearance invalidates appearance-dependent caches only.

Core Animation handles brief transitions. No display link when idle. Avoid many translucent overlapping layers. Native material and opaque modes share the same geometry; honor reduce-transparency and reduce-motion preferences. Compare compositor costs before choosing the default material.

## State and concurrency

AppKit and view mutations stay on the main actor. Blocking collection and decoding run on bounded background work. Providers emit small immutable snapshots tagged with generation/revision. Ignore stale completions after disable/reconfiguration; cancellation tears down observers and connections. Coalesce burst updates before applying them. One slow provider must not hold up other widgets.

Provider interfaces separate lifecycle (`start`, `stop`), snapshots, and user actions. Maintain a registry of built-in provider identifiers. Clock wakes at the next minute boundary by default; seconds are optional. Battery/power, network, volume, and front-app changes use system notifications. CPU/network graphs require bounded sampling and stop when hidden.

## Workspace adapters

AeroSpace is the first adapter: use the supported CLI/events exposed by the user's installed version. Prefer a persistent subscription when supported; otherwise configured callbacks trigger bounded refreshes. Yabai joins as a second adapter behind the same interface in its own milestone. Document capability detection and failure modes. Do not rely on undocumented sockets. User actions can execute the CLI asynchronously with a timeout. Never spawn repeated queries on every render or poll workspace state at frame rate. Native macOS Spaces stays a research question: do not imply that NSWorkspace notifications provide a full native workspace adapter.

## Configuration and extensibility

One validated `Codable` model serves file reload and settings. It expresses ordered `left` and `right` item groups plus namespaced per-item options, and its defaults fill the first-launch bar so customization never starts from blank. Parse away from the main thread; apply atomically, preserving the last good snapshot on errors. Defaults and limits belong to the model. The future script protocol accepts data and actions, not HTML or executable UI injected into the process. Scripts are opt-in, explicitly trusted local programs with timeouts, output limits, and cancellation.

## Website

Vue 3 + stable VitePress 1.6.4. A custom landing component and shared bar demo sit alongside statically generated Markdown guides. Local fonts, no external assets, no runtime API. Default docs theme supplies local search, sidebar, heading navigation, code blocks, and appearance controls. Production output is ordinary HTML/CSS/JS; direct deep links must work on the chosen host.

## Sources

- [AppKit NSPanel](https://developer.apple.com/documentation/appkit/nspanel)
- [Layer backing](https://developer.apple.com/documentation/appkit/nsview/wantslayer)
- [NSScreen safe areas](https://developer.apple.com/documentation/appkit/nsscreen)
- [Energy-efficient notifications](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html)
- [AeroSpace integration guide](https://nikitabobko.github.io/AeroSpace/guide)
- [yabai wiki](https://github.com/koekeishiya/yabai/wiki)
- [VitePress custom themes](https://vitepress.dev/guide/custom-theme)
