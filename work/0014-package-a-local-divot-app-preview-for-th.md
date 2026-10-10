---
id: "0014"
title: Package a local Divot.app preview for this Mac
type: feature
status: review
priority: p1
area: [macos, docs]
story: A beautiful bar from the first launch
depends_on: ["0007"]
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/package-a-local-divot-app-preview-for-th
created_at: "2026-10-09T16:44:33Z"
updated_at: "2026-10-10T02:52:32Z"
---
## Problem

The user wants to start using Divot on this Mac as soon as a useful build is ready. Public Developer ID distribution is a separate signing gate and should not obscure a local preview milestone.

## Desired UX

A reproducible local Divot.app bundle, built from the reviewed and landed source, with a short install/run guide for this Mac and the agreed default bar.

## Acceptance criteria

- Add documented just recipes for building and running an actual app bundle; use Release optimization for the usable preview.
- Package a versioned local preview archive with build commit and checksum; clearly label local/ad-hoc signing versus a public notarized release.
- Default left: workspace navigation and frontmost app. Right: battery %, time + weekday/date, Wi-Fi/network, volume. All four requested theme families and custom groups available.
- Persistent top/below native menu-bar behavior is implemented and its remaining platform/device limits disclosed, never silently hidden.
- Run declared checks and automated launch/smoke coverage where supported; do not claim a human checked appearance, VoiceOver or desktop behavior unless recorded.
- Provide actionable first-run instructions and a clear remaining hardware checklist. Notify the user with the actual bundle/archive location when it can be tried on this Mac.
- No root installer, altered security settings, quarantine-stripping instructions, guessed signing identity, or unapproved public deployment. Public signed release remains #0008.

## Notes for AI

The user authorized driving the board toward a usable build/release on 2026-10-10. Use normal RepoOS engineer, independent review, checks and close-out. Depends on the performance/app readiness milestone #0007; yabai/native Spaces are later integrations and need not block the AeroSpace-first local preview. Version this preview honestly, e.g. 0.1.0-preview.1, when packaging exists.

## Local rollout context
The maintainer Mac runs AeroSpace with a-bar. The reference bar has compact numbered workspaces with app icons left and volume, network, date, time and battery right. Divot should offer calmer spacing, typography and cohesive themes while retaining optional workspace app icons. Once a checked preview is ready, inspect the actual a-bar launch mechanism, temporarily stop only a-bar for comparison, preserve its configuration and record an exact restoration command. Keep AeroSpace running. The user authorizes a reversible local switch; do not uninstall a-bar or permanently modify login startup without a separate request. The user revoked the USD 2/hour cap and spend hold on 2026-10-10, conditional on keeping all configured roles, coding agents and models unchanged.

## Activity

- 2026-10-09T16:44:33Z · created · njachowski@gmail.com
- 2026-10-09T16:47:36Z · body: section Local rollout context
- 2026-10-09T17:20:40Z · status inbox→ready
- 2026-10-09T17:20:44Z · body: section Local rollout context
- 2026-10-10T02:32:20Z · status ready→active, branch
- 2026-10-10T02:52:32Z · status active→review
- 2026-10-10T02:52:32Z · note: shots: skipped — website matched only documentation content, and no declared shot names a route — docs captures need a declared route, so this target was skipped
