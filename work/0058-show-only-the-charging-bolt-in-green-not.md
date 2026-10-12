---
id: "0058"
title: "Show only the charging bolt in green, not the battery outline"
type: feature
status: inbox
priority: p2
area: macos
depends_on: ["0056"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-12T08:36:25Z"
updated_at: "2026-10-12T08:36:25Z"
---
## Problem

When charging, the battery item shows a bolt, but it is drawn in the same colour as the battery and is hard to see. The maintainer wants only the bolt green, with the battery outline left as it is.

## Desired UX

- While charging, the bolt is green and the battery outline keeps the bar's normal colour.
- When not charging, there is no bolt and no green.

## Acceptance criteria

- Draw the bolt as a separate green element on top of the battery symbol, using a fixed green from the theme's accent set rather than a hard-coded colour in a view.
- Tests cover the charging and not-charging states and that only the bolt uses the green.
- Verify on the packaged app while charging; record the observed colours in the task.
- repoos check passes.

## Notes for AI

Depends on the icon-size task, which changes the same battery symbol drawing.

## Activity

- 2026-10-12T08:36:25Z · created · njachowski@gmail.com
