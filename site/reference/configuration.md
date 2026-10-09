# Configuration reference

::: warning Proposed v2 contract
Validated examples exist; the native loader does not. This reference will become stable with native contract tests.
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

`family` and `mode` are independent: changing `mode` keeps the chosen family. `native` is the default and follows macOS appearance.

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
"right": ["battery", "network", "volume", "clock"]
```

Default left is `workspaces`, `front-app`; default right is `battery`, `network`, `volume`, `clock`. Both groups are configurable and items can move between them.

## Widget options

| Namespace | Option | Type | Meaning |
| --- | --- | --- | --- |
| `workspaces` | `adapter` | `aerospace` | Window-manager adapter; `yabai` is a later milestone |
| `workspaces` | `showEmpty` | Boolean | Show workspaces with no windows |
| `workspaces` | `showAppIcons` | Boolean | Show optional per-workspace app icons |
| `front-app` | `showIcon` | Boolean | Show the application icon |
| `front-app` | `showName` | Boolean | Show the application name |
| `clock` | `weekday` | Boolean | Include the day of week |
| `clock` | `date` | Boolean | Include the date |
| `clock` | `seconds` | Boolean | Use second resolution instead of the default minute |

An options object may set any subset of its options. Built-in defaults: `workspaces` shows empty workspaces (`showEmpty: true`) and hides app icons (`showAppIcons: false`); `front-app` shows both icon and name; `clock` shows weekday and date at minute resolution (`seconds: false`).

## Invalid reloads

The planned native loader keeps the last good snapshot and reports field paths with actionable errors. Initial startup without a file uses defaults. A future version must have an explicit migration; unknown versions must never be silently treated as version 2.

## Examples

See `examples/default.json`, `examples/focus.json`, and `examples/opaque.json` in the source repository. Run `bun run scripts/check-config.ts` to validate all three today.
