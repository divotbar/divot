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
| `showOccupiedDot` | Boolean | Optional; show the occupied marker on workspace chips (default `true`) |
| `showEmptyDot` | Boolean | Optional; show the empty marker on workspace chips (default `true`) |
| `bottomShadow` | Boolean | Optional; draw a drop shadow along the bar's bottom edge (default `false`) |

The starter validator rejects missing fields, unknown fields, wrong types, and invalid ranges. An item may appear in only one group; `battery`, `network`, and `volume` accept no widget options yet. JSON does not support comments. No environment substitution or executable expressions are proposed.

## Appearance

| Field | Values |
| --- | --- |
| `family` | `native`, `gruvbox`, `ayu`, `dracula`, `tokyo-night` |
| `mode` | `system`, `dark`, `light` |
| `accent` | Six-digit hex, e.g. `#B7CEFF` |
| `material` | `native`, `opaque` |
| `palette` | Optional object; semantic color token overrides (see below) |

`family` and `mode` are independent: changing `mode` keeps the chosen family. `native` is the default and follows macOS appearance. The root `accent` defaults to `#D6F58A`; while it is left at that default a family uses its own signature accent, and any other value overrides the family. `material` is kept in the configuration contract, but the flat chrome always draws the solid `background` token, so `native` and `opaque` no longer change the bar fill.

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
| `height` | 24–40 | Panel height (default 32, matched to the camera-housing band); clamp to available safe top area |
| `padding` | 0–24 | Padding inside each panel |
| `notchGap` | 0–32 | Extra clearance beside the camera housing |

## Text

The bar's text size and font are an optional root `text` object. The icon scales with the text size so the two stay in proportion.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `size` | Number 10–20 | `14` | Bar text size in points; icon and chip sizes follow it |
| `font` | String | `""` | Installed font family name, or `""` for the system font |

`size` is the single knob: the status icon is two points larger and the workspace chip one point smaller, so changing it keeps the row in proportion. `font` accepts any installed font family name; a name that is not installed falls back to the system font at render time rather than failing the load. Settings exposes both controls and applies changes to the bar without a relaunch.

```json
"text": { "size": 16, "font": "Helvetica" }
```

## Bar icon

Divot can show its own mark at the start of the left group, before the workspace numbers. It is an optional root boolean, `showAppIcon`, off by default so the first-launch bar is unchanged.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `showAppIcon` | Boolean | `false` | Show the Divot mark before the workspaces; clicking it opens Divot settings |

The mark is the same template image as the menu-bar item, so it follows the bar's light and dark theme, and it scales with `text.size`. Settings has a matching toggle, and toggling it updates the bar live.

```json
"showAppIcon": true
```

## Workspace markers

Each non-focused workspace chip carries a small non-color occupancy marker: a filled dot for an occupied workspace and a hollow ring for an empty one (an uninspectable workspace keeps its own ring and has no toggle). Both markers are optional root booleans, on by default so the first-launch bar is unchanged. They are root fields rather than `widgets.workspaces` options because they change only the marker drawing, not the workspace feed.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `showOccupiedDot` | Boolean | `true` | Draw the filled dot on an occupied workspace chip |
| `showEmptyDot` | Boolean | `true` | Draw the hollow ring on an empty workspace chip |

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

Clicking the battery item toggles a Caffeine-style keep-awake assertion (public IOKit power assertions), and the battery shows a cup indicator while it is held. The optional root `keepAwake` object controls whether that state survives a relaunch. It is a root object rather than a `widgets.battery` option so it stays valid when the battery item is not placed.

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

Supported items: `workspaces`, `front-app`, `battery`, `network`, `volume`, `clock`. Leave `widgets` out to use the built-in defaults.

```json
"left": ["workspaces", "front-app"],
"right": ["battery", "clock", "network", "volume"]
```

Default left is `workspaces`, `front-app`; default right is `battery`, `clock`, `network`, `volume`. Both groups are configurable and items can move between them.

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
| `clock` | `weekday` | Boolean | Include the day of week |
| `clock` | `date` | Boolean | Include the date |
| `clock` | `seconds` | Boolean | Use second resolution instead of the default minute |

An options object may set any subset of its options. Built-in defaults: `workspaces` shows empty workspaces (`showEmpty: true`), hides app icons (`showAppIcons: false`), shows details (`showDetails: true`), and shows every icon when enabled (`maxAppIconsPerWorkspace` unset); `front-app` shows both icon and name; `clock` shows weekday and date at minute resolution (`seconds: false`). The native app applies every one of these options: `workspaces` options drive the workspace row, `front-app` and `clock` options drive that item's presentation.

## Invalid reloads

The native loader validates before applying: a bad edit or a bad file reports the failing field path and keeps the last good snapshot running, so the bar never picks up a broken document. Initial startup without a file uses the built-in defaults. The store writes atomically and copies a version 1 original to `config-v1-backup.json` before rewriting it. A future version needs an explicit migration; unknown versions are rejected, never silently treated as version 2.

## Migration from version 1

Version 1 was a pre-release draft with workspaces hard-coded on the left and a `status` array on the right. It never shipped. The loader migrates it on open: `workspaces` becomes the left group, its options move under `widgets.workspaces`, and each `status` identifier becomes part of `right`. The fixtures under `examples/migrations/` (`v1-default.json`, `v1-focus.json`) document the old shape and are validated during web checks.

## Examples

See `examples/default.json`, `examples/focus.json`, `examples/opaque.json`, `examples/custom-palette.json`, `examples/keep-awake.json`, and `examples/app-icon.json` in the source repository. Run `bun run scripts/check-config.ts` to validate all of them and the version 1 migration fixtures today.

## Custom palettes and theme sharing

Custom palette overrides and theme sharing use the same v2 configuration contract, not a separate file format. A shared theme is a configuration example with a description and screenshot: set `appearance.family` for the base look, then override individual tokens under `appearance.palette` for personal tweaks. Keep credentials and machine-specific paths out of shared examples, and label any light adaptation that is not an official upstream variant. The parser, store, and theme resolver validate, persist, and apply these examples; the four families ship with official light and dark variants.
