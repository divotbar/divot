# Configuration reference

::: info Version 2
The native parser, store, migration, and settings surface are implemented and validated against these examples. Theme family colors and custom palettes are parsed and persisted but land with the separate theme milestone.
:::

## Root

| Field | Type | Rule |
| --- | --- | --- |
| `version` | Integer | Exactly `2` |
| `appearance` | Object | Required |
| `layout` | Object | Required |
| `left` | String array | Ordered, unique items on the left |
| `right` | String array | Ordered, unique items on the right |
| `widgets` | Object | Optional; namespaced per-item options |

The starter validator rejects missing fields, unknown fields, wrong types, and invalid ranges. An item may appear in only one group; `battery`, `network`, and `volume` accept no options yet. JSON does not support comments. No environment substitution or executable expressions are proposed.

## Appearance

| Field | Values |
| --- | --- |
| `family` | `native`, `gruvbox`, `ayu`, `dracula`, `tokyo-night` |
| `mode` | `system`, `dark`, `light` |
| `accent` | Six-digit hex, e.g. `#B7CEFF` |
| `material` | `native`, `opaque` |
| `palette` | Optional object; semantic color token overrides (see below) |

`family` and `mode` are independent: changing `mode` keeps the chosen family. `native` is the default and follows macOS appearance.

## Palette overrides

`appearance.palette` is an optional object that overrides individual semantic color tokens of the chosen family and variant. Each token is a six-digit hex color. Supported tokens are `foreground`, `background`, `accent`, `selected`, `occupied`, and `error`. Set only the tokens you want to change; the rest stay with the family. `palette.accent` takes precedence over the root `accent`. The parser and store validate and persist palette overrides; the theme milestone applies them to the bar.

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
| `height` | 24–40 | Panel height; clamp to available safe top area |
| `padding` | 0–24 | Padding inside each panel |
| `notchGap` | 0–32 | Extra clearance beside the camera housing |

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
| `workspaces` | `adapter` | `aerospace` | Window-manager adapter; `yabai` is a later milestone |
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

See `examples/default.json`, `examples/focus.json`, `examples/opaque.json`, and `examples/custom-palette.json` in the source repository. Run `bun run scripts/check-config.ts` to validate all four and the version 1 migration fixtures today.

## Custom palettes and theme sharing

Custom palette overrides and theme sharing use the same v2 configuration contract, not a separate file format. A shared theme is a configuration example with a description and screenshot: set `appearance.family` for the base look, then override individual tokens under `appearance.palette` for personal tweaks. Keep credentials and machine-specific paths out of shared examples, and label any light adaptation that is not an official upstream variant. The parser and store validate and persist these examples today; the theme milestone applies family and palette colors to the bar, so a shared example does not repaint the bar until then.
