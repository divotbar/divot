---
id: "0087"
title: Keep-awake coffee cup must pop on every theme in light and dark
type: bug
status: ready
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T16:15:55Z"
updated_at: "2026-10-13T16:19:52Z"
---
## Problem
The keep-awake coffee cup next to the battery percentage (#0018, #0051) is hard to see: maintainer screenshots 2026-10-13 show it as a low-contrast olive/yellow cup on the chip (dark theme) and a muted brown-green cup on a pale yellow-green chip (light theme), close to the chip colour.

## Desired UX
- The cup is clearly visible against the chip or bar background on every theme family (Native, Gruvbox, Ayu, Dracula, Tokyo Night, Alpine) in light and dark, with chips on and off, and reads as a distinct 'keep-awake is on' indicator at a glance.
- Flat style, consistent with the rest of the bar: prefer a fixed, well-chosen colour with guaranteed contrast (like the fixed charging green from #0074/#0084) over a blurry drop shadow. A thin high-contrast outline or a subtle dark/light halo is acceptable only where a flat colour cannot reach the contrast threshold.

## Acceptance criteria
- One named constant (or a light/dark pair) for the cup colour in the theme tokens, not the raw theme accent; choose it so it meets at least 3:1 (graphical object threshold) against each family's bar and chip background in light and dark, using the existing ContrastAudit; where one colour cannot satisfy every family, derive a per-mode variant.
- Tests: the cup colour contrast audit for every family and mode, chips on and off; the cup only shows for Divot's own keep-awake toggle (unchanged, #0051).
- VERIFY WITH SHOTS: add the keep-awake battery (cup visible) to the reduced offscreen snapshot set (file names starting keep-awake-*) for Native and Gruvbox, light and dark, chips on and off; declare ## Shots with target 'Divot bar'; LOOK at the images and describe what each shows. If a family still looks weak, say so and fix it.
- docs/ and site/ pages that describe the keep-awake indicator updated; the maintainer verifies by eye on the packaged app, do not claim visual sign-off.

## Screenshots
Maintainer screenshots 2026-10-13: the keep-awake cup next to the battery. 1) dark bar/chip: olive cup low contrast against the chip. 2) light chip: muted cup close to the chip colour.

![Cup on dark chip](/api/tasks/0087/attachments/screenshot-1.png)

![Cup on light chip](/api/tasks/0087/attachments/screenshot-2.png)

## Notes for AI
Look at how the cup is drawn next to the battery (WidgetViews.swift / WidgetPresentation.swift, symbol cup.and.saucer) and the #0074/#0084 charging colour approach. Do not add a heavy blur shadow; the maintainer's bar is flat.

## Activity

- 2026-10-13T16:15:55Z · created · njachowski@gmail.com
- 2026-10-13T16:15:59Z · body: section Screenshots
- 2026-10-13T16:19:52Z · status inbox→ready
- 2026-10-13T16:19:52Z · cli_override, model_override
