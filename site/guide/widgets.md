# Widgets

A widget pairs a small native view with a provider that knows when its data changes. Rendering and collection are separate so a slow integration cannot stall the whole bar.

::: warning Pre-alpha status
The native providers below are implemented and unit-tested in the Swift package, but there is no signed app yet and they are not physically validated on hardware. On this website the bar preview uses static sample values; the running app (built from source) reads live local values.
:::

## Built-in items

| Identifier | Default side | Role | Update strategy |
| --- | --- | --- | --- |
| `workspaces` | left | Window-manager workspaces | Manager events or bounded refresh (AeroSpace and yabai adapters delivered; not physically validated) |
| `front-app` | left | Frontmost application | Workspace/application notifications |
| `battery` | right | Charge and power state; click toggles keep-awake | System power notifications |
| `date` | off by default | Local date | Emits immediately, then at each day boundary |
| `time` | right | Local time | Emits immediately, then at each minute boundary by default; seconds optional |
| `network` | right | Wi-Fi/network status; click opens the read-only Wi-Fi popover | Network path notifications |
| `volume` | right | Output volume; click opens the volume popover with a slider and mute | Audio notifications |
| `appearance` | off by default | Current light/dark mode (sun or moon); click opens the appearance popover to set the mode and theme family | System appearance notifications |

Both sides are ordered item groups and every supported item can move between them. The native app fills this default bar from built-in providers — no setup questionnaire and no shell polling. Workspace app icons and empty-state visibility are optional settings on `workspaces`.

The date and time are separate items (task 0033). The default `right` group is `battery`, `time`, `network`, `volume`: the time is on at first launch and the date is off. The date can include the weekday and the year, use a day-first order, a custom separator, or a custom pattern; the time can show seconds and use 24-hour, AM/PM, or a custom pattern. Both edit the `widgets.date` and `widgets.time` objects the [configuration reference](../reference/configuration) documents. The legacy combined `clock` item is accepted and migrated to `date`/`time` on load.

While the Mac is charging, the battery item draws the bolt as a separate badge in the theme accent green over the plain battery outline; the outline and label keep the normal foreground colour. When charging stops, there is no bolt.

Clicking the battery item toggles a Caffeine-style keep-awake assertion and shows a cup indicator while it is held. The cup and the charging bolt stay separate: the cup is the keep-awake state, the bolt is the charge state. The cup tracks Divot's own assertion only: another app preventing sleep — for example a call holding the microphone and speaker sleep assertions — does not show it while Divot's toggle is off. Keep-awake uses the public IOKit power-assertion API only; quitting the app releases any assertion it holds. Whether the state is remembered across launches is an opt-in setting (default off). This is implemented and unit-tested in the Swift package, not physically validated.

## Failure and unavailable states

A disabled provider removes its observers and cancels outstanding work. A failed provider gets an understandable unavailable state while the rest of the bar keeps working; a late background result from an old configuration or a disabled provider is ignored. A desktop Mac shows a settled no-battery state rather than an error.

## Permissions

The date, time, battery, volume, and frontmost-app items need no special permission themselves. Divot asks macOS for Accessibility once at launch when it is not already granted, because the notched-display menu-bar probe uses it; denying it leaves the rest of the bar running. The network item can optionally display the current Wi-Fi network name (SSID); this feature requires Location permission on macOS and is only requested when the user turns the toggle on. If permission is denied, the Settings row says so and links to the Location Services pane while the bar shows the icon only.

Listing nearby networks in the Wi-Fi popover also needs Location permission, because macOS gates network names on it. Divot does not prompt from the popover: without permission it shows a short message and a button that opens **System Settings → Privacy & Security → Location Services**, rather than an empty list.

## Click behavior

Divot does not mirror the system's menu extras. Each item has one explicit action: the frontmost-app item activates that app; the battery item toggles keep-awake; the appearance item opens an appearance popover to set Divot's own light/dark mode and theme family (it no longer toggles directly) and never changes the macOS system appearance; the date and time items open the matching System Settings pane; the network item opens a read-only Wi-Fi popover; and the volume item opens an output-volume popover with a slider and mute.

The Wi-Fi popover lists the nearby networks with their signal and a lock for secured ones, marks the connected network, and ends with **Open Wi-Fi Settings…**, which opens System Settings › Wi-Fi directly (falling back to the generic Network pane if that link cannot be opened). It is read-only: it never joins a network and never asks for a password. Divot scans once each time the popover opens — never on a timer — and the scan runs off the main thread with a timeout, so the popover always settles into a list, an empty state, or an error. This is implemented and unit-tested in the Swift package; the popover on screen is not physically validated yet.

The volume popover has a horizontal slider for the default output with its current percentage, a **Mute** toggle, and a final **Open Sound Settings…** row that opens the Sound pane. Moving the slider changes the output's volume, and the bar item's icon and percentage follow it. It uses public Core Audio only; there is no timer, and while the popover is open it follows changes made elsewhere (a keyboard volume key, another app) through property listeners that are removed when the popover closes. For an output with no settable volume — some HDMI/DisplayPort devices — the slider and mute are disabled and a short note explains why instead of offering a control that cannot do anything. This is implemented and unit-tested in the Swift package; whether the slider actually moves a real output's volume is checked on the packaged app, not claimed here.

The appearance popover sets Divot's own **System**/**Light**/**Dark** variant and the theme family (Native, Gruvbox, Ayu, Dracula, Tokyo Night) with keyboard-accessible radio choices that show the current selection, and ends with an **Open Divot Settings…** row that opens Divot's own settings window, not a System Settings pane. Both lists come from the same configuration fields the Settings window edits — a new family appears here automatically — and a choice applies immediately through the same atomic store, so the popover and the Settings window never disagree; while it is open it also follows a change made in the Settings window or the config file. It changes Divot's own rendering only and never the macOS system appearance. This is implemented and unit-tested in the Swift package; the popover on screen is not physically validated yet.

The date/time and Sound pane links still need validation on the target OS.

## Future script widgets

Scripts are a later milestone. The protocol should have output limits, deadlines, cancellation, and a documented data format. No script API is available yet; do not assume xbar or SketchyBar compatibility.

Scripts will be trusted local programs, not safely sandboxed by a timeout. The first release prioritizes native providers so a normal setup does not continually launch shell processes.
