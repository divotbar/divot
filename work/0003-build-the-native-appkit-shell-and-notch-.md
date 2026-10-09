---
id: "0003"
title: Build the native AppKit shell and notch-aware display coordinator
type: feature
status: ready
priority: p1
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-09T16:18:39Z"
updated_at: "2026-10-09T16:20:19Z"
---
## Problem

Create an executable native app target using Swift/AppKit and the existing DivotCore geometry.

## Desired UX

Two nonactivating panels per display; workspaces left and status right. Public APIs, correct focus, notch-free fallback, geometry updates.

## Acceptance criteria

Build/run on macOS 26+; unit tests for geometry adapter; preserve front-app focus on workspace clicks; overflow does not cross notch. Document physical display/fullscreen checks separately.

## Notes for AI

Read docs/product-requirements.md, docs/architecture.md and ADR 0001. This is the first implementation slice. No providers or private APIs. Add an app build check once the target exists.

## Activity

- 2026-10-09T16:18:39Z · created · njachowski@gmail.com
- 2026-10-09T16:20:19Z · status inbox→ready
- 2026-10-09T16:20:19Z · note: Bootstrap docs, site, core geometry tests, and RepoOS gate are complete; first native implementation slice is ready for kickoff.
