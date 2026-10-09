# Configuration reference

::: warning Proposed v1 contract
Validated examples exist; the native loader does not. This reference will become stable with native contract tests.
:::

## Root

| Field | Type | Rule |
| --- | --- | --- |
| `version` | Integer | Exactly `1` |
| `appearance` | Object | Required |
| `layout` | Object | Required |
| `workspaces` | Object | Required |
| `status` | String array | Ordered, unique built-in identifiers |

The starter validator rejects missing fields, unknown fields, wrong types, and invalid ranges. JSON does not support comments. No environment substitution or executable expressions are proposed.

## Appearance

| Field | Values |
| --- | --- |
| `mode` | `system`, `dark`, `light` |
| `accent` | Six-digit hex, e.g. `#B7CEFF` |
| `material` | `native`, `opaque` |

## Layout

All sizes are logical points, not physical pixels.

| Field | Range | Meaning |
| --- | --- | --- |
| `height` | 24–40 | Panel height; clamp to available safe top area |
| `padding` | 0–24 | Padding inside each panel |
| `notchGap` | 0–32 | Extra clearance beside the camera housing |

## Workspaces

| Field | Type / values |
| --- | --- |
| `enabled` | Boolean |
| `adapter` | `aerospace` |
| `showEmpty` | Boolean |

## Status

`front-app`, `battery`, `clock`. An empty array is allowed. Each may occur at most once.

```json
"status": ["battery", "clock"]
```

## Invalid reloads

The planned native loader keeps the last good snapshot and reports field paths with actionable errors. Initial startup without a file uses defaults. A future version must have an explicit migration; unknown versions must never be silently treated as version 1.

## Examples

See `examples/default.json`, `examples/focus.json`, and `examples/opaque.json` in the source repository. Run `bun run scripts/check-config.ts` to validate all three today.
