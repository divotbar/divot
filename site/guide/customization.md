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
  "version": 1,
  "appearance": {
    "mode": "system",
    "accent": "#D6F58A",
    "material": "native"
  },
  "layout": { "height": 32, "padding": 12, "notchGap": 10 },
  "workspaces": {
    "enabled": true,
    "adapter": "aerospace",
    "showEmpty": true
  },
  "status": ["front-app", "battery", "clock"]
}
```

## A smaller bar

For a distraction-free setup, use `examples/focus.json`: a 28-point opaque bar, occupied workspaces only, and a minute clock. For an opaque blue-accent layout, use `examples/opaque.json`.

## Ordering

The `status` array determines order on the right. Remove an identifier to disable that widget. Duplicates and unknown identifiers are errors. The first contract supports `front-app`, `battery`, and `clock`.

## Keep the center clear

`notchGap` adds space beside the system-reported camera housing; it does not set its width. Long labels should overflow into a menu, not cover the notch. The exact overflow implementation is part of the first app milestone.

See the [complete reference](../reference/configuration) before creating new configurations.
