# Local Divot.app preview

Status: **local preview only.** This packages the current source into a runnable,
ad-hoc-signed `Divot.app` for the maintainer's Mac so the bar can be tried before
the public release gates. It is not Developer ID signed and not notarized, and it
is not a downloadable public release. Public signed distribution stays
[task #0008](../work/0008-human-device-qa-and-signed-pre-alpha-rel.md).

The preview version lives in [`VERSION`](../VERSION): `0.1.0-preview.1`.

## What it is, and what it is not

| It is | It is not |
| --- | --- |
| Built from this checkout with `swift build -c release` | A published, hosted download |
| Signed **ad-hoc** (`codesign --sign -`) so it launches locally | Developer ID signed or notarized |
| A versioned archive with the build commit and a SHA-256 | Cleared by Gatekeeper for other people |
| A way to run the real accessory app from `Divot.app` | A root installer or a system modification |

The preview does **not** install anything system-wide, change Gatekeeper or any
security setting, remove a quarantine attribute, use a guessed signing identity,
or upload anything. You open the bundle in place (or copy it to `/Applications`
yourself). No instruction here tells you to bypass Gatekeeper.

## Prerequisites

- macOS 26+ on Apple silicon.
- Xcode 26+ / Swift 6.2+ (the repo targets `swift-tools-version: 6.2`).
- [just](https://github.com/casey/just) for the documented recipes (optional;
  each recipe is a one-line shell command you can run directly).
- AeroSpace is optional but expected on this Mac; without a supported workspace
  manager the left workspace row reports an honest unavailable state.

## Build, package, and run

From the repository root:

```sh
# Assemble + ad-hoc sign dist/Divot.app, then write the versioned archive,
# checksum, build facts, and manifest under dist/.
just app-package

# Assemble, sign, archive, and verify: structure, Info.plist, signature,
# archive checksum, and a real launch of the bundled executable.
just app-smoke

# Build and open the bundle as a real app on this Mac.
just app-run
```

The same recipes without `just`:

```sh
scripts/package-app.sh          # build (release) + package under dist/
scripts/smoke-app-bundle.sh     # package + verify + launch
open dist/Divot.app             # run it
```

`package-app.sh` accepts `--configuration release` (default), `--output <dir>`,
`--version <string>`, and `--no-archive` for a quicker local bundle.

## Where the artifacts land

Everything is written under `dist/` (gitignored):

| Path | Contents |
| --- | --- |
| `dist/Divot.app` | The runnable, ad-hoc-signed bundle |
| `dist/Divot-<version>-<commit>.zip` | Versioned archive of that bundle |
| `dist/Divot-<version>-<commit>.zip.sha256` | SHA-256 of the archive |
| `dist/Divot-<version>-<commit>.build.txt` | Build commit, date, configuration, signing note |
| `dist/divot-preview-manifest.txt` | Machine-readable list of the above |

The same build facts are embedded in the app: `Divot.app/Contents/Resources/`
`DivotBuildInfo.txt` and the `DivotBuild*` keys in `Info.plist`. Verify an
archive with:

```sh
cd dist
shasum -a 256 -c Divot-0.1.0-preview.1-<commit>.zip.sha256
```

## First run on this Mac

1. Build the bundle: `just app-package` (or `scripts/package-app.sh`).
2. Confirm the smoke gate passed if you ran `just app-smoke`.
3. Open it: `open dist/Divot.app` — or drag `Divot.app` into `/Applications` and
   open it there. Divot is an accessory app (`LSUIElement`), so it has no Dock
   tile; it shows a small menu-bar item to open Settings and Quit.
4. On a notched display, macOS may ask for Accessibility permission the first
   time the notched-menu-bar detector is used. The request is contextual; deny
   it and the rest of the bar still runs, with the notched case reported as
   indeterminate rather than guessed. See
   [app shell evidence](evidence/0003-app-shell.md).
5. The bar should appear as a single row: workspaces and the frontmost app on
   the left; battery %, clock (time + weekday/date), network, and volume on the
   right. No configuration file is required for these defaults.
6. Quit Divot from its menu-bar item when you are done.

To stop a preview build, quit Divot itself; it is a normal user process. Do not
use pattern kills (`pkill`/`killall`).

## Defaults you should see

- **Left:** workspace navigation (`workspaces`) and the frontmost app
  (`front-app`).
- **Right:** battery percentage (`battery`), clock with time + weekday + date
  (`clock`), Wi-Fi/network status (`network`), and volume (`volume`).
- **Themes:** the native default plus the Gruvbox, Ayu, Dracula, and Tokyo Night
  families, each with light and dark variants, selectable from Settings or the
  configuration file (`appearance.family`, `appearance.mode`). Custom
  `appearance.palette` overrides and custom left/right item groups are available
  through the same versioned configuration; see
  [configuration contract](configuration.md) and `examples/`.

These defaults are implemented and unit-tested. The preview does not claim a
person has looked at them on screen; that is on the hardware checklist below.

## Persistent top/below behavior, and its limits

The bar is designed to keep the native menu bar accessible while Divot stays
visible: it occupies the top edge when the native bar is hidden and shifts below
it when it is revealed, returning to the top when it hides. Panel level is just
below the system menu bar (`mainMenu - 1`), so native menus stay above Divot.

Disclosed limits (never hidden):

- **Notched displays:** the camera housing masks the same band, so native-bar
  visibility cannot be decided from public APIs without a validated
  Accessibility observation. On this Mac the notched case currently reports
  `indeterminate(notchedHousingMasksMenuBar)` and holds the top edge; it never
  stacks below a phantom bar. This is the task 0015 fix.
- **A top band occupied by another bar** (for example a-bar under AeroSpace) is
  not treated as a revealed native bar, so Divot holds the top edge.
- **Always-visible native menu bar:** the detector accepts the signal but the
  observation adapter does not populate it yet, so an always-visible bar on
  notched hardware still resolves to indeterminate on this build.
- **Fullscreen, Spaces, and multi-display behavior** are implemented but only
  asserted by construction; no run yet proves on-screen ordering, focus, or
  hot-plug. See [native menu-bar evidence](evidence/0009-native-menu-bar-coexistence.md)
  and [app shell evidence](evidence/0003-app-shell.md).

No physical validation is claimed by this preview.

## Comparing against a-bar (reversible, human-run)

The maintainer's Mac runs AeroSpace with [a-bar](https://github.com/Jean-Tinland/a-bar)
(`/Applications/a-bar.app`, bundle identifier `com.jeantinland.a-bar`). Recorded
by inspection on 2026-10-10: the cask installed it at `/Applications/a-bar.app`
with `LSUIElement=1`; its configuration lives in
`~/Library/Preferences/com.jeantinland.a-bar.plist`. It was **not running** at
inspection time. Its launch-at-login is a macOS login item and is **not** to be
changed.

To compare the two bars while keeping AeroSpace running:

```sh
# Stop only a-bar (safe: it is a normal user app). Keep AeroSpace running.
osascript -e 'tell application "a-bar" to quit'   # or Quit from a-bar's own menu

# Run the preview.
open dist/Divot.app

# Restore the previous bar exactly.
open /Applications/a-bar.app
```

Do not uninstall a-bar, do not modify its login item or its preferences file,
and do not permanently change login startup without a separate request. Divot's
own "launch at login" is opt-in in Settings and stays off unless asked for.

This step is left to the human: the agent smoke test does not stop or start any
bar on your machine.

## Automated coverage the preview adds to `repoos check`

- `scripts/smoke-app-bundle.sh` (declared as the `native-app-bundle` check step)
  packages the Release bundle, checks its structure and `Info.plist`, verifies
  the ad-hoc signature with `codesign --verify --deep --strict`, confirms the
  archive SHA-256, and then **launches the bundled Mach-O** with `--help`,
  `--report` (proving the app resolves its bundled resource), and `--widgets`
  (proving the default left/right layout).
- `scripts/local-preview-gate.test.ts` guards that the recipes, the check step,
  the preview `VERSION`, the ad-hoc signing, and this guide stay honest (no
  `sudo`, no security-setting change, no quarantine stripping, no guessed
  identity).

The smoke gate never opens a window and never asserts appearance, VoiceOver, or
desktop behavior.

## Remaining hardware checklist (a person must supply)

Nothing below is proven by the automated checks. Record what you actually
observe; leave unobserved items blank rather than marking them done.

- [ ] The bar appears as one row in the top band; it does not stack under a-bar
      or the notch.
- [ ] Default left/right content matches the list above at this display width,
      with no clipped labels.
- [ ] Native menu-bar reveal/hide: Divot moves below a revealed (non-notched)
      bar and returns to the top. Notched/always-visible cases stay
      indeterminate as disclosed.
- [ ] Fullscreen, Spaces, and multiple displays (add/remove, sleep/wake).
- [ ] VoiceOver and keyboard traversal of every item and the Settings window
      ([accessibility physical checks](accessibility-physical-checks.md)).
- [ ] Click behavior: battery toggles keep-awake; status items open the intended
      System Settings pane or activate the frontmost app.
- [ ] Light/dark and all four theme families are readable on real glass.
- [ ] Release performance on the stable reference machine
      (`divot --bench`, [performance protocol](performance.md)).
- [ ] AeroSpace workspace clicks focus the right workspace.

## Public release (not this task)

Developer ID signing, notarization, a universal/arm64 archive with stapled
proof, and any public download belong to [task #0008](../work/0008-human-device-qa-and-signed-pre-alpha-rel.md).
The bundle identifier `local.divot.preview` is a deliberate local placeholder,
not a claimed public identity; the real identifier and team are not provisioned.
