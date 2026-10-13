# Colors, materials & moods

The visual direction is alpine: lake blue, pine green, and warm paper. The actual bar should feel at home in macOS and stay legible over a changing desktop.

## Theme families

Alongside the comfortable native default, Divot ships four curated hacker families: **Gruvbox**, **Ayu**, **Dracula**, and **Tokyo Night**. Family and appearance are separate settings, so switching between System, Light, and Dark keeps the chosen family.

The native family follows macOS semantic colors and the system accent, so it keeps vibrancy and accessibility behavior. The four families resolve to semantic color tokens — foreground, background, accent, selected, occupied, and error — and repaint the bar's background, border, item text and icons, selected/occupied/disabled workspace states, and error text. The charging mark is the exception: it is one fixed green on every family, never the theme accent, so charging is unmistakable even when a family's accent is purple or blue. Color alone never identifies a selected workspace: focus is also the control's selected state and an accessibility value, and occupancy has a shape marker.

Every family ships a light and a dark variant, pinned to its upstream palette with source and license recorded per variant:

| Family | Dark | Light | Upstream | License |
| --- | --- | --- | --- | --- |
| Gruvbox | Gruvbox Dark (medium) | Gruvbox Light (medium) | [morhetz/gruvbox](https://github.com/morhetz/gruvbox) | MIT |
| Ayu | Ayu Dark | Ayu Light | [ayu-theme/ayu-colors](https://github.com/ayu-theme/ayu-colors) | MIT |
| Dracula | Dracula | Alucard | [dracula/dracula-theme](https://github.com/dracula/dracula-theme) | MIT |
| Tokyo Night | Tokyo Night | Tokyo Night Light | [enkia/tokyo-night-vscode-theme](https://github.com/enkia/tokyo-night-vscode-theme) | MIT |

Alucard is Dracula's official light variant, and Tokyo Night Light is the upstream light variant of the same theme, so no family relies on an invented palette. Ayu Light is official too; Divot darkens its accent, occupied, and error roles so a focused or occupied state stays legible over a wallpaper, and the app labels that tuning rather than calling the tuned colors stock.

## Contrast

Each variant is tested against a per-role contrast floor: body text clears WCAG AA (4.5:1) on the background and surface, the selected label clears AA on its state, error and occupancy and the accent clear the 3:1 non-text floor, and the fixed charging green clears 3:1 against every family's background in both light and dark. Disabled text stays visible. The fixtures live in the `DivotCore` theme tests. Physical readability on a real display still needs human QA.

## Appearance

`appearance.mode` values are `system`, `dark`, and `light`. `system` follows the Mac's appearance; an explicit override applies app-wide, so the bar, settings window, menus, and popovers agree. Changing family or mode invalidates appearance-dependent caches only and does not restart providers. An accent must be a six-digit hex color such as `#B7CEFF`; leaving it at the built-in default uses each family's signature accent. From the command line, `divot theme set gruvbox --mode dark` writes the same fields, `divot theme show --json` reads them back, and omitting `--mode` keeps the current mode.

The bar's `appearance` item opens an appearance popover that sets the `mode` and `family` with a horizontal **System**/**Light**/**Dark** segmented control and a wrapped swatch grid of theme families — each option shows a colour swatch drawn from that theme's own palette — and a final **Open Divot Settings…** row. Both lists come from these same fields, so a family added to the contract appears in the popover automatically, and a choice writes through the same store the Settings window uses. The item no longer toggles light/dark directly; it never changes the macOS system appearance.

## Custom palette overrides

A family is a starting point, not a cage. Under the same v2 configuration contract, `appearance.palette` overrides individual semantic color tokens—`foreground`, `background`, `accent`, `selected`, `occupied`, `error`—as six-digit hex values merged over the chosen family and variant. Set only what you want to change. `palette.accent` takes precedence over the root `accent`, and the derived chrome roles (muted and disabled text, surface, border, selected label) follow an overridden base.

```json
"appearance": {
  "family": "gruvbox",
  "mode": "dark",
  "accent": "#D6F58A",
  "material": "opaque",
  "palette": { "selected": "#458588", "occupied": "#83A598", "error": "#FB4934" }
}
```

The parser, store, and theme resolver validate, persist, and apply this shape. Complete examples live in the [configuration reference](../reference/configuration).

## Materials

`native` requests a platform material (a vibrancy blur behind the bar); `opaque` uses a solid themed background. Reduce Transparency and Increase Contrast force an opaque background and a stronger border even if a configuration requests material. The native family uses macOS semantic colors; the four families use their resolved tokens.

## Focus preset

```json
{
  "version": 2,
  "appearance": { "family": "gruvbox", "mode": "dark", "accent": "#D6F58A", "material": "opaque" },
  "layout": { "height": 28, "padding": 10 },
  "left": ["workspaces"],
  "right": ["date", "time"],
  "widgets": { "workspaces": { "showEmpty": false }, "date": { "weekday": false } }
}
```

## Website preview

<BarPreview />

These browser presets communicate the visual direction. They are not exported native themes, and the static preview time/battery are sample data.

## Share a theme

A shared theme is a configuration example using the same v2 contract as your own file—nothing theme-specific is added. Start from a family, add `appearance.palette` overrides for your tweaks, and contribute the example with a description and screenshot. Keep credentials out of examples. Test text contrast, focused/occupied states, notch and notch-free displays, and both appearance modes, and label any light variant you adapt that is not upstream.

## Website appearance

The landing page's Light/Dark button and the docs appearance switch share the saved VitePress preference. The default website mode is dark; your choice persists across pages and reloads. This controls the website only. The native app follows macOS by default, with explicit Light/Dark overrides.
