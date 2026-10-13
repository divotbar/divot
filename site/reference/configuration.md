# Configuration reference

::: info Version 2
The native parser, store, migration, settings surface, and theme resolution are implemented and validated against these examples. Theme family colors and custom palettes are applied to the bar.
:::

## Root

| Field | Type | Rule |
| --- | --- | --- |
| `version` | Integer | Exactly `2` |
| `appearance` | Object | Required |
| `layout` | Object | Required |
| `text` | Object | Optional; text size and font for the bar |
| `left` | String array | Ordered, unique items on the left |
| `right` | String array | Ordered, unique items on the right |
| `widgets` | Object | Optional; namespaced per-item options |
| `keepAwake` | Object | Optional; keep-awake persistence (see below) |
| `showAppIcon` | Boolean | Optional; show the Divot mark before the workspaces (default `false`) |
| `showOccupiedDot` | Boolean | Optional; show the occupied marker on workspaces (default `true`) |
| `showEmptyDot` | Boolean | Optional; show the empty marker on workspaces (default `true`) |
| `bottomShadow` | Boolean | Optional; draw a drop shadow along the bar's bottom edge (default `false`) |
| `chipStyle` | Boolean | Optional; draw a rounded chip on the right-side items and the selected workspace (default `false`) |
| `chipOpacity` | Integer 0–100 | Optional; fade every drawn chip's background (default `0`) |
| `appIconSize` | Number 8–24 | Optional; point size of the app icons on the left (default `16`, the status icon size) |

The starter validator rejects missing fields, unknown fields, wrong types, and invalid ranges. An item may appear in only one group. JSON does not support comments. No environment substitution or executable expressions are proposed.

## Appearance

| Field | Values |
| --- | --- |
| `family` | `native`, `alpine`, `gruvbox`, `ayu`, `dracula`, `tokyo-night` |
| `mode` | `system`, `dark`, `light` |
| `accent` | Six-digit hex, e.g. `#B7CEFF` |
| `material` | `native`, `opaque` |
| `palette` | Optional object; semantic color token overrides (see below) |

`family` and `mode` are independent: changing `mode` keeps the chosen family. `native` is the default and follows macOS appearance. The root `accent` defaults to `#D6F58A`; while it is left at that default a family uses its own signature accent, and any other value overrides the family. `material` is kept in the configuration contract, but the flat chrome always draws the solid `background` token, so `native` and `opaque` no longer change the bar fill.

The bar's `appearance` item opens an appearance popover anchored to the item: a horizontal **System** / **Light** / **Dark** segmented control and a vertical list of the theme families (`Native`, `Alpine`, `Gruvbox`, `Ayu`, `Dracula`, `Tokyo Night`), each row left-aligned and showing a colour swatch drawn from that theme's own palette and the family name, with the current theme clearly marked, then an **Open Divot Settings…** row that opens Divot's own settings window. The popover has a solid, opaque background (from the theme's palette), a thin border, and rounded corners, so it renders predictably regardless of what is behind it; content is left-aligned throughout (title, labels, rows, links). Footer links use the theme's contrast-adjusted link colour to guarantee readability against the solid background in every family and mode. Choosing a value applies immediately through the same atomic store the Settings window and `divot theme` use, and while the popover is open it follows a change made elsewhere. The item no longer toggles light/dark directly, and it never changes the macOS system appearance.

## Palette overrides

`appearance.palette` is an optional object that overrides individual semantic color tokens of the chosen family and variant. Each token is a six-digit hex color. Supported tokens are `foreground`, `background`, `accent`, `selected`, `occupied`, and `error`. Set only the tokens you want to change; the rest stay with the family. `palette.accent` takes precedence over the root `accent`. The parser, store, and theme resolver validate, persist, and apply palette overrides; derived chrome roles follow an overridden base.

```json
"appearance": {
  "family": "gruvbox",
  "mode": "dark",
  "accent": "#D6F58A",
  "material": "opaque",
  "palette": { "foreground": "#EBDBB2", "background": "#282828", "accent": "#B8BB26", "error": "#FB4934" }
}
```

## Layout

