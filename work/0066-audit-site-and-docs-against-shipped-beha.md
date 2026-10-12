---
id: "0066"
title: Audit site and docs against shipped behaviour
type: chore
status: review
priority: p1
area: [docs, web]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/audit-site-and-docs-against-shipped-beha
created_at: "2026-10-12T11:40:14Z"
updated_at: "2026-10-12T12:01:56Z"
---
## Problem
Many features landed on 2026-10-11/12 (split date/time, chips, spacing and right inset, charging colour, keep-awake cup, Wi-Fi name and Location, Appearance item, native icon sizes). Docs were updated per task, so drift is likely in the guide pages, getting-started, roadmap, troubleshooting and the landing page.

## Desired UX
- Every page under site/ and docs/ matches current main: settings, defaults, item list, spacing, permissions (Accessibility, Location), install state.
- Roadmap lists only what is truly planned; nothing planned is described as shipped; no invented release links or availability.

## Acceptance criteria
- A list in the task of every page checked and each fix made; bun run check passes.
- Tahoe editorial direction and licence/credit rules in AGENTS.md respected.

## Notes for AI
Compare against the code and docs/configuration.md. Do not touch install/download copy (#0042 owns that).

## Activity

- 2026-10-12T11:40:14Z · created · njachowski@gmail.com
- 2026-10-12T11:40:16Z · status inbox→ready
- 2026-10-12T11:55:20Z · status ready→active, branch
- 2026-10-12T12:01:56Z · status active→review
