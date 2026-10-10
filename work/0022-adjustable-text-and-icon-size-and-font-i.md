---
id: "0022"
title: "Adjustable text and icon size and font in Divot settings, with a larger default"
type: feature
status: review
priority: p1
area: macos
depends_on: ["0021"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/adjustable-text-and-icon-size-and-font-i
created_at: "2026-10-10T05:25:45Z"
updated_at: "2026-10-10T08:52:23Z"
---
## Problem

The bar's text and icons are too small on the maintainer's display. Size and font are fixed in code, and there is no way to change them from Settings.

## Desired UX

- Settings has a text and icon size control, with a slightly larger default than today.
- Settings has a font picker for the bar's text (a short list of installed system fonts, plus the system default).
- Changes apply live to the bar and persist through the configuration store (0006), like the theme picker in 0017.
- Icon size scales with the text size so the two stay in proportion.

## Acceptance criteria

- Add `text size` and `font` keys to the versioned configuration, with defaults that are larger than the current ones. Validate ranges and unknown font names with a clear fallback, not a crash.
- Settings controls for both, in the existing settings window, using the native dropdown and slider components (AGENTS.md: custom styled dropdowns, no bare `<select>`).
- Changing size or font updates the bar without a relaunch and survives relaunch.
- Tests cover the config round-trip, the fallback for a missing font, and that icon size follows text size.
- `repoos check` passes. A screenshot is evidence only; the maintainer confirms how it looks.

## Notes for AI

Depends on #0021 (row height and placement, which changes `BarMetrics`). Do not start until #0021 is done, because both touch the same metrics and the configuration defaults.

## Activity

- 2026-10-10T05:25:45Z · created · njachowski@gmail.com
- 2026-10-10T07:15:23Z · status inbox→ready
- 2026-10-10T08:43:08Z · status ready→active, branch
- 2026-10-10T08:52:23Z · status active→review