All sizes are logical points, not physical pixels.

| Field | Range | Meaning |
| --- | --- | --- |
| `height` | 24–40 | Panel height. Left at the default `32`, the bar computes the row height from the display's native menu-bar band at run time (the camera-housing top on a notched display, the native menu-bar height on a notch-free one) so the row lines up with the system bar; `32` remains the fallback when the band cannot be read. Clamp to available safe top area |
| `padding` | 0–24 | Padding inside each panel |
| `rightItemSpacing` | 0–32 | Gap between right-side items (default 8) |
| `leftItemSpacing` | 0–32 | Gap between left-side items (default 8); the Divot-icon-to-workspace gap and the front-app gap both follow it |

Item spacing is independent per side and defaults to the pre-#0054 uniform 8 points. Settings exposes both side spacings as sliders. A fixed 17-point inset is always left between the rightmost item and the screen edge so the camera-in-use indicator never overlaps the bar.

`layout.height` keeps its stored default of `32`, but when it is left there the app resolves the effective row height per display from the native menu-bar band (`DivotCore.ScreenGeometry.defaultBarHeight`): the camera-housing top on a notched display and the native menu-bar height on a notch-free one. `32` is the fallback when that band is unknown, and an explicit non-default height always wins.

On notched displays the bar hugs the notch with zero padding and the color extends 6 points into the notch area to cover the gap and corners. Legacy configuration files may contain a `notchGap` field; it is ignored during load and omitted when the file is next saved.

## Text

The bar's text size and font are an optional root `text` object. The icon scales with the text size so the two stay in proportion.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `size` | Number 10–20 | `14` | Bar text size in points; icon and chip sizes follow it |
| `font` | String | `""` | Installed font family name, or `""` for the system font |

`size` is the single knob: the status icon is two points larger and the chip font one point smaller, so changing it keeps the row in proportion. The battery, network and volume symbols draw at that status icon size, matched to the native menu-bar symbol size (16 pt by default), so the three scale with this setting; the other items keep the compact square status-icon box. The app icons drawn on the left default to the status icon size and are controlled separately by `appIconSize`. `font` accepts any installed font family name; a name that is not installed falls back to the system font at render time rather than failing the load. Settings exposes these controls and applies changes to the bar without a relaunch.

```json
"text": { "size": 16, "font": "Helvetica" }
```

## Bar icon

Divot can show its own mark at the start of the left group, before the workspace numbers. It is an optional root boolean, `showAppIcon`, off by default so the first-launch bar is unchanged.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `showAppIcon` | Boolean | `false` | Show the Divot mark before the workspaces; clicking it opens Divot settings |

The mark is the same template image as the menu-bar item, so it follows the bar's light and dark theme, and it scales with the app icon size. Settings has a matching toggle, and toggling it updates the bar live.

```json
"showAppIcon": true
```

## Chips and opacity

With `chipStyle` on, every right-side status item and the selected workspace sit in the same rounded chip with the same padding, size, and theme colour; unselected workspaces stay a plain number plus app icons with no background, border, or padding. Off (the default), no chip is drawn and items blend together, so the focused workspace is shown by its semibold title rather than a box. `chipOpacity` fades the background of every chip that is drawn on the bar; `0` keeps the current appearance and `100` makes the chip background match the bar background, leaving only the content. `appIconSize` sets the point size (8–24) of the app icons drawn on the left: the per-workspace app icons and the Divot mark. It defaults to `16`, the status icon size, so the left icons match the right-side ones.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `chipStyle` | Boolean | `false` | Draw a rounded chip on the right-side items and the selected workspace |
| `chipOpacity` | Integer 0–100 | `0` | Fade every drawn chip's background; `100` matches the bar background |
| `appIconSize` | Number 8–24 | `16` | Point size of the app icons on the left (workspace chips and the Divot mark) |

```json
"chipStyle": true,
"chipOpacity": 40,
"appIconSize": 18
```

## Workspace markers

