---
id: "0088"
title: "World clock popover does not work in the real app and does not match its shots: fix, simplify, verify the real flow"
type: bug
status: active
priority: p0
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/world-clock-popover-does-not-work-in-the
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-13T16:20:27Z"
updated_at: "2026-10-13T19:24:50Z"
close_out_repair_count: 1
review_passes: 8
review_rounds: 2
dev_error_count: 1
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

## Shots
```json
[
{
"label": "Empty state (0 zones): header + hint, Add row and settings link",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "zero-timezones"
},
"glob": "*worldclock*zero-timezones*"
},
{
"label": "Default first-run state: three defaults (San Francisco, London, Singapore)",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "default-defaults"
},
"glob": "*worldclock*default-defaults*"
},
{
"label": "One zone: a single added zone row (Tokyo)",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "one-zone"
},
"glob": "*worldclock*one-zone*"
},
{
"label": "Four zones with Yesterday/Tomorrow day labels across the date line",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "day-label"
},
"glob": "*worldclock*day-label*"
},
{
"label": "Add flow: 'los' typed, results list visible (San Francisco)",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "add-flow"
},
"glob": "*worldclock*add-flow*"
}
]
```

## Root cause
Reproduced and fixed through the real controller path (`WorldClockPopoverController` -> `WorldClockPopoverContentController` inside `BarPopoverHost`):

1. **Panel sizing.** `render()` rebuilt the rows but never called `host.resize(to:)`, so the panel stayed at its initial footer-only height while the stack grew underneath - the large blank chrome in the packaged app.
2. **Search action.** The search field relied on `NSSearchField.action`, which fires on Return or the search button, not on each keystroke. Live results now come from the `NSControl.textDidChangeNotification` observer.
3. **Empty list conflated with defaults.** An empty `widgets.time.timezones` was treated the same as "never configured". The field is `[String]?`: absent (nil) resolves to the three defaults, an explicitly empty array stays empty.
4. **Add/remove did not re-render.** Adding or removing a zone only invoked the update callback, not a re-render plus resize, so rows did not appear or disappear until the next provider tick. The callback now persists and re-renders.
5. **Footer row wiped by the rebuild.** `render()` calls `clearRows()`, which also removed the "Open Date & Time Settings..." row that `loadView` added, so every rendered popover lost its last row. The footer is now rebuilt at the end of each render.
6. **Results list layout.** The results scroll view had no Auto Layout height (a plain frame change is ignored once it is an arranged subview), kept whatever theme it was first built with, and AppKit's full-width table insets every cell by 6pt. Its height now tracks the row count, a restyle recolours the rows, and a custom row view plus flush constraints align the results with the other rows.
7. **Snapshots were not the real states.** The snapshot tests rendered hard-coded zone arrays through a count switch, so they never showed the true first-run defaults or the add flow. They now resolve the empty and default lists through `WorldClock.resolvedTimezones` (the same path production and the Settings list use) and drive the real search field for the add-flow shot.

## Shot descriptions
Captured with `repoos shot --target "Divot bar" --glob '*worldclock*.png'` (Native and Gruvbox, light and dark, default text size) on the Asia/Jakarta machine (UTC+7); the live time reads 02:21. Every image renders the real `WorldClockPopoverContentController`; the only chrome missing is the popover window itself (arrow, shadow), which the offscreen render does not draw. 20 images: five states in two themes and two variants.

### Empty state - `*worldclock*zero-timezones*` (4 images)
`divot-bar-worldclock-popover-{native,gruvbox}-{light,dark}-default-zero-timezones-1.png`

Header `02:21 UTC+7` with the local zone `Jakarta` beneath, the hint `No other timezones. Add one below.`, the `Add timezone...` row with its search field, and the `Open Date & Time Settings...` link. No zone rows and nothing disabled: the empty list stays fully functional. Native/Gruvbox and light/dark only change the palette.

### Default first-run state - `*worldclock*default-defaults*` (4 images)
`divot-bar-worldclock-popover-{native,gruvbox}-{light,dark}-default-defaults-1.png`

