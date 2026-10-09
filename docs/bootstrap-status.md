# Bootstrap status · 2026-10-10

Repository: `/Users/nick/code/nick/divot`. Initialized through `repoos init --new`, with root-level `work/` and `docs/`.

## Verified locally

- `repoos check`: all declared steps passed (site, native-core, justfile).
- Static generation completed with internal-link validation; three JSON configurations validated.
- Swift 6.3.3 / Xcode 26.6: six Swift Testing geometry tests passed.
- Browser: landing Light/Dark toggle; shared preference across documentation; workspace selection; mobile menu at 390px; no horizontal document overflow on landing/docs at the checked widths.
- Browser console inspection returned no warnings/errors at the inspected landing/docs states.
- `just --fmt --check` and `just --list` passed.

## Not verified / not implemented

Bootstrap had no executable native app; task 0003 added one (see below). Physical panel behavior, accessibility, measured performance, signing/notarization, CI on hosted runners, public repository hosting, and public deployment remain future gates. The screenshot/bar preview is a browser concept with illustrative data.

## Native shell (task 0003)

- `swift build --package-path macos --product divot` builds an accessory app shell and `swift test --package-path macos` passes 47 tests (placement state machine, notch/no-notch geometry, per-display coordination, cancellable and reduced-motion transitions, honest observation adapter).
- `divot --report` prints one honest observation pass; on the maintainer's notched display it reports `indeterminate(notchedHousingMasksMenuBar)` without Accessibility permission.
- Not verified: physical on-screen ordering, focus, fullscreen/Spaces, multi-display, animation, sleep/wake. There is no signed `.app` bundle. Details in [evidence/0003-app-shell.md](evidence/0003-app-shell.md).

## Kickoff

Task #0003 builds the AppKit app shell and display coordinator. Tasks #0004–#0007 cover providers, AeroSpace, config/appearance, and validation. Task #0008 is held for human device/signing evidence. Generic setup/vision starters are held to avoid duplicating completed bootstrap planning.

Run `just serve` in a human-owned foreground terminal from this repository, then start #0003 through RepoOS. `just dev` serves the website separately. No engineer was automatically launched by the bootstrap.
