# Make it yours

Start with a comfortable default, then remove whatever you don't need. The configuration is deliberately small and readable.

::: info Configuration is implemented in the source app
The versioned parser, atomic store, file watcher, and settings window are implemented and validated by this repository. A packaged release is still pending, so there is no downloaded app to drop a file into yet; the examples describe the model the app already reads.
:::

<BarPreview />

## One file, one model

The intended location is `~/.config/divot/config.json`. Settings, the `divot config` command, and file customization share the same validated model. Changes apply atomically, and the running app watches the file, so a valid edit takes effect without a restart; an invalid edit leaves the last good configuration running.

```json
{
  "version": 2,
  "appearance": {
    "family": "native",
    "mode": "system",
    "accent": "#D6F58A",
    "material": "native"
  },
  "layout": { "height": 24, "padding": 6 },
  "text": { "size": 14, "font": "" },
  "left": ["workspaces", "front-app"],
  "right": ["battery", "time", "network", "volume"]
}
```

If you would rather not edit the file by hand, the same document is available from the command line, which is the discoverable path for an AI agent:

```bash
divot config schema --json          # every setting with its type, range, and default
divot config set appearance.family gruvbox
divot config set widgets.time.seconds true --diff
divot config unset keepAwake.remember
divot status --json                 # version, running state, permissions, adapter, config
```

Keys are dotted JSON paths and the edits validate through the same parser the app uses. `divot status --json` is the read-only way to check what the app currently sees: version, running state, Accessibility and Location permissions, the workspace adapter, and the config path and validity. It never grants a permission; a missing one is reported with the System Settings pane to open. See the [configuration reference](../reference/configuration#command-line-interface) for the full command list.

## Both sides, one model

The bar has two ordered groups, `left` and `right`. Each lists supported items, and an item lives in exactly one group, so you can add, remove, reorder, or move it between sides. Per-item options are namespaced under `widgets`, and omitting them keeps the built-in defaults.

## A smaller bar

For a distraction-free setup, use `examples/focus.json`: a 28-point opaque bar with occupied workspaces only and a minute clock without the day of week. For an opaque themed layout, use `examples/opaque.json`.

## Your own type

The optional `text` object sets the bar's `size` (10–20 points, default 14) and `font` (an installed family name, or `""` for the system font). The icon scales with the text so the two stay in proportion, and Settings exposes both controls with the same live, validated behavior as the file. A font that is not installed falls back to the system font rather than failing the load.

```json
"text": { "size": 16, "font": "Helvetica" }
```

## Your own palette

Themes share the one configuration model, so you are not limited to a family's stock colors. Add `appearance.palette` to override individual semantic tokens—`foreground`, `background`, `accent`, `selected`, `occupied`, `error`—as six-digit hex, and `examples/custom-palette.json` shows a Gruvbox base with overrides. The parser, store, and theme resolver keep and apply these overrides; the derived chrome roles follow an overridden base.

## Ordering

The `left` and `right` arrays determine order on each side. Remove an identifier to disable that item, or move it to the other group. Duplicates, unknown identifiers, and an item on both sides are errors. The contract supports `workspaces`, `front-app`, `battery`, `network`, `volume`, `date`, `time`, and `appearance`; the legacy combined `clock` is migrated to `date`/`time` on load.

## Notched displays

On a Mac with a notch, the bar hugs the camera housing with zero padding and the color extends 6 points into the notch area so the gap and rounded corners stay covered. Long labels should overflow into a menu, not cover the notch. The exact overflow implementation is part of the first app milestone.

See the [complete reference](../reference/configuration) before creating new configurations.