Header `02:21 UTC+7` / `Jakarta`, then the three defaults resolved from an absent config key: `San Francisco  12:21 (14 h behind) Yesterday`, `London  20:21 (6 h behind) Yesterday`, `Singapore  03:21 (1 h ahead)`, each with a remove control; then the Add row and the settings link. This is the state the old `two-timezones` glob never showed.

### One zone - `*worldclock*one-zone*` (4 images)
`divot-bar-worldclock-popover-{native,gruvbox}-{light,dark}-default-one-zone-1.png`

Header `02:21 UTC+7` / `Jakarta`, then a single stored zone `Tokyo  04:21 (2 h ahead)` with its remove control; Add row; settings link. Covers the "one zone" acceptance case, distinct from both the empty state and the defaults.

### Four zones with day labels - `*worldclock*day-label*` (4 images)
`divot-bar-worldclock-popover-{native,gruvbox}-{light,dark}-default-day-label-1.png`

Rendered at the fixed instant 2026-01-01T10:00Z local UTC: header `10:00 UTC+0` / `GMT`, then `Kiritimati  00:00 (14 h ahead) Tomorrow`, `Midway  23:00 (11 h behind) Yesterday`, `Tokyo  19:00 (9 h ahead)`, `San Francisco  02:00 (8 h behind)`; Add row; settings link. Proves both a Yesterday and a Tomorrow label across the date line.

### Add flow - `*worldclock*add-flow*` (4 images)
`divot-bar-worldclock-popover-{native,gruvbox}-{light,dark}-default-add-flow-1.png`

The empty state with `los` typed into the real search field and the result `San Francisco` visible directly beneath it, flush with the other rows; the Add row and the settings link are still present. Proves typing now returns a usable result (ranked so city matches come first) instead of nothing.

The zone list fits up to eight rows and scrolls beyond that (`zoneRowsAreCappedAtEightAndScrollBeyond`), so a long list never grows the panel without bound; these shots cover 0-4 zones.

## Root causes
Consolidated into **Root cause** above (the two headings are left from parallel edits; the singular section is authoritative). This follow-up pass also adds: the panel-height cap (0–8 zones fit, the list scrolls beyond eight rows), one ranked search that puts city-name matches ahead of identifier-only matches, a single `WorldClock.friendlyName` shared by the popover, its search results and the Settings list, and windowless tests through the real `WorldClockPopoverController` (absent/empty/unset, remove-all then add then reopen, panel cap).

## Activity

