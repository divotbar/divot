# Make it yours

Start with a comfortable default, then remove whatever you don't need. The proposed configuration is deliberately small and readable.

::: warning Configuration proposal
The native parser and file watcher are not implemented yet. The examples are checked structurally by this repository; placing a file on your Mac will not launch or configure a Divot app today.
:::

<BarPreview />

## One file, one model

The intended location is `~/.config/divot/config.json`. Settings and file customization will share the same validated model. Changes apply atomically; an invalid edit leaves the last good configuration running.

```json
{
  "version": 2,
  "appearance": {
    "family": "native",
    "mode": "system",
    "accent": "#D6F58A",
    "material": "native"
  },
  "layout": { "height": 32, "padding": 12, "notchGap": 10 },
  "left": ["workspaces", "front-app"],
  "right": ["battery", "network", "volume", "clock"]
}
```

## Both sides, one model

The bar has two ordered groups, `left` and `right`. Each lists supported items, and an item lives in exactly one group, so you can add, remove, reorder, or move it between sides. Per-item options are namespaced under `widgets`, and omitting them keeps the built-in defaults.

## A smaller bar

For a distraction-free setup, use `examples/focus.json`: a 28-point opaque bar with occupied workspaces only and a minute clock without the day of week. For an opaque themed layout, use `examples/opaque.json`.

## Ordering

The `left` and `right` arrays determine order on each side. Remove an identifier to disable that item, or move it to the other group. Duplicates, unknown identifiers, and an item on both sides are errors. The first contract supports `workspaces`, `front-app`, `battery`, `network`, `volume`, and `clock`.

## Keep the center clear

`notchGap` adds space beside the system-reported camera housing; it does not set its width. Long labels should overflow into a menu, not cover the notch. The exact overflow implementation is part of the first app milestone.

See the [complete reference](../reference/configuration) before creating new configurations.
