# Colors, materials & moods

The visual direction is alpine: lake blue, pine green, and warm paper. The actual bar should feel at home in macOS and stay legible over a changing desktop.

## Theme families (planned)

Alongside the comfortable native default, Divot ships four curated hacker families: Gruvbox, Ayu, Dracula, and Tokyo Night. Family and appearance are separate settings, so switching between System, Light, and Dark keeps the chosen family. Where a family has no official light variant, Divot's adaptation is labeled as its own. Semantic color tokens carry foreground, background, accent, selected, occupied, and error roles, and color alone never identifies a selected workspace. No family is delivered until its native surfaces exist.

## Appearance

Proposed `appearance.mode` values are `system`, `dark`, and `light`. `system` follows the Mac's appearance. An accent must be a six-digit hex color such as `#B7CEFF`; color is never the only way to identify a selected workspace.

## Materials

`native` requests a platform material; `opaque` uses a solid background. Respect Reduce Transparency even if a configuration requests material. Native material implementation and its performance comparison have not landed yet.

## Focus preset

```json
{
  "version": 2,
  "appearance": { "family": "gruvbox", "mode": "dark", "accent": "#D6F58A", "material": "opaque" },
  "layout": { "height": 28, "padding": 10, "notchGap": 12 },
  "left": ["workspaces"],
  "right": ["clock"],
  "widgets": { "workspaces": { "showEmpty": false }, "clock": { "weekday": false, "date": true } }
}
```

## Website preview

<BarPreview />

These browser presets communicate the visual direction. They are not exported native themes, and the static preview time/battery are sample data.

## Share a theme

Contribute a configuration example with a description and screenshot once the parser exists. Keep credentials out of examples. Test text contrast, focused/occupied states, notch and notch-free displays, and both appearance modes.

## Website appearance

The landing page's Light/Dark button and the docs appearance switch share the saved VitePress preference. The default website mode is dark; your choice persists across pages and reloads. This controls the website only. The future native app follows macOS by default, with explicit Light/Dark overrides.