- 2026-10-13T16:20:27Z · created · njachowski@gmail.com
- 2026-10-13T16:20:35Z · body: section Screenshots
- 2026-10-13T16:25:38Z · body: section Default timezones
- 2026-10-13T16:25:59Z · body: section Empty list must stay fully functional
- 2026-10-13T16:29:07Z · status inbox→ready
- 2026-10-13T16:29:08Z · cli_override, model_override
- 2026-10-13T16:29:08Z · status ready→active, branch
- 2026-10-13T16:47:59Z · status active→review
- 2026-10-13T16:48:09Z · note: 28 more images not shown (cap 12 per task) — declare a `## Shots` entry with a `glob` to capture a specific one
- 2026-10-13T16:49:20Z · note: review pass 1: needs some work
- 2026-10-13T16:49:20Z · status review→active
- 2026-10-13T16:55:38Z · message_queued at 2026-10-13T16:55:38.559Z
- 2026-10-13T16:58:21Z · status active→review
- 2026-10-13T16:58:22Z · note: shots: skipped — 12 handoff shots already captured for this exact plan (ba47c0df) during finalization (#0734)
- 2026-10-13T17:00:08Z · note: review pass 2: needs some work
- 2026-10-13T17:00:08Z · message_delivered: 1 message(s)
- 2026-10-13T17:00:08Z · status review→active
- 2026-10-13T17:06:13Z · status active→review
- 2026-10-13T17:06:13Z · note: shots: skipped — 12 handoff shots already captured for this exact plan (3e4e0c11) during finalization (#0734)
- 2026-10-13T17:07:28Z · note: review pass 3: needs some work
- 2026-10-13T17:07:28Z · needs_input
- 2026-10-13T17:10:50Z · needs_input
- 2026-10-13T17:10:50Z · status review→active
- 2026-10-13T17:10:50Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T17:14:21Z · status active→review
- 2026-10-13T17:14:21Z · note: shots: skipped — 12 handoff shots already captured for this exact plan (3e4e0c11) during finalization (#0734)
- 2026-10-13T17:15:52Z · note: review pass 4: needs some work
- 2026-10-13T17:15:52Z · needs_input
- 2026-10-13T17:19:36Z · needs_input
- 2026-10-13T17:19:36Z · status review→active
- 2026-10-13T17:19:36Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T17:22:01Z · body: section Shots
- 2026-10-13T17:22:12Z · body: section Shots
- 2026-10-13T17:27:41Z · message_queued at 2026-10-13T17:27:41.211Z
- 2026-10-13T17:27:41Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
- 2026-10-13T17:44:12Z · status active→review
- 2026-10-13T17:44:13Z · note: shots: failed — capture command for "Divot bar" exited 127 sh: scripts/swift-test-lock.sh: No such file or directory
- 2026-10-13T17:44:13Z · note: shots: failed — capture command for "Divot bar" exited 127 sh: scripts/swift-test-lock.sh: No such file or directory
- 2026-10-13T17:44:13Z · note: shots: failed — capture command for "Divot bar" exited 127 sh: scripts/swift-test-lock.sh: No such file or directory
- 2026-10-13T17:44:13Z · note: shots: failed — capture command for "Divot bar" exited 127 sh: scripts/swift-test-lock.sh: No such file or directory
- 2026-10-13T17:46:22Z · note: review pass 5: needs some work
- 2026-10-13T17:46:23Z · needs_input
- 2026-10-13T17:49:23Z · needs_input
- 2026-10-13T17:49:24Z · status review→active
- 2026-10-13T17:49:24Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T17:49:24Z · message_delivered: 1 message(s)
- 2026-10-13T17:54:04Z · status active→review
- 2026-10-13T17:54:04Z · note: shots: skipped — 16 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T17:56:15Z · note: review pass 6: needs some work
- 2026-10-13T17:56:15Z · needs_input
- 2026-10-13T17:58:43Z · needs_input
- 2026-10-13T17:58:43Z · status review→active
- 2026-10-13T17:58:43Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T18:00:31Z · cli_override, model_override
- 2026-10-13T18:00:32Z · status active→review
- 2026-10-13T18:00:32Z · note: handoff requested (cli)
- 2026-10-13T18:00:59Z · status active→review
- 2026-10-13T18:00:59Z · note: shots: skipped — 16 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T18:02:20Z · note: review pass 7: needs some work
- 2026-10-13T18:02:20Z · needs_input
- 2026-10-13T18:07:50Z · needs_input
- 2026-10-13T18:07:50Z · status review→active
- 2026-10-13T18:07:50Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T18:16:17Z · agent exited with an error (opencode) · error: Transport
- 2026-10-13T18:21:33Z · needs_input
- 2026-10-13T18:43:10Z · body: section Root cause
- 2026-10-13T18:43:20Z · body: section Shots
- 2026-10-13T18:45:32Z · body: section Shots
- 2026-10-13T18:52:10Z · body: section Shots
- 2026-10-13T18:54:22Z · body: section Shot descriptions
- 2026-10-13T18:59:56Z · body: section Root causes
- 2026-10-13T19:06:13Z · body: section Shots
- 2026-10-13T19:06:15Z · body: section Shots
- 2026-10-13T19:06:30Z · body: section Root causes
- 2026-10-13T19:09:06Z · body: section Shot descriptions
- 2026-10-13T19:12:43Z · status active→review
- 2026-10-13T19:12:43Z · note: shots: skipped — 20 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T19:15:48Z · note: review pass 8: needs some work
- 2026-10-13T19:15:49Z · needs_input
- 2026-10-13T19:17:06Z · status review→active, needs_input
- 2026-10-13T19:17:06Z · note: close-out repair: merge-conflict
- 2026-10-13T19:19:38Z · body: section Shots
- 2026-10-13T19:21:44Z · body: section Shot descriptions
- 2026-10-13T19:24:50Z · note: shots: skipped — 20 shots already captured — an engineer-made capture pre-empts the automatic one
