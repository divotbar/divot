---
id: "0043"
title: Add a Homebrew cask so users can install Divot with brew
type: feature
status: ready
priority: p2
area: [macos, docs]
depends_on: ["0041"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T12:47:11Z"
updated_at: "2026-10-12T13:01:45Z"
---
## Problem

Users who prefer Homebrew have no install command. The maintainer wants a cask that installs the released DMG.

## Desired UX
- `brew install --cask divotbar/tap/divot` (or the final tap name) installs the latest released Divot.app.
- Same approach as RepoOS: a separate tap repo owns the cask and updates itself; the release workflow only dispatches an event to the tap after the GitHub Release exists.

## Acceptance criteria

- Add a Homebrew cask definition (in the repo under packaging/homebrew or in a tap, as the maintainer chooses) pointing at the v0.1.0 DMG with its SHA-256.
- Document the install command in docs/infrastructure.md and in the install page (#0042).
- Verify the cask file passes `brew audit --cask` locally where possible.
- `repoos check` passes.

## Notes for AI

Depends on the unsigned DMG release (#0041). Unsigned casks are accepted by Homebrew for now; do not add notarization claims.

## Activity

- 2026-10-11T12:47:11Z · created · njachowski@gmail.com
- 2026-10-12T11:38:53Z · status inbox→ready
- 2026-10-12T13:01:45Z · body: section Desired UX
