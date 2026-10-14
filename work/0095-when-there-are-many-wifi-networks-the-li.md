---
id: "0095"
title: Make the Wi-Fi network list scrollable
type: feature
status: ready
priority: p2
area: macos
assigned_to: ai
created_by: api
branch: ""
created_at: "2026-10-14T03:49:52Z"
updated_at: "2026-10-14T04:02:50Z"
---
## Problem

When many Wi-Fi networks are available, the network list grows too tall.

## Desired UX

The Wi-Fi network list scrolls when its content exceeds 90% of the screen height, so it does not grow taller than that limit.

## Acceptance criteria

- [ ] The Wi-Fi network list has a maximum height of 90% of the screen height.
- [ ] When the list content exceeds that maximum height, the list can be scrolled to view the networks.

## Notes for AI

- Assume “screen height” means the height of the screen displaying the Wi-Fi network list.

## Scope

This task covers the Wi-Fi network list’s maximum height and scrolling behavior.

## Original prompt

When there are many wifi networks the list view gets too long, instead it should become scrollable. Let’s set the max height of the wifi network list at 90% of screen height.

## Screenshots

![Screenshot-2026-10-14-at-09.29.12](/api/tasks/0095/attachments/screenshot-1.png)
![Screenshot-2026-10-14-at-10.48.10](/api/tasks/0095/attachments/screenshot-2.png)

## Activity

- 2026-10-14T03:49:52Z · created · api
- 2026-10-14T03:49:52Z · screenshots
- 2026-10-14T03:49:52Z · screenshots
- 2026-10-14T03:50:06Z · status draft→inbox, title, area, assigned_to, body
- 2026-10-14T04:02:50Z · status inbox→ready
