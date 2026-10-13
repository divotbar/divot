---
id: "0082"
title: Add Alpine theme and refresh landing-page examples
type: feature
status: ready
priority: p2
area: web
assigned_to: ai
created_by: api
branch: ""
cli_override: opencode
model_override: opencode-go/deepseek-v4.1-flash
created_at: "2026-10-13T08:56:17Z"
updated_at: "2026-10-13T09:01:35Z"
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

## Activity

- 2026-10-13T08:56:17Z · created · api
- 2026-10-13T08:56:18Z · screenshots
- 2026-10-13T08:56:37Z · status draft→inbox, title, area, assigned_to, body
- 2026-10-13T09:01:16Z · status inbox→ready
- 2026-10-13T09:01:26Z · cli_override, model_override
- 2026-10-13T09:01:35Z · model_override
