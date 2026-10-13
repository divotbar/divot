---
id: "0087"
title: Keep-awake coffee cup must pop on every theme in light and dark
type: bug
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/keep-awake-coffee-cup-must-pop-on-every-
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T16:15:55Z"
updated_at: "2026-10-13T17:55:24Z"
review_passes: 7
review_rounds: 2
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

## Shots
```json
[
{
"target": "Divot bar",
"label": "Keep-awake cup on Native light theme, no chips",
"glob": "keep-awake-native-light-default-chips-off.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Native light theme, with chips",
"glob": "keep-awake-native-light-default-chips-on.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Native dark theme, no chips",
"glob": "keep-awake-native-dark-default-chips-off.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Native dark theme, with chips",
"glob": "keep-awake-native-dark-default-chips-on.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Gruvbox light theme, no chips",
"glob": "keep-awake-gruvbox-light-default-chips-off.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Gruvbox light theme, with chips",
"glob": "keep-awake-gruvbox-light-default-chips-on.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Gruvbox dark theme, no chips",
"glob": "keep-awake-gruvbox-dark-default-chips-off.png"
},
{
"target": "Divot bar",
"label": "Keep-awake cup on Gruvbox dark theme, with chips",
"glob": "keep-awake-gruvbox-dark-default-chips-on.png"
}
]
```

## Activity

- 2026-10-13T16:15:55Z · created · njachowski@gmail.com
- 2026-10-13T16:15:59Z · body: section Screenshots
- 2026-10-13T16:19:52Z · status inbox→ready
- 2026-10-13T16:19:52Z · cli_override, model_override
- 2026-10-13T16:19:53Z · status ready→active, branch
- 2026-10-13T16:29:04Z · body: section Shots
- 2026-10-13T16:33:10Z · status active→review
- 2026-10-13T16:34:27Z · note: review pass 1: needs some work
- 2026-10-13T16:34:28Z · status review→active
- 2026-10-13T16:37:23Z · status active→review
- 2026-10-13T16:37:24Z · note: shots: skipped — 48 handoff shots already captured for this exact plan (d2a29f4) during finalization (#0734)
- 2026-10-13T16:38:52Z · note: review pass 2: needs some work
- 2026-10-13T16:38:52Z · status review→active
- 2026-10-13T16:39:13Z · message_queued at 2026-10-13T16:39:13.282Z
- 2026-10-13T16:42:26Z · status active→review
- 2026-10-13T16:42:27Z · note: shots: skipped — 48 handoff shots already captured for this exact plan (565b6b9) during finalization (#0734)
- 2026-10-13T16:44:45Z · note: review pass 3: needs some work
- 2026-10-13T16:44:45Z · needs_input
- 2026-10-13T16:49:30Z · needs_input
- 2026-10-13T16:49:31Z · status review→active
- 2026-10-13T16:49:31Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T16:49:31Z · message_delivered: 1 message(s)
- 2026-10-13T16:52:24Z · status active→review
- 2026-10-13T16:53:37Z · note: review pass 4: needs some work
- 2026-10-13T16:53:37Z · needs_input
- 2026-10-13T16:55:39Z · needs_input
- 2026-10-13T16:55:39Z · status review→active
- 2026-10-13T16:55:39Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T16:58:23Z · status active→review
- 2026-10-13T16:59:45Z · note: review pass 5: needs some work
- 2026-10-13T17:01:32Z · status review→active
- 2026-10-13T17:01:32Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T17:13:27Z · status active→review
- 2026-10-13T17:14:35Z · note: review pass 6: needs some work
- 2026-10-13T17:14:35Z · needs_input
- 2026-10-13T17:19:35Z · needs_input
- 2026-10-13T17:19:35Z · status review→active
- 2026-10-13T17:19:35Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T17:43:38Z · status active→review
- 2026-10-13T17:43:38Z · note: handoff requested (cli)
- 2026-10-13T17:44:18Z · status active→review
- 2026-10-13T17:44:18Z · note: shots: failed — capture command for "Divot bar" exited 127 sh: scripts/swift-test-lock.sh: No such file or directory
- 2026-10-13T17:44:19Z · note: shots: failed — capture command for "Divot bar" exited 127 sh: scripts/swift-test-lock.sh: No such file or directory
- 2026-10-13T17:45:16Z · note: review pass 7: needs some work
- 2026-10-13T17:49:24Z · status review→active
- 2026-10-13T17:49:24Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T17:51:33Z · body: section Shots
- 2026-10-13T17:53:25Z · status active→review
- 2026-10-13T17:53:25Z · note: shots: skipped — 48 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T17:55:24Z · note: review pass 8: needs some work
- 2026-10-13T17:55:24Z · needs_input
