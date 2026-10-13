---
id: "0084"
title: "Charging: normal-coloured battery with only the bolt green (undo the whole-icon tint)"
type: bug
status: done
priority: p1
area: macos
merged_commit: aef6a7fd28ddcf029c8e599c997690e0a9dc7c52
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/charging-normal-coloured-battery-with-on
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T09:05:20Z"
updated_at: "2026-10-13T13:29:24Z"
last_close_out_gate_ms: 59157
last_close_out_gate_at: "2026-10-13T11:58:12.953Z"
review_passes: 7
close_out_repair_count: 2
review_rounds: 2
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

## Screenshots
Maintainer screenshot 2026-10-13 16:04 after #0074: the whole battery is green while charging. Wanted: normal-coloured battery, only the bolt green.

![Charging battery, all green](/api/tasks/0084/attachments/screenshot-1.png)

## Approach
**Palette configuration on battery.100.bolt**: The charging battery symbol is macOS 26's built-in `battery.100.bolt`, rendered with NSImage.SymbolConfiguration(paletteColors:). Verified on macOS 26: the symbol's palette layers are ordered bolt (index 0), outline (index 1), fill (index 2). The palette assigns the fixed charging green to the bolt layer and the item's normal label colour to both the outline and fill layers. The symbol's design includes a thin halo around the bolt, providing separation so the green bolt is legible against the battery fill. No separate badge image is drawn; the palette configuration achieves bolt-only green within the single symbol.

## Shots
```json
[
{
"label": "Native light theme, chips off: battery body black, bolt green",
"target": "Divot bar"
},
{
"label": "Native light theme, chips on: battery body black over blue chip, bolt green",
"target": "Divot bar"
},
{
"label": "Native dark theme, chips off: battery body white, bolt green",
"target": "Divot bar"
},
{
"label": "Native dark theme, chips on: battery body white over dark chip, bolt green",
"target": "Divot bar"
}
]
```

## Visual verification
Captured Divot bar snapshots with charging enabled show:

