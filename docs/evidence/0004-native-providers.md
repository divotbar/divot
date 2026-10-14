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
| Wi-Fi popover | `macos/Sources/DivotAppKit/WifiPopover.swift`, `WifiNetworkScanner.swift`, `macos/Sources/DivotCore/WifiNetworks.swift` | Read-only nearby-network popover, the CoreWLAN scanner behind a seam, and the pure list shaping (task 0070). |
| Bar popover scaffold | `macos/Sources/DivotAppKit/BarPopover.swift` | Shared header/body/settings-row layout, the theme-aware label/secondary/link colours, and the anchored `NSPopover` lifecycle (transient + outside-click/Escape monitors, same-item toggle) reused by the Wi-Fi, volume, and appearance popovers. |
| Volume popover | `macos/Sources/DivotAppKit/VolumePopover.swift`, `macos/Sources/DivotCore/OutputVolume.swift` | Output-volume slider with a percentage, a mute toggle, and a Sound-settings row over a tested set/get seam (task 0071). |
| Appearance popover | `macos/Sources/DivotAppKit/AppearancePopover.swift`, `macos/Sources/DivotCore/AppearanceSettings.swift` | System/Light/Dark segmented control and a vertical list of theme-family options plus a Divot-settings row over the shared configuration store (tasks 0072/0073). |
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
  changes stay live on devices that only expose channels. A volume control that
  exists but is **not writable** (some HDMI/DisplayPort outputs, checked with
  `AudioObjectIsPropertySettable`) is reported as `isSettable == false`, so the
  volume popover disables its slider instead of writing a value the hardware
  ignores. No output device is an explicit state.
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
the clock opens the matching System Settings pane; the battery item toggles
keep-awake (task 0018), which is a provider action rather than a settings link;
the workspaces item owns no action here (that is the workspace-adapter
milestone). The network item opens the Wi-Fi popover below (task 0070, clickable
since task 0099);
its last row opens System Settings › Wi-Fi via the macOS 13+ extension id
`x-apple.systempreferences:com.apple.wifi-settings-extension` (confirmed against
the local `/System/Library/ExtensionKit/Extensions/Wi-Fi.appex` bundle on macOS
26), with the legacy generic Network pane (`com.apple.preference.network`) as the
fallback when the extension link cannot be opened. The volume item opens the
output-volume popover below (task 0071); its last row opens the Sound pane with
the candidate `x-apple.systempreferences:com.apple.preference.sound` identifier.
The appearance item opens the appearance popover below (task 0072); it no longer
toggles light/dark directly, and its last row opens Divot's own settings window
rather than a System Settings pane.
The clock pane uses the same candidate `x-apple.systempreferences:com.apple.preference.*`
pattern and **still needs validation on the target OS**.

## Wi-Fi popover (task 0070)

