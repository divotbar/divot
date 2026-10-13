---
id: "0083"
title: "Popover survey and standardisation: solid, left-aligned, readable, verified with shots"
type: bug
status: ready
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T09:00:54Z"
updated_at: "2026-10-13T09:01:56Z"
---
## Problem
Maintainer screenshots (2026-10-13, 15:51, Appearance, Wi-Fi and Calendar popovers) show the popovers are still wrong in the running app after #0072-#0077, even though those tasks passed review:
- Still translucent: wallpaper/page bleeds through with a vertical gradient (top darker, bottom lighter); the fill is not a solid, predictable colour. #0076 painted an opaque content layer, but the real popover window chrome still shows through.
- Alignment: the Appearance theme list is staggered (Gruvbox, Ayu and Dracula rows are right-aligned or centred at different offsets while Native and Tokyo Night sit at the left). The Wi-Fi message and links, and the calendar footer ('Today', 'Open Date & Time Settings...'), are right-aligned. The maintainer wants everything left-aligned like the native macOS menu bar popovers.
- Contrast: Wi-Fi message text is grey on grey and nearly unreadable, the calendar weekday headers (Sun, Mon, ...) and dimmed days are faint, and the white '13' for today has no clear filled highlight against the translucent background. Accent-coloured footer links are brownish and hard to read.
- The maintainer's rules from earlier feedback: left align, not translucent/opaque-looking-unpredictable (solid and predictable per theme light/dark), and text colours that are easy to see.

## Desired UX (one standard for ALL popovers)
- Survey every popover Divot has today (Wi-Fi in both states, Volume, Appearance, Calendar, and any other popup or menu the app shows) and list them in the task.
- Define the standard once, in the shared popover component and theme tokens, and apply it to every popover:
- Solid opaque background from the theme popover palette (light and dark variant), fully opaque including the arrow and border; no vibrancy, no blur, no gradient.
- Left-aligned content everywhere: title, section headings, rows, messages, footer links; consistent leading inset and row height.
- Text colours from theme tokens with guaranteed contrast against the solid background (primary, secondary, heading, link, disabled/dimmed, selected); no raw accent text unless it passes the audit.
- One selected-state style, one footer-link style, one divider style.
- Fix the specific defects above: Appearance theme list rows all left-aligned in a clean vertical list; Wi-Fi message and links readable; calendar headers, dimmed days, 'Today' and footer readable; today's date shown as a clearly filled highlight.

## Acceptance criteria
- A written survey in the task (every popover, the rules, what was inconsistent).
- The root cause of the remaining translucency is found and fixed. NSPopover's own chrome applies a vibrant material that a painted content layer does not remove: either disable it for real (and prove it) or replace NSPopover with a custom borderless panel that Divot draws itself with a solid fill, border, shadow and arrow, shared by all popovers. State which and why.
- Runtime assertions that do not depend on offscreen rendering: walk the real popover window's view hierarchy in a test or debug path and assert no NSVisualEffectView (or other material) remains, the window is opaque, and the effective background colour has alpha 1 for every theme family in light and dark.
- Pixel assertions on the offscreen renders for left alignment (first content column of every row within the leading inset), contrast of sampled text against the sampled background for every text role, and today's highlight, run for all five families in light and dark, for every popover, including the Wi-Fi permission message state and the calendar.
- VERIFY WITH SHOTS: use the new Divot bar shot target (#0081) and declare a ## Shots entry; the captured images must show all popovers in at least two themes in light and dark. Look at the shots and describe in the task what each shows; fix and recapture until they match the rules. If offscreen rendering cannot show the real window chrome, say exactly what the shots do and do not prove; do not claim the translucency is fixed from content-only shots.
- Check that the app the maintainer runs actually contains the fix: record in the task which build/commit the packaged app was built from, and tell the maintainer to rebuild with scripts/package-app.sh and reopen (the screenshots may have come from a build older than #0076).
- Keep keyboard and VoiceOver behaviour, outside-click and Escape dismissal, sizing, and the existing tests; docs/ and site/ pages updated for the standard; swift test --package-path macos passes.
- The maintainer verifies by eye on the packaged app; do not claim visual sign-off.

## Notes for AI
Related, already done but evidently incomplete: #0070 Wi-Fi, #0071 Volume, #0072 Appearance, #0073 and #0076 restyle, #0077 Calendar, #0078/#0079 snapshots, #0081 shots. Start from BarPopover.swift (BarPopoverHost), AppearancePopover.swift, VolumePopover.swift, WifiPopover.swift, CalendarPopover.swift and BarTheme.swift. Do not commit images.

## Screenshots
Maintainer screenshots from the packaged app, 2026-10-13 15:51. 1) Appearance popover: staggered, partly right-aligned theme rows, gradient/translucent fill. 2) Wi-Fi popover: grey-on-grey permission message, right-aligned links, translucent fill. 3) Calendar popover: faint weekday headers, no filled highlight for today, right-aligned footer.

![Appearance popover](/api/tasks/0083/attachments/screenshot-1.png)

![Wi-Fi popover](/api/tasks/0083/attachments/screenshot-2.png)

![Calendar popover](/api/tasks/0083/attachments/screenshot-3.png)

## Activity

- 2026-10-13T09:00:54Z · created · njachowski@gmail.com
- 2026-10-13T09:01:18Z · body: section Screenshots
- 2026-10-13T09:01:53Z · cli_override, model_override
- 2026-10-13T09:01:55Z · model_override
- 2026-10-13T09:01:56Z · status inbox→ready
