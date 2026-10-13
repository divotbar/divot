---
id: "0088"
title: "World clock popover does not work in the real app and does not match its shots: fix, simplify, verify the real flow"
type: bug
status: inbox
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-13T16:20:27Z"
updated_at: "2026-10-13T16:20:35Z"
---
## Problem
#0085 landed, but in the packaged app (maintainer screenshot 2026-10-13 23:16, UTC+7) the world clock popover does not work and looks wrong, and it does not look like the shots that were used to approve it (second screenshot):
- Real app: a large mostly blank panel with one line of text ('13/10/2026, 23:16 (UTC+07:00)') and a search field with a loupe icon under it; no zone list, no visible way to add a timezone (typing in the search field gives no usable result), large empty space above the text. The maintainer says it 'doesn't work'.
- The approved shot shows a different, nicer layout (title 'Local (GMT)', four pre-filled zones with 'Tomorrow'/'Yesterday' labels, remove buttons, 'Add timezone...' with a search field) in a light, oversized rendering with the fixed date 01/01/2026 10:00. So the shots render a different configuration and sizing than the real popover: they pre-load four zones and never show the empty state or the add flow, and they do not go through the real popover host and panel sizing.

## Desired UX (the maintainer's changes)
- No date at all. Show the CURRENT TIME and the local UTC offset, for example '23:16  UTC+7' (use the compact offset form: UTC+7, UTC+5:30, UTC-8, UTC+0), with the local city or zone name small beneath. Follow the existing 12/24 hour setting.
- Below it the user's zones, one per row, left-aligned: zone name, its current time, a 'Yesterday'/'Tomorrow' label only when the day differs, and the hour difference ('8 h behind'), with a small remove control.
- Adding a zone must actually work: an 'Add timezone' row that opens a search field; typing shows a short results list directly under the field (city and identifier matches, e.g. 'los' finds Los Angeles; at most 6 rows, scrollable); clicking a result or pressing Return on the highlighted one adds it, closes the search and shows the new row at once; Esc cancels. The saved list persists in widgets.time.timezones and the Settings list shows it.
- Empty state (no zones yet): one short hint line and the Add row, no blank gaps. The panel is sized to its content (no big empty area), uses the same solid theme-based chrome as the other popovers, and the rows are the same height and left inset as the calendar/Wi-Fi popovers.
- Last row: 'Open Date & Time Settings...'.

## Acceptance criteria
- Reproduce the real failure first and record the cause in the task: instantiate the REAL controller path (BarPopoverHost/BarPopoverPanel with the world clock content controller) in a test, type into the search field (set stringValue and send the control-text-did-change notification), and assert the results rows appear; invoke the result row action and assert widgets.time.timezones changes through the configuration store and the rows rebuild. This test must fail before the fix if the bug is in that path.
- Fix the root cause so the add flow works end to end, and add the regression tests above.
- The shots must go through the same code as the real popover: render the real content controller inside the real panel sizing, not a separate layout, and add shots for: empty state, one zone, four zones with a Yesterday and a Tomorrow label, and the add flow with the results list visible after typing 'los'; in Native and Gruvbox, light and dark, at the default text size. LOOK at the images, describe each in the task, and fix until they match the design above.
- The header shows time plus compact UTC offset and no date; unit-test the offset formatting (UTC+7, UTC+5:30, UTC+5:45, UTC-3:30, UTC+0).
- Panel height fits content for 0 to 8 zones, with a max height and scrolling beyond that.
- Contrast and left-alignment pixel assertions as for the other popovers, for every family including Alpine, in light and dark.
- Keyboard: Tab/Return/Esc work in the add flow, and VoiceOver labels exist for the search field, results and remove buttons.
- Docs and site pages describe the final behaviour only. The maintainer verifies by eye on the packaged app; do not claim visual sign-off. If the problem only appears in the packaged app and cannot be reproduced in tests, say so and add a debug path that renders the real window.

## Screenshots
Maintainer screenshots 2026-10-13. 1) The REAL packaged app at 23:16 (UTC+7): the time chip popover shows only a blank panel, one date/time line and a search field; nothing usable. 2) The shot that was used to approve #0085: a different, pre-filled layout (rendered oversized, light theme, fixed date 01/01/2026 10:00 UTC+0). The maintainer also wants: no date, current time plus UTC offset only (UTC+7).

![Real app, broken](/api/tasks/0088/attachments/screenshot-1.png)

![Approved shot, different layout](/api/tasks/0088/attachments/screenshot-2.png)

## Notes for AI
WORK IN SMALL STAGES and commit after each; do not hand off until the real-flow test and the new shots exist and swift build, swift test --package-path macos and bun run check all pass. Never hand off while swift build fails. Files: WorldClockPopover.swift, WorldClock.swift, BarPopover.swift, the snapshot helpers. Do not commit images.

## Activity

- 2026-10-13T16:20:27Z · created · njachowski@gmail.com
- 2026-10-13T16:20:35Z · body: section Screenshots
