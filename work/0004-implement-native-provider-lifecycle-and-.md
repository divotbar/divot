---
id: "0004"
title: "Implement native provider lifecycle and clock, power, front-app widgets"
type: feature
status: active
priority: p1
area: macos
story: A beautiful bar from the first launch
depends_on: ["0003"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/implement-native-provider-lifecycle-and-
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T18:27:00Z"
---
## Problem

The useful default bar needs actual status and active-app data, not illustrative placeholders.

## Desired UX

Left active/frontmost app next to workspaces. Right battery percentage, local clock with weekday/date, Wi-Fi/network and volume. Built-in defaults require no setup questionnaire.

## Acceptance criteria

Native provider lifecycle and notifications where supported; minute clock; power/network/volume data and contextual unavailable states. Tests cover cancellation, stale completions, independent failures and no main-thread I/O. Explicitly design native click controls/settings links without assuming mirroring of system menu extras. Denied access degrades gracefully; network details do not force unnecessary permissions.

## Notes for AI

Default positions are configurable through the shared model; no continuous shell polling. Read first-launch and customization stories. All listed providers are required for the first useful release.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:41:13Z · story, body
- 2026-10-09T17:20:38Z · status inbox→ready
- 2026-10-09T18:02:46Z · status ready→active, branch
- 2026-10-09T18:27:00Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
