# Colors, materials & moods

The visual direction is alpine: lake blue, pine green, and warm paper. The actual bar should feel at home in macOS and stay legible over a changing desktop.

## Appearance

Proposed `appearance.mode` values are `system`, `dark`, and `light`. `system` follows the Mac's appearance. An accent must be a six-digit hex color such as `#B7CEFF`; color is never the only way to identify a selected workspace.

## Materials

`native` requests a platform material; `opaque` uses a solid background. Respect Reduce Transparency even if a configuration requests material. Native material implementation and its performance comparison have not landed yet.

## Focus preset

```json
{
  "version": 1,
  "appearance": { "mode": "dark", "accent": "#D6F58A", "material": "opaque" },
  "layout": { "height": 28, "padding": 10, "notchGap": 12 },
  "workspaces": { "enabled": true, "adapter": "aerospace", "showEmpty": false },
  "status": ["clock"]
}
```

## Website preview

<BarPreview />

These browser presets communicate the visual direction. They are not exported native themes, and the static preview time/battery are sample data.

## Share a theme

Contribute a configuration example with a description and screenshot once the parser exists. Keep credentials out of examples. Test text contrast, focused/occupied states, notch and notch-free displays, and both appearance modes.

## Website appearance

The landing page's Light/Dark button and the docs appearance switch share the saved VitePress preference. The default website mode is dark; your choice persists across pages and reloads. This controls the website only. The future native app follows macOS by default, with explicit Light/Dark overrides.
