---
id: "0041"
title: Build an unsigned Divot.dmg and publish it on a GitHub Release from a version tag
type: feature
status: review
priority: p1
area: [macos, docs]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/build-an-unsigned-divot-dmg-and-publish-
created_at: "2026-10-11T12:47:05Z"
updated_at: "2026-10-11T13:19:12Z"
---
## Problem

Users have no way to download the app. The maintainer wants a DMG first, unsigned for now, and a signed DMG later.

## Desired UX

- Pushing a version tag such as v0.1.0 builds Divot.app in Release mode, packages it as a DMG, and attaches the DMG and its SHA-256 checksum to a GitHub Release.
- The release notes say the build is unsigned and how to open it (right-click, Open).

## Acceptance criteria

- Add a `scripts/make-dmg.sh` that creates Divot.dmg from dist/Divot.app with a drag-to-Applications layout.
- Add `.github/workflows/release.yml` that runs on version tags, on a macOS runner, and uploads the DMG and checksum to the release.
- Document the release steps in docs/infrastructure.md, including that the build is ad-hoc signed.
- Verify locally that the DMG mounts and the app inside launches.
- `repoos check` passes.

## Notes for AI

Unsigned build only. Do not add Developer ID signing or notarization here; that is a separate task blocked on the maintainer's certificate.

## Activity

- 2026-10-11T12:47:05Z · created · njachowski@gmail.com
- 2026-10-11T12:47:16Z · status inbox→ready
- 2026-10-11T12:47:17Z · status ready→active, branch
- 2026-10-11T12:51:54Z · status active→review
- 2026-10-11T12:51:54Z · note: shots: skipped — the diff (4 changed paths) touches no [[preview.paths]] globs — no UI change to capture
- 2026-10-11T12:52:10Z · note: review pass 1: failed — no usable report
- 2026-10-11T12:52:10Z · needs_input
- 2026-10-11T13:18:11Z · needs_input
- 2026-10-11T13:18:11Z · status review→active
- 2026-10-11T13:18:11Z · note: follow-up message — moved from review to active so work can be committed and re-handoffed
- 2026-10-11T13:19:12Z · status active→review