Each non-focused workspace carries a small non-color occupancy marker: a filled dot for an occupied workspace and a hollow ring for an empty one (an uninspectable workspace keeps its own ring and has no toggle). Both markers are optional root booleans, on by default so the first-launch bar is unchanged. They are root fields rather than `widgets.workspaces` options because they change only the marker drawing, not the workspace feed.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `showOccupiedDot` | Boolean | `true` | Draw the filled dot on an occupied workspace |
| `showEmptyDot` | Boolean | `true` | Draw the hollow ring on an empty workspace |

Hiding a marker leaves the workspace name and the focused highlight, so a workspace stays identifiable. Settings has a matching toggle for each, and toggling one updates the bar live and survives a relaunch.

```json
"showOccupiedDot": false
```

## Flat chrome

The bar draws one flat colour from the left screen edge to the right, with square corners and no highlight, bevel, or gradient. The workspace and item chips are flat too; the focused chip keeps a flat accent stroke. A subtle drop shadow along the bottom edge is optional and off by default.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `bottomShadow` | Boolean | `false` | Draw a drop shadow along the bar's bottom edge |

The shadow is a soft gradient drawn just below the bar, so it runs along the bottom edge only and never rims the other edges. Settings has a matching toggle, and toggling it updates the bar live.

```json
"bottomShadow": true
```

## Keep awake

Clicking the battery item toggles a Caffeine-style keep-awake assertion (public IOKit power assertions), and the battery shows a cup indicator while it is held. The cup uses a fixed green pair — `#0B6B3A` on a light bar, `#7BD88F` on a dark one — independent of the theme accent, so it clears the 3:1 non-text floor against every family's bar background. The default chip is an opaque `selected` fill that can hide that green, so the cup is audited against the composited chip fill too and, where the green cannot clear 3:1, is stroked with a thin black or white outline (whichever contrasts more with the chip) rather than a shadow or blur (task 0087). The cup reflects Divot's own assertion only, not system-wide sleep prevention: another app that prevents sleep while Divot's toggle is off does not show it. The optional root `keepAwake` object controls whether that state survives a relaunch. It is a root object rather than a `widgets.battery` option so it stays valid when the battery item is not placed.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `remember` | Boolean | `false` | Persist the on/off state across launches |
| `isActive` | Boolean | `false` | The remembered state; only meaningful when `remember` is `true` |

With no `keepAwake` object (or `remember: false`), keep-awake always starts off at launch. `isActive` is written only while `remember` is on.

```json
"keepAwake": { "remember": true, "isActive": true }
```

## Menu bar

When the native menu bar is auto-hidden, macOS reveals it as the pointer reaches the top edge of a display. Divot follows that pointer reveal by default through an event-driven mouse-moved monitor (no polling): while the pointer is in a display's top strip Divot sits below the native bar, and when it leaves Divot returns to the top edge. A notch-free display's own `visibleFrame` is the cross-check, so a reading that disagrees with the geometry is corrected rather than followed.

On notched hardware the camera housing masks the same top band whether the native menu bar is hidden or revealed, so screen geometry alone cannot say which. The permission-gated Accessibility observation of the bar's own on-screen frame can. It is **off** by default because the on-screen heuristic is hardware-sensitive. `alwaysBelow` is the fallback for a Mac where the cursor reveal does not line up.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `moveBelowOnCursorReveal` | Boolean | `true` | Follow the native menu bar's reveal from the pointer reaching the top strip |
| `alwaysBelow` | Boolean | `false` | Fallback: keep Divot below the native menu bar at all times |
| `trustAccessibilityProbe` | Boolean | `false` | Let the Accessibility observation decide the masked (notched) case |

Turning `moveBelowOnCursorReveal` off leaves Divot in its current placement; the Accessibility path then decides the notched case only when `trustAccessibilityProbe` is on.

```json
"menuBar": { "moveBelowOnCursorReveal": true, "alwaysBelow": false, "trustAccessibilityProbe": true }
```

## Items

Supported items: `workspaces`, `front-app`, `battery`, `network`, `volume`, `date`, `time`, `appearance`. Leave `widgets` out to use the built-in defaults.

```json
"left": ["workspaces", "front-app"],
"right": ["battery", "time", "network", "volume"]
```