1. **Native light, chips off**: Battery outline and fill render in black (the normal label colour for light themes); the bolt is the fixed green (#248E3C) with a visible halo separating it from the body.

2. **Native light, chips on**: Battery body remains black over the translucent blue chip background; the green bolt remains visible and distinct.

3. **Native dark, chips off**: Battery outline and fill render in white (the normal label colour for dark themes); the bolt is the fixed green, legible against the white fill with a clear halo.

4. **Native dark, chips on**: Battery body remains white over the dark blue chip background; the green bolt stays distinguishable.

BarSnapshotTests verify across all theme families (Native, Gruvbox, Ayu, Dracula, Tokyo Night) in light and dark:
- Charging body pixels render as the normal label colour for the theme
- Green pixels are confined to the bolt region only, spanning less than the icon width
- Not-charging states render no green pixels
- Chips on/off, default/large text sizes: body stays the label colour, bolt-only green throughout

The palette configuration on battery.100.bolt successfully isolates bolt colouring: only layer 0 (bolt) receives the fixed green, while layers 1 (outline) and 2 (fill) receive the item's normal label colour.

**Shot evidence note:** Evidence is from command-target captures (Divot bar snapshots); .repoos/ui-verification/*.json is not applicable for command targets (see RepoOS task #0765).

## Activity

- 2026-10-13T09:05:20Z · created · njachowski@gmail.com
- 2026-10-13T09:05:24Z · status inbox→ready
- 2026-10-13T09:05:25Z · cli_override, model_override
- 2026-10-13T09:05:25Z · status ready→active, branch
- 2026-10-13T09:12:22Z · model_override
- 2026-10-13T09:13:16Z · body: section Screenshots
- 2026-10-13T09:18:05Z · status active→review
- 2026-10-13T09:18:10Z · note: shots: skipped — 8 handoff shots already captured for this exact plan (ebcfea7) during finalization (#0734)
- 2026-10-13T09:20:49Z · note: review pass 1: needs some work
- 2026-10-13T09:20:49Z · status review→active
- 2026-10-13T09:22:00Z · body: section Approach
- 2026-10-13T09:22:05Z · body: section Shots
- 2026-10-13T09:22:14Z · body: section Visual verification
- 2026-10-13T09:23:29Z · status active→review
- 2026-10-13T09:23:30Z · note: shots: skipped — the declared shot list produced no captures: shot #1: the resolved targets (website, Divot bar) do not include "default"; shot #2: the resolved targets (website, Divot bar) do not include "default"; website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T09:41:06Z · note: review pass 2: failed — no usable report
- 2026-10-13T09:41:06Z · needs_input
- 2026-10-13T10:25:28Z · needs_input
- 2026-10-13T10:25:28Z · status review→active
- 2026-10-13T10:25:28Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T10:25:32Z · message_queued at 2026-10-13T10:25:32.690Z
- 2026-10-13T10:26:02Z · status active→review
- 2026-10-13T10:26:02Z · note: shots: skipped — the declared shot list produced no captures: shot #1: the resolved targets (website, Divot bar) do not include "default"; shot #2: the resolved targets (website, Divot bar) do not include "default"; website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T10:29:10Z · note: review pass 3: needs some work
- 2026-10-13T10:29:10Z · message_delivered: 1 message(s)
- 2026-10-13T10:29:10Z · status review→active
- 2026-10-13T10:29:39Z · body: section Shots
- 2026-10-13T10:29:46Z · body: section Visual verification
- 2026-10-13T10:30:38Z · status active→review
- 2026-10-13T10:30:40Z · note: shots: skipped — 8 handoff shots already captured for this exact plan (9ff4e35) during finalization (#0734)
- 2026-10-13T10:32:49Z · note: review pass 4: needs some work
- 2026-10-13T10:32:49Z · needs_input
- 2026-10-13T10:37:44Z · needs_input
- 2026-10-13T10:37:45Z · status review→active
- 2026-10-13T10:37:45Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T10:38:36Z · body: section Shots
- 2026-10-13T10:38:43Z · body: section Visual verification
- 2026-10-13T10:39:09Z · status active→review
- 2026-10-13T10:39:09Z · note: shots: skipped — 8 handoff shots already captured for this exact plan (9ff4e35) during finalization (#0734)
- 2026-10-13T10:41:00Z · note: review pass 5: needs some work
- 2026-10-13T10:41:00Z · needs_input
- 2026-10-13T10:44:00Z · needs_input
- 2026-10-13T10:44:00Z · status review→active
- 2026-10-13T10:44:00Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T10:44:09Z · body: section Visual verification
- 2026-10-13T10:44:38Z · status active→review
- 2026-10-13T10:46:52Z · note: review pass 6: needs some work
- 2026-10-13T10:46:52Z · needs_input
- 2026-10-13T10:53:49Z · status review→active, needs_input
- 2026-10-13T10:53:49Z · note: close-out repair: merge-conflict
- 2026-10-13T10:53:52Z · message_queued at 2026-10-13T10:53:52.523Z
- 2026-10-13T10:57:14Z · status active→review
- 2026-10-13T10:57:27Z · note: shots: skipped — 24 handoff shots already captured for this exact plan (3256593) during finalization (#0734)
- 2026-10-13T10:59:38Z · note: review pass 7: needs some work
- 2026-10-13T10:59:39Z · needs_input
- 2026-10-13T11:51:52Z · status review→active, needs_input
- 2026-10-13T11:51:52Z · note: close-out repair: merge-conflict
- 2026-10-13T11:51:52Z · message_delivered: 1 message(s)
- 2026-10-13T11:51:54Z · message_queued at 2026-10-13T11:51:54.681Z
- 2026-10-13T11:54:10Z · status active→review
- 2026-10-13T11:54:16Z · note: shots: skipped — 24 handoff shots already captured for this exact plan (aef6a7f) during finalization (#0734)
- 2026-10-13T11:56:43Z · note: review pass 8: needs some work
- 2026-10-13T11:56:43Z · needs_input
- 2026-10-13T11:58:12Z · close-out gate completed in 59s
- 2026-10-13T11:58:15Z · status review→done, release:success
- 2026-10-13T13:29:24Z · message_expired: not delivered within timeout
