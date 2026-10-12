# Evidence · 0004 native provider lifecycle and status widgets

Status: **implemented and unit-tested, not physically validated** · task 0004 ·
2026-10-10. This records what the provider pipeline and status widgets actually
do, what is covered by tests, and what still needs a person on real hardware. It
is not a claim that permissions, click behavior, or on-screen rendering were
observed working.

> Note: this record predates task 0033, which split the combined `clock` item
> into the separate `date` and `time` providers. The clock rows below describe
> the task 0004 state; current behavior is the split item list in
> [configuration](../configuration.md) and the public guide.

Story: [A beautiful bar from the first launch](../../stories/a-beautiful-bar-from-the-first-launch.md).
Shell and display coordinator: [0003 evidence](0003-app-shell.md).

## What was built

| Piece | Path | Role |
| --- | --- | --- |
| Widget value types | `macos/Sources/DivotCore/Widgets.swift` | `BarItemID`, snapshots, contextual `WidgetUnavailable`, `BarLayout` default. |
| Provider pipeline | `macos/Sources/DivotCore/WidgetPipeline.swift` | `WidgetProvider` interface, generation-checked `WidgetStore`, coalescing, `WidgetPipeline` actor, subscription helpers. |
| Clock | `macos/Sources/DivotCore/ClockWidget.swift` | Pure next-minute boundary math and localized weekday/date/time text. |
| Presentation | `macos/Sources/DivotCore/WidgetPresentation.swift` | State → SF Symbol + compact text + accessible label. |
| Click design | `macos/Sources/DivotCore/WidgetActions.swift` | Default action per item: settings link or activate app; no menu-extra mirroring. |
| Provider wrappers | `macos/Sources/DivotAppKit/WidgetProviders.swift` | Clock, front-app, battery, network, volume providers over small reading protocols. |
| System readings | `macos/Sources/DivotAppKit/System*Reading.swift` | IOKit power sources, `NWPathMonitor`, Core Audio property listeners, `NSWorkspace` front app. |
| Bar views | `macos/Sources/DivotAppKit/WidgetViews.swift`, `BarPanels.swift` | Per-item views, per-side content, panels; only changed items re-render. |
| App wiring | `macos/Sources/DivotApp/DivotAppDelegate.swift`, `DivotAppWidgetReport.swift` | First-launch defaults, main-actor sink, action handling, `divot --widgets`. |

## Providers and lifecycle

- **Clock** wakes at the next minute boundary (`ClockSchedule`), seconds
  optional, and emits once per boundary. No frame-rate or display-link loop.
- **Battery/power** reads IOKit power sources and observes
  `IOPSNotificationCreateRunLoopSource` on a dedicated background run loop. A
  desktop Mac reports a settled no-battery state, not an error. The internal
  battery's `Is Charging`/`Is Charged` flags are read tolerantly (boolean or
  numeric IOKit encoding), so the presentation always sees the live charging
  state and can show the bolt; `SystemBatteryReadingTests` covers both encodings.
  A power-source notification can arrive before the charging flag flips (the
  system starts charging a moment later), so each notification arms a bounded,
  fixed-interval re-read (`DivotCore.BatteryRecheckWindow`, 1s for a few
  attempts) that catches the bolt within about a second and then closes; it is
  not continuous polling. The window also closes early once the state settles
  (unplugged, charging, or fully charged), so a desktop or an already-charging
  laptop does not keep re-reading. The provider emits only on a changed
  snapshot, so re-check ticks do not redraw the bar. `BatteryRecheckWindow` is
  unit-tested, the observer's timer path and early close are covered by
  lagging/settled-source integration tests, and the provider's plug-in/unplug
  path is tested with a fake power source. Debug reads log the charging/plug
  flags for hardware confirmation.
- **Network** observes `NWPathMonitor` on a utility queue and maps transport,
  expensive, and constrained flags. It reads **no** SSID or other
  location-gated detail, so it never triggers a location prompt.
- **Volume** reads the default output device and observes Core Audio volume,
  mute, and default-device changes. Reads and listeners use the same elements:
  the main element when the device exposes it, otherwise the per-channel
  controls (front channels for volume, channel 1 for mute), so volume and mute
  changes stay live on devices that only expose channels. No output device is an
  explicit state.
- **Front app** reads `NSWorkspace.frontmostApplication` on the main actor and
  observes activation notifications.

`WidgetPipeline` is an actor. `start` runs every provider off the main thread;
providers emit small immutable snapshots tagged with a generation. The store
accepts an emission only for the item's current generation and only when the
content fits the item, so a late result from a disabled or reconfigured provider
is ignored. Changed items are coalesced and delivered to a `@MainActor` sink in
one batch. Stopping a provider (or reconfiguring it away) delivers a removal for
that item, so a widget that stays in the layout clears instead of showing a value
that is no longer kept current; a provider stopped and restarted before the
batch drains delivers its fresh value instead of a removal. `configure` compares
each provider's activation key (its item plus a fingerprint of its options): a
changed key replaces the activation, an equivalent one is left running.