Default left is `workspaces`, `front-app`; default right is `battery`, `time`, `network`, `volume`. Both groups are configurable and items can move between them. The `date` item shows the current date; clicking it opens a calendar popover with a month grid, back/forward navigation, a Today button, and a row to open Date & Time settings. The `time` item shows the current time; clicking it opens a world clock popover with the local time and date (with the timezone name and UTC offset), followed by any added timezones from `widgets.time.timezones`, each with the time, hour offset from local (e.g., "2 h ahead", "30 min behind"), and a day label (Yesterday/Tomorrow) only when the day differs from local. Timezones are stored as an ordered array of IANA identifiers (e.g., `America/Los_Angeles`, `Asia/Tokyo`); duplicates are removed and an identifier that is not a known zone is ignored when the popover renders rather than breaking the config, while `divot config set` rejects an unknown identifier with an error. The popover's last row opens Date & Time settings. The `appearance` item shows the current light/dark mode; clicking it opens the appearance popover described above (mode and theme family through the same store as the Settings window, and a row that opens Divot's own settings window). It changes Divot's own rendering only, never the macOS system appearance. The legacy combined `clock` item is still accepted and migrated to `date`/`time` on load.

## Widget options

| Namespace | Option | Type | Meaning |
| --- | --- | --- | --- |
| `workspaces` | `adapter` | `aerospace`, `yabai` | Window-manager adapter; unset uses the deterministic priority |
| `workspaces` | `showEmpty` | Boolean | Show workspaces with no windows |
| `workspaces` | `showAppIcons` | Boolean | Show optional per-workspace app icons (each deduplicated app, not just the first) |
| `workspaces` | `showDetails` | Boolean | Show workspace detail: app count and the current-program label |
| `workspaces` | `maxAppIconsPerWorkspace` | Integer 0–32 | Cap app icons per workspace; unset shows all |
| `front-app` | `showIcon` | Boolean | Show the application icon |
| `front-app` | `showName` | Boolean | Show the application name |
| `battery` | `showPercentage` | Boolean | Show the battery percentage (default `true`) |
| `date` | `weekday` | Boolean | Include the day of week (default `true`) |
| `date` | `year` | Boolean | Include the year (default `false`) |
| `date` | `dayFirst` | Boolean | Show the day before the month (default `false`) |
| `date` | `separator` | String | Separator between date components (default `" "`) |
| `date` | `customPattern` | String | Custom date format pattern; an invalid pattern falls back to the generated one |
| `time` | `seconds` | Boolean | Show seconds (default `false`) |
| `time` | `timeFormat` | `24-hour`, `AM/PM`, `custom` | Time format (default `AM/PM`) |
| `time` | `customPattern` | String | Custom time pattern, used when `timeFormat` is `custom` |
| `time` | `timezones` | Array of strings | User's added timezones (IANA identifiers, e.g., `America/Los_Angeles`); default empty |
| `network` | `showWifiName` | Boolean | Show the connected Wi-Fi network name (default `false`; asks for Location permission) |
| `volume` | `showVolumePercent` | Boolean | Show the volume percentage (default `true`) |
| `volume` | `showVolumeMuted` | Boolean | Show the muted indicator (default `true`) |

An options object may set any subset of its options. Built-in defaults: `workspaces` shows empty workspaces (`showEmpty: true`), hides app icons (`showAppIcons: false`), shows details (`showDetails: true`), and shows every icon when enabled (`maxAppIconsPerWorkspace` unset); `front-app` shows both icon and name; `battery` shows the percentage; `date` shows the weekday, hides the year, and follows the system date order; `time` shows minutes in 12-hour form; `network` hides the Wi-Fi name; `volume` shows the percentage and the muted indicator. The native app applies every one of these options: `workspaces` options drive the workspace row, and the others drive that item's presentation.

## Command-line interface

The `divot` binary has a `config` subcommand for agents and scripts. It edits the same `~/.config/divot/config.json` document through the same parser and atomic store the app and Settings window use, so a value it accepts loads natively and a value it rejects leaves the last good file in place. The running app watches the file's directory, so an edit takes effect without a restart: a valid change is applied and an invalid one is refused while the app keeps the last valid configuration. There is no daemon, no network API, and no runtime dependency.

