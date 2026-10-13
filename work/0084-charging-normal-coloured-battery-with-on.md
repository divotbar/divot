---
id: "0084"
title: "Charging: normal-coloured battery with only the bolt green (undo the whole-icon tint)"
type: bug
status: ready
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T09:05:20Z"
updated_at: "2026-10-13T09:05:24Z"
---
## Problem
#0074 made the charging indicator unmistakable by tinting the WHOLE battery symbol green while charging (its Approach chose the whole-icon fallback; #0058 and #0074 both started from 'only the bolt green'). Maintainer screenshot 2026-10-13 16:04: the whole battery is green. The maintainer does not want that: the battery should stay the normal icon colour (the bar's regular label colour, black on light themes) and ONLY the charging bolt should be green, so it is clear what it is.

## Desired UX
- While charging: battery outline and fill use the item's normal label colour for the theme; the bolt is a fixed real green (the ChargingIndicatorPalette green from #0074, not the theme accent).
- Not charging: normal colour, no bolt, no green.
- Clearly visible on every theme family in light and dark, with chips on and off, at the default and a larger text size.

## Acceptance criteria
- Implement bolt-only green using a public approach and say which in the task. The preferred approach is an SF Symbol palette configuration (NSImage.SymbolConfiguration(paletteColors:)) on the charging battery symbol (for example battery.100.bolt or battery.100percent.bolt), assigning the normal label colour to the body layers and the fixed green to the bolt layer; verify the layer order of the symbol on macOS 26 rather than assuming it. If palette layers cannot isolate the bolt, draw the bolt as a separate green overlay clipped to the battery bounds (the #0058 approach) and fix its contrast against the battery fill.
- Contrast: the green bolt must stay distinguishable against the battery body/fill colour for every family in light and dark (extend the existing ChargingIndicator contrast tests/audit). Where green on the body fails the threshold, add a thin outline or choose the body fill so the bolt is visible, and record the decision.
- Tests: charging renders pixels of the fixed green only within the bolt region and the body pixels equal the normal label colour; not charging contains no green. Use the offscreen bar snapshot helpers (#0078/#0079).
- VERIFY WITH SHOTS: use the Divot bar shot target (#0081), declare a ## Shots entry, LOOK at the captured images (charging on a light theme and a dark theme, chips on and off) and describe what they show in the task; fix and recapture until the body is normal-coloured and only the bolt is green.
- Update docs/ and site/ pages that describe the charging indicator (it is a green bolt on a normal battery, not a green battery).
- The maintainer verifies by eye on the packaged app; do not claim visual sign-off.

## Notes for AI
Look at the badge/tint code in WidgetViews.swift, ChargingIndicatorPalette, WidgetPresentation.swift (symbol names) and the #0074 tests. Undo the whole-icon tint cleanly (remove dead code and update the tests that asserted it).

## Activity

- 2026-10-13T09:05:20Z · created · njachowski@gmail.com
- 2026-10-13T09:05:24Z · status inbox→ready