The `workspaces` item stays in the default left group but has no provider yet, so
that slot renders its honest unavailable state until the workspace-adapter
milestone lands. It is intentionally absent rather than faked with numbered
spaces.

## Click controls and settings links

Divot deliberately does not mirror the system's menu extras. Each item has one
explicit default action (`WidgetActions`): front-app activates the running app;
network, volume, and clock open the matching System Settings pane; the battery
item toggles keep-awake (task 0018), which is a provider action rather than a
settings link; the workspaces item owns no action here (that is the
workspace-adapter milestone). The network item opens System Settings › Wi-Fi via
the macOS 13+ extension id `x-apple.systempreferences:com.apple.wifi-settings-extension`
(confirmed against the local `/System/Library/ExtensionKit/Extensions/Wi-Fi.appex`
bundle on macOS 26), and falls back to the legacy generic Network pane
(`com.apple.preference.network`) when the extension link cannot be opened. The
volume and clock panes use candidate
`x-apple.systempreferences:com.apple.preference.*` identifiers and **still need
validation on the target OS**; a later milestone may replace the volume/network
links with a native control popover.

## Tests

`swift test --package-path macos` covers the pure and mocked behavior. What is
asserted, by category:

- **Cancellation**: stopping a provider cancels its subscription and drops its
  slot; the subscription bag cancels a late-registered observation immediately;
  the volume watcher marks itself stopped before removing listeners, so a
  default-device callback queued at cancellation is ignored, installs nothing,
  and does not fire the handler (and `stop` is idempotent).
- **Volume element coverage**: the watcher observes the same elements the
  snapshot reads — the main element when the device exposes it, otherwise the
  per-channel controls — so a per-channel-only device is not left with a stale
  value, and a device with a main control still registers exactly the main
  element.
- **Stale completions**: a completion from before a disable/reconfigure is
  ignored, whether it arrives through the pipeline or through a captured emit
  closure; `configure` keeps an unchanged activation running and replaces one
  whose activation key changed.
- **Removal delivery**: stopping a provider delivers a `.removed` change so the
  bar clears the item; stopping and restarting before the drain delivers the
  fresh value, not a removal; the display coordinator forwards the removal to
  its surfaces instead of retaining the last value.
- **Independent failures**: one item reporting an unavailable state does not stop
  the others; a battery provider painting clock content is rejected.
- **No main-thread I/O**: providers are started on the actor's executor, never
  the main thread; the sink is only ever called on the main actor.
- **Coalescing**: a burst of emissions arrives as one batch with the latest
  value.
- **Clock**: next-minute and next-second boundary math, including already-on-a-
  boundary and non-finite input.
- **Presentation**: battery (including a sane desktop no-battery state),
  network (connected/offline/metered), volume (mute/no-output/level), clock
  (locale + zone), front-app, and honest unavailable states.

## Honest status by claim

**Implemented and covered by tests** (see the table above): provider lifecycle,
generations and stale rejection, independent per-item failure, coalescing,
off-main start with a main-actor sink, the minute clock and its text, the item
presentation, the default layout, the click-action mapping, and the subscription
helpers.

**Implemented but only asserted by construction, not observed:**

- The real system readings (IOKit, `NWPathMonitor`, Core Audio, `NSWorkspace`)
  compile and are wired, but only their pure mapping/presentation is tested here.
- The AppKit item views, their layout, click handling (`acceptsFirstMouse`,
  `mouseDown`, accessibility press), and the panel content swap.

**Not verified at all — a human must supply (do not treat as working):**

- Any on-screen rendering, truncation, or readability of the widgets on a real
  display at real scales.
- Whether a click on a nonactivating panel actually reaches an item and opens
  the intended System Settings pane; the network item's Wi-Fi id is confirmed,
  but the remaining pane identifiers above are candidates and no click has been
  observed end to end.
- Real battery/network/volume/front-app values under sleep/wake, hot-plug,
  external displays, and audio-device changes.
- Whether any provider's callback fires on main on real hardware for a long run.

No visual shots are declared for this change: the managed preview serves the
website, and the native bar has no browser route, so on-screen rendering stays a
device-QA item rather than something a capture here could prove.

A local, non-device run of `divot --widgets` (a 0.6s window) printed live values
from the built-in providers on the authoring machine. That is a smoke check that
the wiring runs; it is **not** device validation and no numbers from it are a
benchmark.

## Permissions

No new permission is required for battery, clock, network, volume, or front-app.
Network details that would need a location prompt (SSID) are deliberately not
read. Accessibility remains required only for the notched-display native-menu-bar
detector (0003/0009) and is unrelated to these widgets. A denied or failed
provider emits its own unavailable state and leaves the rest of the bar working.

## Commands

```sh
swift test --package-path macos
macos/.build/debug/divot --report    # display/menu-bar observation, one pass
macos/.build/debug/divot --widgets   # live built-in provider values, short window
```
