---
id: "0076"
title: "Popovers: solid predictable background, left-aligned layout, vertical theme list"
type: bug
status: active
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/popovers-solid-predictable-background-le
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T05:50:05Z"
updated_at: "2026-10-13T06:19:28Z"
review_passes: 4
review_rounds: 2
---
## Problem
Maintainer feedback with screenshots (2026-10-13) on the Appearance, Volume and Wi-Fi popovers after #0073:
- The popover background is translucent: the page behind bleeds through (the Ayu popover shows a yellow page behind it), so contrast depends on whatever is underneath and the maintainer cannot predict what will be visible. The accent-coloured 'Open ... Settings...' link is faint on some backgrounds (orange on Ayu).
- Titles, rows and footers are right-aligned. The native macOS menu bar popovers (Wi-Fi example screenshot) are left-aligned.
- #0073 laid the theme list out in a wrapped horizontal grid; the maintainer now wants it vertical.

## Desired UX
- Solid, predictable background: no see-through blur and no vibrancy material. Use an opaque fill that follows the selected Divot theme and its light or dark variant (the same light/dark decision the bar uses), so a given theme and mode always look the same regardless of what is behind the popover. Keep subtle rounded corners, a thin border and the shadow.
- Everything left-aligned like the native menu bar popovers: title left, section headings left, rows left, footer link left.
- Appearance popover: Mode stays one horizontal segmented control (System / Light / Dark); Theme becomes a vertical list (Native, Gruvbox, Ayu, Dracula, Tokyo Night), one per row, with the colour swatch and the name, and the current theme clearly marked.
- Wi-Fi and Volume popovers get the same background and alignment: slider and percentage, Mute, and the footer rows all left-aligned.
- Footer links ('Open Divot Settings...', 'Open Sound Settings...', 'Open Wi-Fi Settings...') use a readable text colour from the theme with guaranteed contrast against the solid popover background in every family, light and dark; do not use the raw accent if it fails contrast.

## Acceptance criteria
- Use the existing contrast audit to check every popover text role (title, section heading, row label, secondary text, link, selected state) against the solid background for every theme family in light and dark; fail the test below the existing threshold.
- Popover background and text colours come from the theme tokens (no hard-coded colours in views); layout alignment is built in the shared popover component so all three popovers inherit it.
- Keep keyboard and VoiceOver behaviour, outside-click dismissal and the sizing/readability fixes from #0073.
- Update docs/ and site/ pages that describe the popovers' look; no new claims about unreleased behaviour.
- The maintainer checks the final look by eye on the packaged app; do not claim visual sign-off.

## Notes for AI
The maintainer's wording was ambiguous ('dial back the opacity', 'shouldn't be opaque'): the intent from context is to stop the see-through look, i.e. a solid, predictable fill. If you disagree, state it in the task rather than guessing. Look at BarPopover.swift, AppearancePopover.swift, VolumePopover.swift, WifiPopover.swift and BarTheme.swift.

## Activity

- 2026-10-13T05:50:05Z · created · njachowski@gmail.com
- 2026-10-13T05:50:08Z · status inbox→ready
- 2026-10-13T05:50:08Z · cli_override, model_override
- 2026-10-13T05:50:09Z · status ready→active, branch
- 2026-10-13T05:55:43Z · status active→review
- 2026-10-13T05:55:43Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T05:57:02Z · note: review pass 1: needs some work
- 2026-10-13T05:57:02Z · status review→active
- 2026-10-13T05:58:51Z · status active→review
- 2026-10-13T05:58:51Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:00:28Z · note: review pass 2: needs some work
- 2026-10-13T06:00:28Z · status review→active
- 2026-10-13T06:01:27Z · message_queued at 2026-10-13T06:01:27.365Z
- 2026-10-13T06:02:16Z · status active→review
- 2026-10-13T06:02:17Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:06:03Z · note: review pass 3: needs some work
- 2026-10-13T06:06:03Z · needs_input
- 2026-10-13T06:11:11Z · needs_input
- 2026-10-13T06:11:11Z · status review→active
- 2026-10-13T06:11:11Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T06:11:11Z · message_delivered: 1 message(s)
- 2026-10-13T06:13:00Z · status active→review
- 2026-10-13T06:13:01Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-13T06:14:15Z · note: review pass 4: needs some work
- 2026-10-13T06:14:15Z · needs_input
- 2026-10-13T06:19:28Z · needs_input
- 2026-10-13T06:19:28Z · status review→active
- 2026-10-13T06:19:28Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
