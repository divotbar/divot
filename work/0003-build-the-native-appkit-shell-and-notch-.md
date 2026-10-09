---
id: "0003"
title: Build the native AppKit shell and notch-aware display coordinator
type: feature
status: inbox
priority: p1
area: macos
story: Divot stays visible when the native menu bar appears
depends_on: ["0009", "0010"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T16:41:15Z"
---
## Problem

Create the Swift/AppKit app target and display coordinator around the proven persistent top/below placement strategy.

## Desired UX

Notch-aware bar panels stay visible; when the native menu bar appears they shift below it, and return to the top when it hides. Correct focus and per-display geometry.

## Acceptance criteria

Executable app builds on macOS 26+; tested placement state machine and notch/no-notch geometry; cancellable rapid transitions; reduced-motion reposition; no overlap/focus theft. Below-bar mode recomputes layout and content gap policy. Add app build gate. Physical fullscreen/Spaces/display evidence is recorded separately, never invented.

## Notes for AI

User-approved story supersedes starter hide-on-fullscreen assumption. Read the feasibility report and aligned docs. Do not implement hide as fallback without a product decision.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:20:19Z · status inbox→ready
- 2026-10-09T16:20:19Z · note: Bootstrap docs, site, core geometry tests, and RepoOS gate are complete; first native implementation slice is ready for kickoff.
- 2026-10-09T16:41:13Z · story, depends_on, body
- 2026-10-09T16:41:15Z · status ready→inbox
- 2026-10-09T16:41:15Z · note: Product stories add a persistent top/below feasibility gate and docs alignment before the shell.
