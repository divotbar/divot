---
id: "0073"
title: "Restyle the Appearance popover: compact, horizontal and easy to scan"
type: bug
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/restyle-the-appearance-popover-compact-h
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T02:59:14Z"
updated_at: "2026-10-13T04:49:32Z"
---
## Problem
The Appearance popover from #0072 looks unfinished (maintainer screenshot 2026-10-13). It is wide for its content: the section titles and the radio rows are right-aligned, leaving a large empty block on the left. Mode and Theme are two long vertical lists of plain system radio buttons, the focus ring on 'Dark' looks stray, and nothing shows what a theme looks like.

## Desired UX
- Compact, balanced popover: content left-aligned with even padding, width sized to content (no big empty area), same corner radius, material and typography as the Wi-Fi and volume popovers so the three read as one family.
- Mode: one horizontal segmented control: System / Light / Dark, with the current mode clearly selected.
- Theme: horizontal or wrapped grid of options (Native, Gruvbox, Ayu, Dracula, Tokyo Night), each with a small colour swatch from that theme's own palette and the name, the current one clearly highlighted. Choosing one applies immediately.
- 'Open Divot Settings...' stays as the last row, left-aligned like the other popovers' footer rows.
- Pretty in both light and dark bar themes, and with the increased-contrast setting; no clipped or truncated text at the larger text sizes.

## Acceptance criteria
- Layout is built from the shared popover component and styles; adjust that component only if Wi-Fi and volume popovers stay visually correct.
- Swatches use the real theme palette values (no hand-copied colours), so new themes appear automatically.
- Keyboard and VoiceOver behaviour from #0072 is kept or improved: options reachable, selected state and labels announced.
- Layout/sizing logic that can be unit tested is covered; existing popover tests still pass.
- docs/ and site/ screenshots or descriptions of the popover updated only where they describe the old layout.
- The maintainer checks the final look by eye on the packaged app; do not claim visual sign-off.

## Notes for AI
Look at the Appearance popover view from #0072 and the Wi-Fi/volume popovers (#0070, #0071). Prefer a segmented NSSegmentedControl (or SwiftUI Picker segmented) for mode and a small swatch grid for themes over radio buttons.

## Activity

- 2026-10-13T02:59:14Z · created · njachowski@gmail.com
- 2026-10-13T02:59:17Z · status inbox→ready
- 2026-10-13T02:59:18Z · cli_override, model_override
- 2026-10-13T02:59:19Z · status ready→active, branch
- 2026-10-13T03:14:41Z · message_queued at 2026-10-13T03:14:41.974Z
- 2026-10-13T03:14:42Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
- 2026-10-13T03:53:48Z · message_queued at 2026-10-13T03:53:48.380Z
- 2026-10-13T04:14:00Z · message_delivered: 2 message(s)
- 2026-10-13T04:25:24Z · cli_override, model_override
- 2026-10-13T04:41:08Z · cli_override, model_override
- 2026-10-13T04:41:30Z · message_queued at 2026-10-13T04:41:30.105Z
- 2026-10-13T04:46:48Z · cli_override, model_override
- 2026-10-13T04:46:49Z · message_delivered: 1 message(s)
- 2026-10-13T04:49:32Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