```bash
divot config schema --json          # every setting: key, type, range, default, description
divot config show --json            # the effective document
divot config get widgets.time.seconds
divot config set widgets.time.seconds true
divot config set layout.height 30 --dry-run --diff
divot config unset keepAwake.remember
divot config validate --file ./config.json
divot items list --json
divot items add date --side left --at 0
divot items move workspaces --side right
divot theme set gruvbox --mode dark
divot status --json                 # app, permissions, workspace adapter, config
```

Keys are dotted JSON paths (`appearance.mode`, `layout.leftItemSpacing`, `widgets.workspaces.showAppIcons`, `menuBar.alwaysBelow`). `schema --json` describes every documented field above and is generated from the same model the loader and Settings UI use, so the list cannot drift. An invalid edit names the field and its valid values (`layout.height: expected 24–40`). `set` validates before writing, `--dry-run` validates without writing, and `--diff` shows the changed lines. `unset` restores the declared default (removing it from the file when the default is omitted). Exit codes: `0` success, `1` invalid value or file, `2` usage error.

`divot status --json` reports the app version, whether a Divot app instance is running, the Accessibility and Location permission readings, the detected workspace adapter (AeroSpace or yabai, with every supported manager found and where the choice came from), and the config path with its validity and migration state. It is read-only: it never prompts for or grants a permission, launches the app, or writes a file. A missing permission is reported with the System Settings pane to open — `Privacy & Security › Accessibility` or `Privacy & Security › Location Services` — and an invalid config is listed as a problem, noting that the running app keeps the last valid configuration. The plain form is the same reading in words; `--json` is for scripts and agents.

The `items` and `theme` subcommands are focused helpers over the same `left`/`right` and `appearance` fields, for the two edits that come up most. `divot items list|add|remove|move` reads and writes the ordered groups: `add` appends to the right unless `--side` says otherwise, `move` keeps the item's current side unless `--side` is given, `--at` names a zero-based slot, and removing an item also clears its per-item options so the document stays valid. An unknown or legacy (`clock`) spelling, adding an item that is already placed, and an `--at` outside the destination group are refused. `divot theme set <family> [--mode system|dark|light]` validates through the same schema as `divot config set appearance.family`/`appearance.mode` and keeps the current mode when `--mode` is omitted. Both write atomically through the same store and use the same exit codes: `0` success, `1` invalid item/value or file, `2` usage error. There is a copy-pasteable ["set up Divot with your AI"](/guide/ai-setup) prompt built on `divot config schema --json` and `divot status --json`.

## Invalid reloads

The native loader validates before applying: a bad edit or a bad file reports the failing field path and keeps the last good snapshot running, so the bar never picks up a broken document. Initial startup without a file uses the built-in defaults. The store writes atomically and copies a version 1 original to `config-v1-backup.json` before rewriting it. A future version needs an explicit migration; unknown versions are rejected, never silently treated as version 2.

## Migration from version 1

Version 1 was a pre-release draft with workspaces hard-coded on the left and a `status` array on the right. It never shipped. The loader migrates it on open: `workspaces` becomes the left group, its options move under `widgets.workspaces`, and each `status` identifier becomes part of `right`. The fixtures under `examples/migrations/` (`v1-default.json`, `v1-focus.json`) document the old shape and are validated during web checks.

## Examples

See `examples/default.json`, `examples/focus.json`, `examples/opaque.json`, `examples/custom-palette.json`, `examples/keep-awake.json`, and `examples/app-icon.json` in the source repository. Run `bun run scripts/check-config.ts` to validate all of them and the version 1 migration fixtures today.

## Custom palettes and theme sharing

Custom palette overrides and theme sharing use the same v2 configuration contract, not a separate file format. A shared theme is a configuration example with a description and screenshot: set `appearance.family` for the base look, then override individual tokens under `appearance.palette` for personal tweaks. Keep credentials and machine-specific paths out of shared examples, and label any light adaptation that is not an official upstream variant. The parser, store, and theme resolver validate, persist, and apply these examples; every family ships with official light and dark variants.