Clicking the network item opens an `NSPopover` anchored to the item
(`WifiPopover.swift`) that lists nearby networks: SSID, a signal glyph, a lock
for a secured network, and the connected network marked and pinned first. Each
in-range row is a button: clicking it joins that network through the
`WifiNetworkConnecting` seam, showing "Connecting…" and then the new current
network or the macOS error. A secured network with no password yet asks for one
through a Divot-styled dialog holding an `NSSecureTextField` (never a plain
field in the bar); the password is passed only to the join call and is never
written to Divot's configuration, state, or logs. Networks Divot joined itself
are recorded with their time and shown in a separate **Previously joined**
section (most recent first, at most five, skipping SSIDs that are in range now);
system saved profiles are never listed. The last row is **Open Wi-Fi Settings…**
(the #0069 pane link).
The network rows live in a scroll view whose height is capped at 90% of the
screen the popover is shown on, so a long list of nearby networks scrolls
instead of growing the panel without bound (task 0095).

The scan runs through the `WifiNetworkScanning` seam (`DivotAppKit`), once per
open and never on a timer; closing the popover cancels an in-flight scan or
join. The last completed list scan is cached with its finish time: when it is
less than 10 minutes old the next open paints it at once with its age
("Updated Xs ago") and always runs the live scan in the background, updating
the list in place. The
live scanner (`CoreWLANNetworkScanner`) uses public CoreWLAN only
(`CWWiFiClient.shared().interface()`, `CWInterface.scanForNetworks(withSSID:)`),
runs the blocking call on its own serial queue rather than the main actor, and
races it against a 20-second timeout so a wedged scan still settles into a
visible state; the cached rows stay visible until the live result lands or the
scan times out. While scanning, a spinning indicator animates beside the status
line instead of static text. `WifiNetworks` in `DivotCore` is the pure list logic: dedupe by
SSID keeping the strongest reading (a signal tie keeps the secure entry so a
lock is never dropped), drop blank/hidden SSIDs, mark and pin the current
network, then sort by signal descending and name. States are explicit:
`.networks`, `.permissionDenied`, `.unavailable` (no interface), and `.failed`
(message shown verbatim). Without Location authorization the popover shows the
permission message and a button to **Privacy & Security › Location Services**
instead of an empty list; on a dev build without an `Info.plist` the same
permission/unavailable state is what a person sees.

Findings recorded for the follow-up decision (no behavior was invented):

- **Hidden SSIDs.** A hidden network reports a `nil` (or empty) `ssid`; the
  scanner drops it and `WifiNetworks` drops a blank name again as a safety net.
  No hidden network appeared in the local probe below, so the drop path is
  asserted by unit tests, not observed against a real hidden AP.
- **Without Location permission.** In a local probe on the authoring machine
  (macOS 26.5, a non-bundled command-line process, `CLLocationManager`
  authorization `.notDetermined`), `CWInterface.ssid()` returned `nil` while
  `scanForNetworks(withSSID: nil)` still returned 19 named results. That is a
  single observation and not device validation: it does not establish whether
  TCC attributed the scan to a parent process that already holds Location, and
  Divot's shipped path is the permission-gated one the acceptance criteria ask
  for. A packaged app with Location denied is still the check a person must run.
- **Joining networks (task 0099).** The public CoreWLAN header exposes
  `CWInterface.associate(to:password:)` (macOS 10.7+), which the live
  `CoreWLANWifiConnector` calls with the `CWNetwork` a directed scan returns
  for the tapped SSID, off the main actor. Tests join through a fake connector
  and a fake password provider, so no test touches system state or prompts;
  whether association works for an unsandboxed app without extra entitlements,
  and the real join UX, are validated on the packaged app by a person, not
  claimed here.
- **Duplicate SSIDs are real.** The same probe returned the SSID `ARISTA` twice
  (RSSI −60 and −70), which is the multi-BSSID case the dedupe rule collapses.

## Volume popover (task 0071)

Clicking the volume item opens the same anchored popover shell as the Wi-Fi
popover (`BarPopover.swift` owns the shared layout and `NSPopover` lifecycle;
`VolumePopover.swift` supplies the rows). It contains a horizontal output-volume
slider with the current percentage, a **Mute** toggle, and a final
**Open Sound Settings…** row that opens the Sound pane, exactly the pattern of
the Wi-Fi popover's last row.

Opening reads the default output once and subscribes to the same Core Audio
property listeners the provider already uses — never a timer — so a keyboard
volume key or another app moves the slider while it is open; closing the popover
removes those listeners. A slider drag and the mute toggle write through the
`OutputVolumeControlling` seam (implemented live by `CoreAudioVolumeReading`
using `AudioObjectSetPropertyData` on the output-scope scalar-volume and mute
properties), and the write makes the bar item's own provider re-emit, so the bar
icon and percentage follow the slider. All reads and writes are public Core Audio
property calls on the default output device; no private API is used.

Code paths for an output that cannot be changed (recorded, not invented):

- A device whose volume property is exposed but **not writable**
  (`AudioObjectIsPropertySettable` false, e.g. some HDMI/DisplayPort outputs) is
  reported with `isSettable == false`. The popover disables the slider **and** the
  mute toggle, shows `—` instead of a percentage, and shows the short note
  "This output has no settable volume. Use the display's or device's own
  controls." It never writes a value the hardware ignores. The bar item keeps its
  existing presentation (the pre-existing "no software volume control is full
  scale" rule), which this task did not change.
- With no output device at all (`VolumeSnapshot.noOutput`) the popover disables
  both controls and shows "No audio output device."

The popover is anchored to the item and is `.transient`, additionally watched by
a global (other apps and the desktop) and a local mouse-down monitor plus Escape,
so any click outside it, or Escape, dismisses it; a second click on the same bar
item toggles it closed. The monitors are installed while it is shown and removed
the instant it closes — no polling. Its text is painted from the bar's `BarTheme`
(`BarTheme.popoverPalette`), so its label/secondary/link roles clear the same
contrast floors the theme audit checks; all themes paint the popover's own solid,
opaque background from the theme palette so it matches the bar exactly and renders
predictably regardless of what is behind it, and the popover adopts the bar's light/dark
variant either way.
Whether the slider
actually moves the real output volume, and whether the item's percentage follows
on screen, are **not verified here**: that is the maintainer's packaged-app check.

## Appearance popover (tasks 0072/0073)

Clicking the appearance (moon/sun) item now opens the same anchored popover shell
as the Wi-Fi and volume popovers (`BarPopover.swift` owns the shared layout and
`.transient` lifecycle; `AppearancePopover.swift` supplies the rows) instead of
toggling light/dark directly. Task 0073 restyled it compact and horizontal: it
contains a **Mode** row as one horizontal `System`/`Light`/`Dark` segmented
control matching `appearance.mode`, a vertical list of theme-family options
(`Native`, `Alpine`, `Gruvbox`, `Ayu`, `Dracula`, `Tokyo Night`, matching
`appearance.family`) where each row is left-aligned and shows a small colour swatch taken from
that family's own palette (`ThemeResolver.swatch`, so a new family needs no
hand-copied colour) and the family name, with the current theme clearly marked, then a final **Open Divot
Settings…** row that opens Divot's own settings window, not a System Settings
pane. The shared width floor is lowered for this content so the popover hugs the
control and list instead of leaving an empty block beside them; the Wi-Fi and
volume popovers keep the shared floor. All popover content (title, labels, rows, links) is left-aligned. All themes paint the popover with a solid, opaque background from the theme palette and a thin border (rounded corners for curated families), so the popover renders predictably regardless of what is behind it. The chosen ring and option labels come from
the bar's `BarTheme`,
so the popover matches the bar in light and dark and under increased contrast.

Both lists are built from the configuration enums
(`AppearanceConfiguration.Mode.allCases` and `.Family.allCases`), so a new family
or mode appears here automatically, and every edit goes through the same
`ConfigurationController` the Settings window and `divot theme` use — validate,
atomic write, live reload — so the popover and the Settings window never
disagree. The popover owns one `AppearancePopoverModel` over the
`AppearanceSettingsControlling` seam (implemented live by
`ConfigurationController`): it reads the current selection when it opens,
subscribes to published changes while it is open so a change made in the Settings
window or by the file watcher shows up without reopening, and removes that
subscription on any close. It changes Divot's own rendering only; it never
changes the macOS system appearance. Whether the popover applies on screen and
lines up under the item is the maintainer's packaged-app check, not verified
here.

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
- **Wi-Fi list shaping** (task 0070, `WifiNetworksTests`): dedupe keeps the
  strongest duplicate reading, a signal tie keeps the secure entry, blank/hidden
  names are dropped, the current network is marked and pinned first, the rest
  sort by signal then name, the dBm-to-bars bands are pinned, and every scan
  response maps to its honest state. The scan model is driven by a fake scanner
  through the seam, so the permission-denied and scanned paths are asserted
  without standing up CoreWLAN, and the Location Services deep link is pinned.
- **Output volume** (task 0071, `OutputVolumeTests`): the 0...1 clamp (including
  non-finite input and the whole-percent rounding), and the popover model driven
  by a fake `OutputVolumeControlling` — a write is clamped before it reaches the
  seam, the mute toggle writes and reports its state, an unsettable output and a
  missing output write nothing and return `nil`, an external change reloads the
  state, and closing the popover cancels the observation. `VolumePopoverTests`
  pins the content rows: the slider percentage and enabled state, the disabled
  note for an unsettable output, and the slider's accessibility label and value.
  `WidgetProviderTests` adds that a normal output reports `isSettable == true`
  and a read-only one reports `isSettable == false`.
- **Appearance settings** (task 0072, `AppearanceSettingsTests`): the popover
  model driven by a fake `AppearanceSettingsControlling` — the family/mode lists
  come from the configuration enums, a mode or family selection writes through
  the seam and reports the settled value, re-selecting the current value writes
  nothing, a selection while observing is delivered through the observer, an
  external change replays the published configuration and updates the model, a
  change made before observing is picked up by `refresh`, and observing registers
  once and is removed on close. `AppearancePopoverTests` pins the compact content:
  the mode segmented control offers System/Light/Dark in order with the current
  segment selected, every family is offered from the enums with the current one
  outlined, a theme swatch is drawn from the resolved family palette (and follows
  the system variant for `system` mode, with native falling back to system
  colours), the theme options are displayed in a vertical list with one per row, the shared width floor is
  dropped for this content, a selection forwards its value, every option carries
  an accessibility label and a selected/not-selected value and refuses no first
  responder, focus lands on the mode control, and the settings row reports.
- **Popover theme and dismissal** (tasks 0072/0073, `BarPopoverTests`,
  `BarThemeTests`): the dismiss decision closes on an outside press or Escape but
  not on a press on the anchor item (the toggle) or inside the popover; the host
  installs the dismiss monitors when it presents and removes them the moment it
  closes, and drops its anchor; a second click on the owning item toggles closed.
  The popover palette is the bar theme's own background/label/secondary/border
  plus a contrast-adjusted link (AA against the popover background), the popover
  adopts the bar's light/dark appearance, and the native theme keeps the system
  semantic roles.

## Honest status by claim

**Implemented and covered by tests** (see the table above): provider lifecycle,
generations and stale rejection, independent per-item failure, coalescing,
off-main start with a main-actor sink, the minute clock and its text, the item
presentation, the default layout, the click-action mapping, the Wi-Fi list
shaping and scan-model states, the output-volume clamp and popover model, the
appearance selection model, and the subscription helpers.

**Implemented but only asserted by construction, not observed:**

- The real system readings (IOKit, `NWPathMonitor`, Core Audio, `NSWorkspace`)
  compile and are wired, but only their pure mapping/presentation is tested here.
- The AppKit item views, their layout, click handling (`acceptsFirstMouse`,
  `mouseDown`, accessibility press), and the panel content swap.
- The live `CoreWLANNetworkScanner` and the `WifiPopoverController`/AppKit
  popover itself: the seam and pure logic are tested, but no scan result or
  popover was rendered and observed in an app.
- The live `CoreAudioVolumeReading.setLevel`/`setMuted` writes and the
  `VolumePopoverController` itself: the seam, the clamp, and the rows are tested
  with fakes, but no volume write or on-screen slider was exercised in an app.
- The `AppearancePopoverController` itself: the seam, the selection model, and
  the rows are tested with fakes, but no appearance choice or on-screen popover
  was exercised in an app; whether the choice reaches the bar live is unobserved.

**Not verified at all — a human must supply (do not treat as working):**

- Any on-screen rendering, truncation, or readability of the widgets on a real
  display at real scales.
- Whether a click on a nonactivating panel actually reaches an item and opens
  the intended System Settings pane or the Wi-Fi/volume popover; the network
  item's Wi-Fi id is confirmed, but the remaining pane identifiers above are
  candidates and no click has been observed end to end.
- Whether a packaged app with Location **granted** lists real nearby networks in
  the popover (the human step in task 0070), and how the popover behaves with
  Location denied on that packaged app.
- Whether the volume slider actually moves the real default output's volume on
  the packaged app, and whether the bar item's icon and percentage follow it on
  screen (the human step in task 0071).
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
The network **provider** reads no SSID, so it never triggers a location prompt.
The Wi-Fi popover (task 0070) is the one part that reads network names, and it is
gated on Location authorization: without it the popover explains and links to
**Privacy & Security › Location Services** rather than showing an empty list.
Accessibility remains required only for the notched-display native-menu-bar
detector (0003/0009) and is unrelated to these widgets. A denied or failed
provider emits its own unavailable state and leaves the rest of the bar working.

## Commands

```sh
swift test --package-path macos
macos/.build/debug/divot --report    # display/menu-bar observation, one pass
macos/.build/debug/divot --widgets   # live built-in provider values, short window
```
