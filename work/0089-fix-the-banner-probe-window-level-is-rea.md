---
id: "0089"
title: "Fix the banner probe: window level is read from a key that does not exist, so every level prints 0"
type: bug
status: active
priority: p2
area: macos
assigned_to: ""
created_by: njachowski@gmail.com
branch: feat/fix-the-banner-probe-window-level-is-rea
cli_override: claude code
model_override: haiku
created_at: "2026-10-13T16:29:02Z"
updated_at: "2026-10-13T16:29:13Z"
---
## Problem
The maintainer ran divot-notification-banner-probe on 2026-10-13 (macOS 26.5.2, one display, safeArea.top 33). Every window printed level=0, including Divot, Finder, the Dock and the Dock's Wallpaper window, which is impossible (the wallpaper layer is a large negative number, Dock and menu bar layers are positive). Cause: macos/Sources/DivotProbeCommon/WindowBounds.swift parseWindowLevelFromDict reads dict["kCGWindowLevel"], but CGWindowListCopyWindowInfo dictionaries carry the window layer under kCGWindowLayer (as in DivotSpacesProbe: info[kCGWindowLayer as String]); the other key does not exist, so the NSNumber cast always falls back to 0. The measurement task #0080 depends on this probe, so its output is currently useless.

## Desired UX
- The probe prints the real layer of every window, sorted highest first, so a notification banner window's layer can be compared with Divot's panel layer.
- It prints bounds correctly in both CG top-left coordinates and an explicit AppKit-flipped y.
- It keeps listening for a short window (for example a --watch [seconds] option, default 15, polling twice a second) and prints the NotificationCenter windows the moment one appears, so the maintainer can start it, then trigger a notification, without a shell loop.

## Acceptance criteria
- parseWindowLevelFromDict (rename to parseWindowLayerFromDict) reads kCGWindowLayer; unit test with a sample dictionary containing kCGWindowLayer = 25 and a negative wallpaper layer, and one without the key (returns 0).
- Do not keep the nonexistent key as a fallback. Update docs/evidence/0075-notification-banner-overlap.md and docs/troubleshooting.md wording that mentions window levels from the probe.
- --watch option implemented with tests for argument parsing; output includes the Divot panel layer for comparison.
- No private APIs. swift build and swift test --package-path macos pass; repoos check --changed main passes.
- After this lands the maintainer re-runs the probe while a banner is visible (task #0080); do not claim banner measurements.

## Notes for AI
Related: #0075, #0080. Evidence of the bug: all windows in the maintainer's output show level=0.

## Activity

- 2026-10-13T16:29:02Z · created · njachowski@gmail.com
- 2026-10-13T16:29:10Z · status inbox→ready
- 2026-10-13T16:29:11Z · cli_override, model_override
- 2026-10-13T16:29:13Z · status ready→active, branch
