---
id: "0042"
title: Update the landing and docs with install instructions for the DMG
type: feature
status: inbox
priority: p1
area: [macos, docs]
assigned_to: ""
created_by: njachowski@gmail.com
branch: ""
created_at: "2026-10-11T12:47:05Z"
updated_at: "2026-10-11T12:47:05Z"
---
## Problem

The site doesn't tell users how to get the app. Once the release exists, it should link to the latest DMG and explain the first launch.

## Desired UX

- A Download / Install page with a button to the latest DMG on the GitHub Release.
- First-launch steps for the unsigned build (right-click, Open, then allow in Privacy & Security if needed) and the Accessibility permission steps.
- The landing page links to the install page.

## Acceptance criteria

- Add site/guide/install.md with the download link, checksum note, first launch steps and the Accessibility setup.
- Link it from the landing page and the sidebar.
- The download link points at the GitHub Release "latest" asset.
- The page builds with `bun run build`.
- `repoos check` passes.

## Notes for AI

Depends on the unsigned DMG release task. Do not promise signed or notarized builds yet.

## Activity

- 2026-10-11T12:47:05Z · created · njachowski@gmail.com
