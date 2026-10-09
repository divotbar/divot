# Proposed configuration contract · version 1

The app-side parser and hot reload are not implemented. The website preview and structural checker use these examples today. Fields become stable only when the native implementation and contract tests land.

Use UTF-8 JSON at `~/.config/divot/config.json`. Missing file uses native defaults; invalid file preserves the last valid configuration. Unknown keys produce actionable diagnostics. File writes from settings must be atomic and preserve supported user settings; explain whether comments are unsupported (JSON has none).

Top-level fields: `version` (exactly 1), `appearance`, `layout`, `workspaces`, `status`. Appearance mode: `system`, `dark`, `light`; accent: six-digit hex; material: `native` or `opaque`. Layout height: 24–40 points, padding: 0–24, notch gap: 0–32. Workspaces: `enabled`, adapter `aerospace`, `showEmpty`. Status is an ordered unique list from `front-app`, `battery`, `clock`. Initial clock resolution is minutes.

See `examples/default.json`, `examples/focus.json`, `examples/opaque.json` and the public reference for complete examples. They use the same shape and are validated during web checks. The starter checker rejects unknown fields/types/ranges; later replace duplication with generated schema or cross-language contract fixtures.

## Migration and extension

Require explicit version migrations; never reinterpret an existing field silently. A migration must preserve a recoverable original. Add new built-ins only with provider tests, doc changes, and performance evidence. Future per-display overrides use stable display identity and inherit global defaults. Script settings and API credentials do not belong in committed example files.
