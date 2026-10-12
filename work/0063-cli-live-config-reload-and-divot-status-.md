---
id: "0063"
title: "CLI: live config reload and divot status --json"
type: feature
status: review
priority: p1
area: macos
depends_on: ["0062"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/cli-live-config-reload-and-divot-status-
created_at: "2026-10-12T11:39:01Z"
updated_at: "2026-10-12T12:04:57Z"
---
## Problem
CLI changes should take effect without restarting the app, and agents need diagnostics.

## Desired UX
- Running app applies config changes immediately (file watch or divot reload).
- divot status --json: app version, running state, Accessibility granted, Location granted, workspace adapter detected (AeroSpace/yabai), config path and validity.
- Permission gaps are reported with the System Settings pane to open; the CLI never tries to grant them.

## Acceptance criteria
- Reload applies a valid change and keeps the old config on an invalid one, with tests.
- status output covered by tests with an injectable environment.
- No permanent render loop or busy polling.
- Docs updated.

## Notes for AI
Builds on the config CLI from #0062.

## Activity

- 2026-10-12T11:39:01Z · created · njachowski@gmail.com
- 2026-10-12T11:55:19Z · status inbox→ready
- 2026-10-12T11:55:20Z · status ready→active, branch
- 2026-10-12T12:04:57Z · status active→review
- 2026-10-12T12:04:57Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
