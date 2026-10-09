---
id: "0004"
title: "Implement native provider lifecycle and clock, power, front-app widgets"
type: feature
status: active
needs_input: true
needs_input_reason: review-rounds-exhausted
needs_input_detail: The reviewer sent this back to the engineer 2 times and still found issues. Human review needed.
priority: p1
area: macos
story: A beautiful bar from the first launch
depends_on: ["0003"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/implement-native-provider-lifecycle-and-
review_cli_override: cursor
review_model_override: composer-2.5
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T18:44:11Z"
review_passes: 3
review_rounds: 2
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
- 2026-10-09T18:27:00Z · status active→review
- 2026-10-09T18:27:00Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T18:29:05Z · note: review pass 1: needs some work
- 2026-10-09T18:29:05Z · status review→active
- 2026-10-09T18:36:45Z · status active→review
- 2026-10-09T18:36:45Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T18:38:27Z · note: review pass 2: needs some work
- 2026-10-09T18:38:27Z · status review→active
- 2026-10-09T18:41:45Z · status active→review
- 2026-10-09T18:41:45Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
- 2026-10-09T18:43:05Z · note: review pass 3: needs some work
- 2026-10-09T18:43:05Z · needs_input
- 2026-10-09T18:43:22Z · review_cli_override
- 2026-10-09T18:43:25Z · review_model_override
- 2026-10-09T18:44:11Z · status review→active
