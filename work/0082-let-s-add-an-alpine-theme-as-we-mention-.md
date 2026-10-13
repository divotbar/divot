---
id: "0082"
title: Add Alpine theme and refresh landing-page examples
type: feature
status: review
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p2
area: web
assigned_to: ai
created_by: api
branch: feat/add-alpine-theme-and-refresh-landing-pag
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-13T08:56:17Z"
updated_at: "2026-10-13T10:53:08Z"
review_passes: 4
review_rounds: 2
last_check_failure: "repoos check at 2026-10-13T09:41:07.861Z: repoos check failed: ◆ Check plan"
---
## Problem

The landing page mentions an Alpine theme, but the theme and the three examples it presents need to be brought into alignment. The bar examples should also reflect the bar’s real, current design rather than showing outdated or inaccurate representations.

## Desired UX

The landing page presents Alpine, Gruvbox, and Dracula as its three examples. Alpine is available as a theme, and each bar example looks like the current bar design. The examples may be simplified for the landing page while remaining based on that design.

## Acceptance criteria

- [ ] Add an Alpine theme consistent with the existing theme implementation.
- [ ] Update the landing page to show Alpine, Gruvbox, and Dracula as its three examples.
- [ ] Make the bar shown in each example reflect the real, current bar design; use actual bar shots where useful, or simplify the presentation while keeping it based on that design.

## Notes for AI

- Assume Alpine refers to a bar theme consistent with the Alpine direction already mentioned on the landing page.
- Follow existing theme and landing-page patterns.
- Use the available shot capabilities to capture the actual bar if helpful; a simplified landing-page example is also acceptable.
- Do not invent additional themes or change unrelated landing-page content.

## Scope

Covers adding the Alpine theme and updating the landing-page bar examples. Does not require changes to unrelated product areas.

## Original prompt

Let’s add an “Alpine” theme as we mention on the landing page (and change the landing page to use the 3 examples: Alpine, Gruvbox, Dracula. Also make sure the bar examples shown in the bar are actually based on the real, current design of the bar (and now we have shots capabilities, so you ca use that to get shots of the actual bar - but you can also edit it a bit to simplify the one we show on the landing page)

## Screenshots

![Screenshot-2026-10-13-at-15.52.53](/api/tasks/0082/attachments/screenshot-1.png)

## Shots
```json
[
{"target":"website","route":"/","label":"Landing hero bar — Alpine (default)","highlight":".desktop-preview .mock-bar"},
{"target":"website","route":"/","label":"Bar example — Gruvbox","highlight":".try-section .bar-demo","steps":[{"click":".preset-buttons button:nth-child(2)"},{"waitMs":250}]},
{"target":"website","route":"/","label":"Bar example — Dracula","highlight":".try-section .bar-demo","steps":[{"click":".preset-buttons button:nth-child(3)"},{"waitMs":250}]}
]
```

## Activity

- 2026-10-13T08:56:17Z · created · api
- 2026-10-13T08:56:18Z · screenshots
- 2026-10-13T08:56:37Z · status draft→inbox, title, area, assigned_to, body
- 2026-10-13T09:01:16Z · status inbox→ready
- 2026-10-13T09:01:26Z · cli_override, model_override
- 2026-10-13T09:01:35Z · model_override
- 2026-10-13T09:01:36Z · status ready→active, branch
- 2026-10-13T09:16:29Z · body: section Shots
- 2026-10-13T09:19:05Z · body: section Shots
- 2026-10-13T09:20:12Z · status active→review
- 2026-10-13T09:22:30Z · note: review pass 1: needs some work
- 2026-10-13T09:22:30Z · status review→active
- 2026-10-13T10:03:11Z · message_queued at 2026-10-13T10:03:11.315Z
- 2026-10-13T10:03:11Z · CTO nudge: sent engineer a completion reminder after 5m without worktree activity
- 2026-10-13T10:24:00Z · status active→review
- 2026-10-13T10:24:00Z · note: shots: skipped — 3 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T10:27:06Z · note: review pass 2: needs some work
- 2026-10-13T10:27:06Z · message_delivered: 1 message(s)
- 2026-10-13T10:27:06Z · status review→active
- 2026-10-13T10:28:40Z · status active→review
- 2026-10-13T10:28:40Z · note: shots: skipped — 6 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T10:32:20Z · note: review pass 3: needs some work
- 2026-10-13T10:32:20Z · needs_input
- 2026-10-13T10:37:44Z · needs_input
- 2026-10-13T10:37:44Z · status review→active
- 2026-10-13T10:37:44Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T10:40:34Z · note: Shots re-captured on the final merged tree (HEAD 481ebd5) after merging main and committing, so nothing is committed after the capture.

Landing / Alpine examples (website target, route /):
- 'Landing hero bar — Alpine (default)': the hero bar over the Lake Tahoe photo drawn with Alpine's dark tokens (background #16272B, text #E8EFEB, focused chip #47809E, accent #7CE3D8-ish lake blue). Left group: Divot mark, workspace chips 01-04 with one focused, and the front-app item; right group in the shipped default order: battery %, time, Wi-Fi, volume %. This reflects the real current bar layout (front-app on the left; battery, time, network, volume on the right) rather than the old app/wifi/battery/date/time arrangement.
- 'Bar example — Gruvbox': the playground bar recoloured with Gruvbox dark tokens (bar #282828, text #EBDBB2, focused chip #83A598, accent #FABD2F) with the Gruvbox preset button selected.
- 'Bar example — Dracula': the same bar recoloured with Dracula dark tokens (bar #282A36, text #F8F8F2, focused chip #6272A4, accent #BD93F9) with the Dracula preset button selected.

The three preset buttons now read Alpine / Gruvbox / Dracula, matching the theme families the app ships. The PNGs are stored under the task shots folder; the reviewer can inspect them there. (The native Divot bar target is captured separately below.)
- 2026-10-13T10:41:54Z · status active→review
- 2026-10-13T10:41:54Z · note: shots: skipped — 17 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T10:44:05Z · note: review pass 4: needs some work
- 2026-10-13T10:44:05Z · needs_input
- 2026-10-13T10:49:30Z · needs_input
- 2026-10-13T10:49:30Z · status review→active
- 2026-10-13T10:49:30Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-13T10:51:10Z · status active→review
- 2026-10-13T10:51:10Z · note: shots: skipped — 17 shots already captured — an engineer-made capture pre-empts the automatic one
- 2026-10-13T10:53:08Z · note: review pass 5: needs some work
- 2026-10-13T10:53:08Z · needs_input
