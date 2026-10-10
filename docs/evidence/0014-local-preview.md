# Evidence · 0014 local Divot.app preview packaging

Status: **tooling implemented and smoke-tested; no physical/visual validation.**
Task 0014 · observed 2026-10-10 on the maintainer Mac (macOS 26.5.2, arm64,
Swift 6.3.3, Xcode 26.6).

This records what the packaging tooling actually did in one local run. It is not
a claim that the bar looks right, is accessible, or behaves correctly on a
display; a person must still run the [hardware checklist](../local-preview.md).

## What was built

| Piece | Path |
| --- | --- |
| Packaging script | `scripts/package-app.sh` |
| Package-and-launch smoke | `scripts/smoke-app-bundle.sh` |
| Declared check step | `repoos.toml` → `native-app-bundle` |
| Recipe guard test | `scripts/local-preview-gate.test.ts` |
| Preview version | `VERSION` (`0.1.0-preview.1`) |
| Guide | `docs/local-preview.md` |

## Observed run

`scripts/smoke-app-bundle.sh` ran the Release build, assembled the bundle,
ad-hoc signed it, verified it, launched the bundled Mach-O, and verified the
archive checksum. All steps passed:

```
smoke-app-bundle: ok  bundle structure
smoke-app-bundle: ok  Info.plist keys and version labelling
smoke-app-bundle: ok  ad-hoc signature verifies
smoke-app-bundle: ok  bundled app launches (--help)
smoke-app-bundle: ok  bundled app resolves resources (--report)
smoke-app-bundle: ok  default bar layout through the packaged app
smoke-app-bundle: ok  versioned archive and checksum
smoke-app-bundle: PASS
```

Facts from that run (the commit is the pre-handoff HEAD; a later build records
its own commit):

- version `0.1.0-preview.1`, bundle identifier `local.divot.preview`;
- commit `fabc84e6857d8633b60fe1f20e68e3e5d48ba022` (short `fabc84e6857d`),
  dirty because the branch held uncommitted work at build time;
- archive `dist/Divot-0.1.0-preview.1-fabc84e6857d.zip`,
  SHA-256 `64c99aaae2f2d5168ca458d7d078671545c5785ffa091f71f74499962f1f620e`
  (one observed run; a fresh packaging run writes its own checksum because the
  archive embeds build timestamps and a signature);
- `codesign -dv`: `Format=app bundle with Mach-O thin (arm64)`,
  `Signature=adhoc`, `TeamIdentifier=not set`;
- extracting the archive with both `unzip` and `ditto -x -k` leaves a bundle
  whose `codesign --verify --deep --strict` still passes.

`divot --report` from the packaged bundle printed:

```
# divot shell placement report
displays=1
accessibility=not trusted (permission required)
reduceMotion=false
menuBarMark=resolved
display-1 notched=true visibility=indeterminate(notchedHousingMasksMenuBar)
  mode=indeterminate (holds current placement; never hides)
```

`menuBarMark=resolved` proves the packaged app finds its bundled mark through
`Bundle.main` in `Contents/Resources`; the notched display honestly reports
indeterminate without Accessibility permission. `divot --widgets` from the
packaged bundle printed the default layout `layout.left=workspaces,front-app`
and `layout.right=battery,clock,network,volume` with live provider values.

## a-bar inspection (read-only)

- a-bar 1.6.0 installed via Homebrew cask at `/Applications/a-bar.app`.
- Bundle identifier `com.jeantinland.a-bar`, `LSUIElement = 1`.
- Configuration in `~/Library/Preferences/com.jeantinland.a-bar.plist`.
- **Not running** at inspection time; no `launchd` job under that label was
  listed.
- The reversible stop/compare/restore commands are documented in the guide and
  were **not** executed by the agent. a-bar was not uninstalled, its login item
  and preferences were not modified, and AeroSpace was left running.

## Not verified (a person must supply)

On-screen appearance and ordering; VoiceOver and keyboard traversal; fullscreen,
Spaces, multi-display, and sleep/wake behavior; click actions; theme readability
on real glass; Release performance on the reference machine; live AeroSpace
click-to-focus; and whether the bar coexists cleanly with a-bar when both are
running. No human-observed appearance or accessibility result is recorded here.
