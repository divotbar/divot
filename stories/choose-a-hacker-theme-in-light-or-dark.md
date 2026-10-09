---
name: Choose a hacker theme in light or dark
number: "0005"
created_at: "2026-10-09T16:41:11.591Z"
created_by: api
---
## User story

As a hacker who cares about my desktop, I want recognizable themes with usable light and dark variants, so Divot feels like part of my setup instead of a generic system utility.

## Theme families

Gruvbox, Ayu, Dracula, and Tokyo Night. The requested 'Tokyo' is interpreted as Tokyo Night. Preserve recognizable family palettes, and use openly licensed upstream palettes with source/attribution. Where an upstream family lacks an official light variant, label Divot's light adaptation honestly; do not call an invented palette official.

## Acceptance criteria

- Themes are central to the first useful release, not deferred polish. Ship the four families plus the comfortable native default.
- Theme family and appearance are separate settings: System/Light/Dark selects a variant without discarding the chosen family.
- Both variants cover the whole product: bar, selected/occupied states, icons, menus/popovers, settings, errors and disabled text.
- Semantic color tokens carry foreground/background/accent/selected/occupied/error roles; color alone never carries state.
- Live switching persists, invalidates appearance-dependent caches only, and does not restart providers.
- Test contrast in every state, respect increased contrast/reduced transparency, and provide opaque material.
- Custom palette overrides and theme sharing are documented using the same configuration contract.

## Evidence

Visual/reference fixtures can be automated, but physical readability/accessibility still need human QA. No theme is declared delivered until its actual native surfaces exist and pass review.
