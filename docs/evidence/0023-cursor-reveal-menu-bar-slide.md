# Evidence · 0023 cursor-reveal slide below the native menu bar

Status: **automated implementation and checks pass; visual slide and maintainer
feel are not claimed.** Task 0023 · observed 2026-10-10 on the maintainer Mac
(macOS 26.5.2, arm64).

This records what automated verification observed in one run. It does not claim
the slide looks correct, lands on time, or feels right on hardware; a person
must still run the [menu-bar reveal checklist](../local-preview.md) and attach a
screen capture.

## Automated (this run)

| Check | Result |
| --- | --- |
| `REPOOS_CHECK_CHANGED=main repoos check` | **PASS** (includes `native-app-bundle` / `smoke-app-bundle.sh`) |
| `swift test --package-path macos` | **419 tests** (cursor enter/dwell/leave, `visibleFrame` disagreement, toggle off, Reduced Motion, monitor gating, config round-trip) |
| `bun run check` (scoped) | **PASS** via `repoos check` |

Packaged `dist/Divot.app` from this worktree (`scripts/package-app.sh` via the
check step). `divot --report` from that bundle (pointer not in the top strip at
capture time):

```text
moveBelowOnCursorReveal=true
alwaysBelow=false
cursorEngaged=
cursorGlobalMonitor=installed
reduceMotion=false
display-1 notched=true visibility=hidden
  mode=topEdge left=(0.0, 1075.0, 753.0, 32.0) right=(958.0, 1075.0, 752.0, 32.0)
```

`cursorGlobalMonitor=installed` means AppKit accepted a global mouse-moved
monitor for this session (contrast with launch stderr when it is unavailable).

## Pointer-warp experiment (inconclusive)

A short Swift harness posted `CGEvent` mouse-moved events to the top edge
(`y=1106` on the built-in 1710×1107 display) and read on-screen Divot panel
frames via `CGWindowListCopyWindowInfo`. Panel `y` stayed at `0` before and
after the warp, and a subsequent `divot --report` still showed
`cursorEngaged=` empty. That is **inconclusive**: synthetic pointer injection may
not update `NSEvent.mouseLocation` for a separate process, the live accessory may
not have been the packaged build under test, or the native bar may not have
revealed during the warp. It is not reported as proof that the slide fails.

## Human-only (required for acceptance; not supplied here)

A maintainer must:

1. Build or use `dist/Divot.app` from this branch (`just app-package` or
   `scripts/package-app.sh`).
2. Record a screen capture showing: pointer entering the top strip (bar slides
   below the revealed native menu bar), dwelling, leaving (bar returns to the
   top edge); Settings with **Move below the menu bar when it appears** off
   (no slide); optionally a notch-free external with auto-hide or with
   **Always below the menu bar** enabled.
3. Sign off on feel (4 pt strip and ~150 ms settle are tunable only after a real
   display check).

Do not mark the hardware checklist item in `local-preview.md` done without that
capture and sign-off.
