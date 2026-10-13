---
id: "0093"
title: "Keep-awake toast: a self-dismissing in-app message under the battery when caffeine is toggled"
type: feature
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/keep-awake-toast-a-self-dismissing-in-ap
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T17:13:26Z"
updated_at: "2026-10-13T18:55:31Z"
---
## Problem
Clicking the battery item toggles keep-awake (#0018, #0051), but the only feedback is the small cup appearing or disappearing, which is easy to miss. The maintainer wants a short message under the battery item saying whether caffeine is now on or off, regardless of Focus/Do Not Disturb.

## Desired UX
- When the user clicks the battery item to toggle keep-awake, a small toast appears directly below the battery item, anchored to it like the popovers: 'Caffeine on' (with a short subline such as 'Your Mac will stay awake') in GREEN, or 'Caffeine off' in RED.
- It dismisses itself after about 2 seconds (fade out; no fade when Reduce Motion is on), never needs a click, never takes keyboard focus, never activates the app, and does not block clicks on the bar. A second toggle while one is showing replaces it immediately (no stacking).
- It must show regardless of the system Focus / Do Not Disturb state, so it must NOT be a system notification. Do NOT use osascript 'display notification' or UNUserNotificationCenter: both go through Notification Center, are suppressed by Focus, need a permission, and appear attributed to another app. Draw Divot's own transient panel instead (same approach as the popovers: a borderless non-activating panel with the shared solid theme-based chrome, left-aligned text), positioned just below the battery item.
- Green and red are fixed semantic colours (like the charging green) chosen for contrast on the solid toast background in every theme family including Alpine, light and dark; the text itself stays readable, with the colour carried by a leading dot or bar plus the heading text. VoiceOver is told via an accessibility announcement ('Caffeine on' / 'Caffeine off') and the toast is not focusable.
- Only Divot's own toggle triggers it (unchanged rule from #0051); remembered state restored at launch must not show a toast.

## Acceptance criteria
- Toast logic (text, colour role, duration, replacement, suppression at launch) in DivotCore or an injectable model, unit tested; presentation goes through the injectable window presenter so tests never put a real window on screen (see #0091), and the toast is rendered offscreen for the snapshot set.
- Positioned correctly below the battery item on every display, including notched displays and multiple screens, and clamped to the screen edge; does not overlap the bar.
- The timer is a single one-shot dismissal (no polling); cancelled when replaced or when the app quits.
- Contrast audit for the toast text and the on/off accent against the toast background for every family in light and dark (extend ContrastAudit).
- VERIFY WITH SHOTS using the Divot bar target with a filter glob: capture 'caffeine on' and 'caffeine off' toasts in Native and Gruvbox, light and dark (file names containing caffeine-toast), LOOK at them and describe each; say honestly that offscreen shots do not prove placement or that the real window shows regardless of Focus.
- Document in docs/ and site/ (widgets guide): what the toast is, that it ignores Focus/Do Not Disturb because it is Divot's own window, and that it can be turned off if you add a setting (include an on/off setting 'Show keep-awake message' default on, in the config, the Settings window and the config CLI schema).
- The maintainer verifies by eye on the packaged app, including with Do Not Disturb on; do not claim visual sign-off.

## Notes for AI
Reuse BarPopoverHost/BarPopoverPanel chrome and the window-presenter seam; look at how the battery click toggles keep-awake (WidgetActions toggleKeepAwake) and the #0087 cup colours. Work in stages, commit after each, and do not hand off until swift build, swift test --package-path macos and bun run check pass.

## Activity

- 2026-10-13T17:13:26Z · created · njachowski@gmail.com
- 2026-10-13T18:55:30Z · status inbox→ready
- 2026-10-13T18:55:30Z · cli_override, model_override
- 2026-10-13T18:55:31Z · status ready→active, branch
