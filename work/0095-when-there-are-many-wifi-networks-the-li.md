---
id: "0095"
title: Make the Wi-Fi network list scrollable
type: feature
status: active
priority: p2
area: macos
assigned_to: ai
created_by: api
branch: feat/make-the-wi-fi-network-list-scrollable
created_at: "2026-10-14T03:49:52Z"
updated_at: "2026-10-14T04:11:13Z"
review_rounds: 1
review_passes: 1
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

## Shots
```json
[
{
"label": "Wi-Fi popover network list",
"target": "Divot bar",
"env": {
"DIVOT_SNAPSHOT_ONLY": "wifi"
},
"glob": "*wifi*.png"
}
]
```

## Activity

- 2026-10-14T03:49:52Z · created · api
- 2026-10-14T03:49:52Z · screenshots
- 2026-10-14T03:49:52Z · screenshots
- 2026-10-14T03:50:06Z · status draft→inbox, title, area, assigned_to, body
- 2026-10-14T04:02:50Z · status inbox→ready
- 2026-10-14T04:02:59Z · status ready→active, branch
- 2026-10-14T04:07:22Z · body: section Shots
- 2026-10-14T04:10:02Z · status active→review
- 2026-10-14T04:11:10Z · note: review pass 1: needs some work
- 2026-10-14T04:11:13Z · status review→active
