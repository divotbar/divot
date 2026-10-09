# Proposed configuration contract · version 2

The app-side parser and hot reload are not implemented. The website preview and structural checker use these examples today. Fields become stable only when the native implementation and contract tests land.

Use UTF-8 JSON at `~/.config/divot/config.json`. Missing file uses native defaults; invalid file preserves the last valid configuration. Unknown keys produce actionable diagnostics. File writes from settings must be atomic and preserve supported user settings; explain whether comments are unsupported (JSON has none).

Two ordered groups, `left` and `right`, hold the bar's items, and an item appears in exactly one group. Both sides are configurable: add, remove, reorder, or move any supported item. Defaults match the first-launch story, so a missing file or an omitted `widgets` object still produces the full default bar. Appearance sets a theme `family` and a separate `mode`; the family survives appearance changes. Per-item options are namespaced under `widgets`.

Supported items: `workspaces`, `front-app`, `battery`, `network`, `volume`, `clock`. Default left is `workspaces`, `front-app`; default right is `battery`, `clock`, `network`, `volume`. Clock resolution stays minutes unless `widgets.clock.seconds` is enabled. Appearance `family` is `native` (default), `gruvbox`, `ayu`, `dracula`, or `tokyo-night`; `mode` is `system`, `dark`, or `light`. Layout height is 24–40 points, padding 0–24, notch gap 0–32.

See `examples/default.json`, `examples/focus.json`, `examples/opaque.json` and the public reference for complete examples. They use the same shape and are validated during web checks. The starter checker rejects unknown fields/types/ranges and unknown or misplaced items; later replace duplication with generated schema or cross-language contract fixtures.

## Migration and extension

Version 1 was a pre-release draft that hard-coded workspaces on the left and a status-only right array. It never shipped and is superseded by version 2: move the `workspaces` item into `left`, its options into `widgets.workspaces`, and each `status` identifier into `right`. Require explicit version migrations; never reinterpret an existing field silently, and reject unknown versions rather than treating them as version 2. A migration must preserve a recoverable original. Add new built-ins only with provider tests, doc changes, and performance evidence. Yabai joins as a second `widgets.workspaces.adapter` value in its own milestone; until then the checker accepts `aerospace`. Future per-display overrides use stable display identity and inherit global defaults. Script settings and API credentials do not belong in committed example files.
