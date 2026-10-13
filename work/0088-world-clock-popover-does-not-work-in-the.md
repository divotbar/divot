---
id: "0088"
title: "World clock popover does not work in the real app and does not match its shots: fix, simplify, verify the real flow"
type: bug
status: review
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/world-clock-popover-does-not-work-in-the
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T16:20:27Z"
updated_at: "2026-10-13T16:47:59Z"
---
## Problem
#0085 landed, but in the packaged app (maintainer screenshot 2026-10-13 23:16, UTC+7) the world clock popover does not work and looks wrong.

### Root causes identified and fixed:
1. **Panel sizing**: `render()` never called `host.resize(to:)`, leaving the panel at the initial footer-only size while the stack grew underneath, creating large empty chrome.
2. **Search keystroke**: `NSSearchField.action` only fires on Return/search-button, not on each keystroke. Switched to `NSControl.textDidChangeNotification` for live results.
3. **Config distinction**: Empty timezone list was conflated with "never configured". Changed to `[String]?` to distinguish absent (nil → use defaults) from explicit empty.
4. **Re-render after add/remove**: Timezone updates only called the callback, not `render()` + `host.resize()`, so rows didn't appear/disappear until the next tick.
5. **Shots rendering**: Test snapshots used a mock layout, not the real BarPopoverHost/panel sizing path.

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

## Default timezones
Added by the maintainer 2026-10-13: the list must not start empty, so a first-time user sees something that makes sense.

- Default zones when the user has never configured the list: San Francisco (America/Los_Angeles), London (Europe/London) and Singapore (Asia/Singapore), in that order. Display the friendly city names San Francisco, London, Singapore (the identifier for San Francisco is America/Los_Angeles; show 'San Francisco').
- Distinguish 'never configured' from 'explicitly emptied': if widgets.time.timezones is ABSENT from the config, use the three defaults; once the user adds or removes any zone the list is written to the config exactly as shown, and an explicitly empty list stays empty (the empty state with the hint and Add row). Do not silently re-add defaults after the user removed them.
- If one of the default zones is the user's own local zone, do not show it twice: the local zone is already in the header, so skip it.
- The config schema default, the config CLI schema (divot config schema), the Settings window list, docs/configuration.md, site/reference/configuration.md and the widgets guide must state the three defaults and the absent-vs-empty rule; the unit tests cover: absent -> three defaults, present and empty -> empty, user removes one default -> remaining two persist, local zone equals a default -> no duplicate row.
- Shots: the 'four zones' and 'empty state' shots from the acceptance criteria stay; add a shot of the default first-run state (three defaults, Singapore showing as the user's own zone when the local zone is Singapore, if you can render with an injected local zone).

## Empty list must stay fully functional
Added by the maintainer 2026-10-13: when the user has removed ALL timezones the popover must remain fully working, not a dead end.

- With zero zones the popover still shows the header (current time and UTC offset, local zone name), a short hint line ('No other timezones. Add one below.'), the 'Add timezone' row with a working search field and results list, and 'Open Date & Time Settings...'. Nothing is hidden or disabled because the list is empty.
- Adding a zone from the empty state works exactly as from a populated list: typing shows results, choosing one adds the row immediately and persists it, and the hint disappears.
- Removing the last remaining zone leaves the list explicitly empty (persisted as an empty array, NOT reset to the defaults) and the popover rebuilds into this empty state immediately without closing or crashing.
- Reopening the popover after removing everything still shows the empty state with a working Add row; the three defaults only come back if the config key is absent (for example the user deletes it from the file or runs divot config unset widgets.time.timezones).
- The Settings window list behaves the same: removing everything leaves a working Add control.
- Tests (through the real controller path, as above): remove every default one by one -> empty state rows are correct; add a zone from empty -> persisted and shown; reopen after emptying -> still empty; unset the key -> defaults return. Add an empty-state shot and an 'after adding from empty' shot.

## Activity

- 2026-10-13T16:20:27Z · created · njachowski@gmail.com
- 2026-10-13T16:20:35Z · body: section Screenshots
- 2026-10-13T16:25:38Z · body: section Default timezones
- 2026-10-13T16:25:59Z · body: section Empty list must stay fully functional
- 2026-10-13T16:29:07Z · status inbox→ready
- 2026-10-13T16:29:08Z · cli_override, model_override
- 2026-10-13T16:29:08Z · status ready→active, branch
- 2026-10-13T16:47:59Z · status active→review
